function nodetool {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local namespace="${1:?"${errmsg} Missing namespace"}";
  checkNamespace "${namespace}";
  if [[ ! ${?} -eq 0 ]];
  then
    return 1;
  fi
  shift 1;
  local nodeList="";
  local instanceList="";
  local args="";
  local debug="";
  local filter;
  local option;
  while [[ ${#} -gt 0 ]]
  do
    case "${1}" in
      "${DEBUG_OPTION}")
        debug="${1}";
        shift 1;
        ;;
      "${NODE_OPTION}"|"${INSTANCE_OPTION}")
        option="${1}";
        shift 1;
        filter="";
        while [[ ${#} -gt 0 ]]
        do
          if [[ "${1}" =~ ^-(.*)+$ ]];
          then
            break;
          fi
          if [[ -n "${1}" ]];
          then
            filter="${1} ${filter}";
          fi
          shift 1;
        done
        if [[ -n "${filter}" ]];
        then
          case "${option}" in
            "${NODE_OPTION}")
              nodeList="${filter}";
              ;;
            "${INSTANCE_OPTION}")
              instanceList="${filter}";
              ;;
          esac
        fi
        ;;
      --)
        shift 1;
        args="${*}";
        shift ${#};
        ;;
      *)
        if [[ -n "${1}" ]];
        then
          echoerr "${errmsg} Option \"${1}\" is unknown";
          return 1;
        fi
        shift 1;
        ;;
    esac
  done
  nodeList="${nodeList:?"${errmsg} Missing list of Kubernetes node"}";
  args="${args:?"${errmsg} Missing nodetool arguments"}";
  local node;
  local podlist;
  local pod;
  local err;
  local errCode=0;
  local nodeErrCode;
  local toDo;
  for node in ${nodeList};
  do
    err="$(isCassandraNode "${node}")";
    nodeErrCode=${?};
    if [[ -z "${err}" ]];
    then
      err="$(kubectl get "${PODS_CLASS}" -n "${namespace}" \
            -o=custom-columns=NAME:.metadata.name,NODE:.spec.nodeName \
            2>&1)";
      nodeErrCode=${?};
      if [[ ${nodeErrCode} -eq 0 ]];
      then
        podlist="$(printf "%s\n" "${err}" | \
          awk -v node="${node}" '{if($2==node) print $1;}')"
        if [[ -n "${podlist}" ]];
        then
          for pod in ${podlist};
          do
            toDo=1;
            if [[ -n "${instanceList}" ]];
            then
              if [[ -z "$(isInList "${pod##*-}" "${instanceList}")" ]];
              then
                toDo=0;
              fi
            fi
            if [[ ${toDo} -eq 1 ]];
            then
              echoerr "DEBUG: ${FUNCNAME[0]}: Running nodetool on pod \"${pod}\" on node \"${node}\" with arguments \"${args}\"...";
              err="$(kubectl exec "${pod}" \
                -n "${namespace}" -- nodetool "${args}" 2>&1)";
              nodeErrCode=${?};
              if [[ ! ${nodeErrCode} -eq 0 ]];
              then
                echoerr "${errmsg} kubectl:" "${err}";
              else
                if [[ "${debug}" == "${DEBUG_OPTION}" ]];
                then
                  echoerr "DEBUG: ${FUNCNAME[0]}:" "${err}";
                fi
              fi
              echoerr "DEBUG: ${FUNCNAME[0]}: ...nodetool on pod \"${pod}\" on node \"${node}\" finished";
            fi
          done
        else
          nodeErrCode=1;
          echoerr "${errmsg} No Cassandra instance is running on the node \"${node}\"";
        fi
      else
        nodeErrCode=1;
        echoerr "${errmsg} kubectl:" "${err}";
      fi
    else
      echoerr "${errmsg} Node \"${node}\" is not a Cassandra node";
    fi
    if [[ ! ${nodeErrCode} -eq 0 ]];
    then
      errCode=1;
      printf "%s\n" "${node}";
    fi
  done
  return ${errCode};
}

function deleteNode {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local nodeList="${*:?"${errmsg} Missing list of Kubernetes node"}";
  local cluster;
  local dataCenter;
  local rack;
  local node;
  local key;
  local instances;
  local err;
  local errCode=0;
  local nodeErrCode;
  local podlist;
  local noPodNodeList="";
  local failedNodeList="";
  local statefulSet;
  local statefulSetDataList;
  local namespace;
  local storageClassName;
  local storageType;
  local storageCapacity;
  local limitCPU;
  local limitMemory;
  local requestCPU;
  local requestMemory;
  local currentReplicas;
  local maxHeapSize;
  local heapNewSize;
  local replicas;
  declare -A statefulSetList;
  for node in ${nodeList};
  do
    nodeErrCode=0;
    cluster="$(getLabel "${NODE_CLASS}" "${node}" "${CLUSTER_LABEL}")";
    dataCenter="$(getLabel "${NODE_CLASS}" "${node}" "${DATACENTER_LABEL}")";
    rack="$(getLabel "${NODE_CLASS}" "${node}" "${RACK_LABEL}")";
    if [[ -z "${cluster}" ]] || \
      [[ -z "${dataCenter}" ]] || \
      [[ -z "${rack}" ]];
    then
      nodeErrCode=1;
      echoerr "${errmsg} Node \"${node}\" is not a Cassandra node";
    else
      podlist="$(getPodsOnNode "${node}")";
      nodeErrCode=${?};
      if [[ ${nodeErrCode} -eq 0 ]] && [[ -z "${podlist}" ]];
      then
        noPodNodeList="$(addList "${node}" "${noPodNodeList}")";
        echoerr "DEBUG: ${FUNCNAME[0]}: No Cassandra instance is running on the node \"${node}\"";
      fi
      if [[ ${nodeErrCode} -eq 0 ]] && [[ -n "${podlist}" ]];
      then
        key="${cluster}.${dataCenter}.${rack}";
        statefulSetList["${key}"]="$(addList \
          "${node}" \
          "${statefulSetList[${key}]}")";
      fi
    fi
    if [[ ! ${nodeErrCode} -eq 0 ]];
    then
      errCode=1;
      printf "%s\n" "${node}";
    fi
  done
  if [[ -n "${noPodNodeList}" ]];
  then
    echoerr "DEBUG: ${FUNCNAME[0]}: Deleting persistent volumes for nodes without pods";
    err="$(deleteNodePersistentVolume ${noPodNodeList})";
    if [[ ! ${?} -eq 0 ]];
    then
      errCode=1;
      echoerr "${errmsg} Unable to delete persistent volumes for nodes:" "${err}";
    fi
    failedNodeList="$(addList2List \
      -l ${failedNodeList} \
      -l ${err})";
    echoerr "DEBUG: ${FUNCNAME[0]}: Deleting labels for nodes without pods";
    err="$(deleteNodeLabel ${noPodNodeList})";
    if [[ ! ${?} -eq 0 ]];
    then
      errCode=1;
      echoerr "${errmsg} Unable to delete labels for nodes:" "${err}";
    fi
    failedNodeList="$(addList2List \
      -l ${failedNodeList} \
      -l ${err})";
  fi
  err="$(kubectl get "${STATEFULSET_CLASS}" --all-namespaces \
    -o=custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace,STORAGECLASSNAME:.spec.volumeClaimTemplates[*].spec.storageClassName,STORAGECAPACITY:.spec.volumeClaimTemplates[*].spec.resources.requests.storage,LCPU:.spec.template.spec.containers[*].resources.limits.cpu,LMEM:.spec.template.spec.containers[*].resources.limits.memory,RCPU:.spec.template.spec.containers[*].resources.requests.cpu,RMEM:.spec.template.spec.containers[*].resources.requests.memory,REPLICAS:.spec.replicas,ENV:.spec.template.spec.containers[*].env 2>&1)";
  if [[ ! ${?}  -eq 0 ]];
  then
    echoerr "${errmsg} kubectl:" "${err}";
    return 1;
  fi
  statefulSetDataList="${err}";
  for key in ${!statefulSetList[*]};
  do
    nodeErrCode=0;
    cluster="${key%%.*}";
    dataCenter="${key#*.}";
    dataCenter="${dataCenter%.*}";
    rack="${key##*.}";
    statefulSet="${cluster,,}-${dataCenter,,}-${rack,,}"
    namespace="$(printf "%s\n" "${statefulSetDataList}" |
      awk -v statefulSet="${statefulSet}" \
        '{if($1 == statefulSet) print $2}')";
    storageClassName="$(printf "%s\n" "${statefulSetDataList}" | \
      awk -v statefulSet="${statefulSet}" \
        '{if($1 == statefulSet) print $3;}')";
    storageType="$(getStorageType "${storageClassName}")";
    storageCapacity="$(printf "%s\n" "${statefulSetDataList}" | \
      awk -v statefulSet="${statefulSet}" \
        '{if($1 == statefulSet) print $4;}')";
    limitCPU="$(printf "%s\n" "${statefulSetDataList}" | \
      awk -v statefulSet="${statefulSet}" \
        '{if($1 == statefulSet) print $5;}')";
    limitMemory="$(printf "%s\n" "${statefulSetDataList}" | \
      awk -v statefulSet="${statefulSet}" \
        '{if($1 == statefulSet) print $6;}')";
    requestCPU="$(printf "%s\n" "${statefulSetDataList}" | \
      awk -v statefulSet="${statefulSet}" \
        '{if($1 == statefulSet) print $7;}')";
    requestMemory="$(printf "%s\n" "${statefulSetDataList}" | \
      awk -v statefulSet="${statefulSet}" \
        '{if($1 == statefulSet) print $8;}')";
    currentReplicas="$(printf "%s\n" "${statefulSetDataList}" | \
      awk -v statefulSet="${statefulSet}" \
        '{if($1 == statefulSet) print $9;}')";
    maxHeapSize="$(printf "%s\n" "${statefulSetDataList}" | \
      awk -v statefulSet="${statefulSet}" \
        -v TOFIND="${MAX_HEAP_SIZE}" '{ \
          if($1 == statefulSet) { \
            for(i=10; i<=NF; i++) { \
              if(match($i, TOFIND)) { \
                i++; \
                split($i, value, ":"); \
                sub("]", "", value[2]); \
                print value[2]; \
              } \
            } \
          } \
        }')";
    heapNewSize="$(printf "%s\n" "${statefulSetDataList}" | \
      awk -v statefulSet="${statefulSet}" \
        -v TOFIND="${HEAP_NEWSIZE}" '{ \
          if($1 == statefulSet) { \
            for(i=10; i<=NF; i++) { \
              if(match($i, TOFIND)) { \
                i++; \
                split($i, value, ":"); \
                sub("]", "", value[2]); \
                print value[2]; \
              } \
            } \
          } \
        }')";
    echoerr "DEBUG: ${FUNCNAME[0]}: Decommissioning all pods in rack \"${cluster}.${dataCenter}.${rack}\"...";
    err="$(deleteStatefulSet \
      "${namespace}" \
      "${CLUSTER_OPTION}" "${cluster}" \
      "${DATACENTER_OPTION}" "${dataCenter}" \
      "${RACK_OPTION}" "${rack}")";
    if [[ ${?} -eq 0 ]];
    then
      echoerr "DEBUG: ${FUNCNAME[0]}: ...All pods in rack \"${cluster}.${dataCenter}.${rack}\" were decommissioned";
      err="$(deleteNodePersistentVolume \
        "${statefulSetList["${key}"]}")";
      if [[ ! ${?} -eq 0 ]];
      then
        nodeErrCode=1;
        echoerr "${errmsg} Unable to delete persistent volumes for nodes:" "${err}";
      fi
      failedNodeList="$(addList2List \
        -l ${failedNodeList} \
        -l ${err})";
      err="$(deleteNodeLabel \
        "${statefulSetList["${key}"]}")";
      if [[ ! ${?} -eq 0 ]];
      then
        nodeErrCode=1;
        echoerr "${errmsg} Unable to delete labels for nodes:" "${err}";
      fi
      failedNodeList="$(addList2List \
        -l ${failedNodeList} \
        -l ${err})";
      instances=$(sumInstances \
        "${CLUSTER_OPTION}" "${cluster}" \
        "${DATACENTER_OPTION}" "${dataCenter}" \
        "${RACK_OPTION}" "${rack}");
      if [[ ${instances} -gt 0 ]];
      then
        if [[ ${currentReplicas} -gt ${instances} ]];
        then
          echoerr "WARN: ${FUNCNAME[0]}: Not enough instances in rack \"${cluster}.${dataCenter}.${rack}\": desired replicas: \"${currentReplicas}\", available instances: \"${instances}\"";
          echoerr "WARN: ${FUNCNAME[0]}: Scale down desired replicas to available instances (${instances})";
          replicas=${instances};
        else
          replicas=${currentReplicas};
        fi
        echoerr "DEBUG: ${FUNCNAME[0]}: Creating statefulSet \"${statefulSet}\"";
        createStatefulSet \
          "${namespace}" \
          "${STORAGETYPE_OPTION}" "${storageType}" \
          "${STORAGECAPACITY_OPTION}" "${storageCapacity}" \
          "${CPULIMIT_OPTION}" "${limitCPU}" \
          "${MEMORYLIMIT_OPTION}" "${limitMemory}" \
          "${CPUREQUEST_OPTION}" "${requestCPU}" \
          "${MEMORYREQUEST_OPTION}" "${requestMemory}" \
          "${MAXHEAPSIZE_OPTION}" "${maxHeapSize}" \
          "${NEWHEAPSIZE_OPTION}" "${heapNewSize}" \
          "${CLUSTER_OPTION}" "${cluster}" \
          "${DATACENTER_OPTION}" "${dataCenter}" \
          "${RACK_OPTION}" "${rack}" \
          "${REPLICAS_OPTION}" "${replicas}" 1>/dev/null;
        nodeErrCode=${?};
      else
        echoerr "DEBUG: ${FUNCNAME[0]}: Rack \"${cluster}.${dataCenter}.${rack}\" was deleted";
      fi
    else
      nodeErrCode=1;
      echoerr "${errmsg} Unable to delete statefulSet:" "${err}";
    fi
    if [[ ! ${nodeErrCode} -eq 0 ]];
    then
      errCode=1;
    fi
  done
  for node in ${failedNodeList};
  do
    printf "%s\n" "${node}";
  done
  unset currentReplicas;
  unset statefulSetList;
  return ${errCode};
}
