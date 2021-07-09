STATEFULSET_CLASS="statefulsets";
STATEFULSET_SHORT="sts";
STATEFULSET_OBJECT="statefulset";

PODS_CLASS="pods";
PODS_SHORT="po";

LOCAL_DOMAIN="svc.cluster.local";

# Maximum number of seed node in a seed rack
MAX_SEEDS="${MAX_SEEDS:-3}";

WAITRUNNING_TIMEOUT="${WAITRUNNING_TIMEOUT:-60}";

STATEFULTSET_FILENAME_PREFIX="statefulSet";

MAX_HEAP_SIZE="MAX_HEAP_SIZE";
HEAP_NEWSIZE="HEAP_NEWSIZE";

STATEFULSET_COMPARE_EQUAL_SCALE="0";
STATEFULSET_COMPARE_EQUAL_STRICT="1";
STATEFULSET_COMPARE_STATUS=( \
  "${STATEFULSET_COMPARE_EQUAL_SCALE}" \
  "${STATEFULSET_COMPARE_EQUAL_STRICT}" );

function compareStatefulSet {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local namespace="${1:?"${errmsg} Missing namespace"}";
  checkNamespace "${namespace}";
  if [[ ! ${?} -eq 0 ]];
  then
    return 1;
  fi
  local cluster="${2:?"${errmsg} Missing cluster"}";
  local dataCenter="${3:?"${errmsg} Missing data center"}";
  local rack="${4:?"${errmsg} Missing rack"}";
  local replicas="${5:?"${errmsg} Missing replicas"}";
  local storageClassName="${6:?"${errmsg} Missing storage class name"}";
  local storageCapacity="${7:?"${errmsg} Missing storage capacity"}";
  local limitCPU="${8:?"${errmsg} Missing CPU limit"}";
  local limitMemory="${9:?"${errmsg} Missing memory limit"}";
  local requestCPU="${10:?"${errmsg} Missing CPU resquest"}";
  local requestMemory="${11:?"${errmsg} Missing memory request"}";
  local maxHeapSize="${12:?"${errmsg} Missing max heap size"}";
  local heapNewSize="${13:?"${errmsg} Missing new heap size"}";
  local err;
  err="$(kubectl get "${STATEFULSET_CLASS}" \
    "${cluster,,}-${dataCenter,,}-${rack,,}" -n "${namespace}" \
    -o=custom-columns=STORAGECLASSNAME:.spec.volumeClaimTemplates[*].spec.storageClassName,STORAGECAPACITY:.spec.volumeClaimTemplates[*].spec.resources.requests.storage,LCPU:.spec.template.spec.containers[*].resources.limits.cpu,LMEM:.spec.template.spec.containers[*].resources.limits.memory,RCPU:.spec.template.spec.containers[*].resources.requests.cpu,RMEM:.spec.template.spec.containers[*].resources.requests.memory,REPLICAS:.spec.replicas,ENV:.spec.template.spec.containers[*].env 2>&1)";
  if [[ ${?} -eq 0 ]];
  then
    printf "%s\n" "${err}" | \
      awk -v storageClassName="${storageClassName}" \
      -v storageCapacity="${storageCapacity}" \
      -v limitCPU="${limitCPU}" \
      -v limitMemory="${limitMemory}" \
      -v requestCPU="${requestCPU}" \
      -v requestMemory="${requestMemory}" \
      -v MAX_HEAP_SIZE="${MAX_HEAP_SIZE}" \
      -v maxHeapSize="${maxHeapSize}" \
      -v HEAP_NEWSIZE="${HEAP_NEWSIZE}" \
      -v heapNewSize="${heapNewSize}" \
      -v replicas="${replicas}" \
      -v STATEFULSET_COMPARE_EQUAL_SCALE="${STATEFULSET_COMPARE_EQUAL_SCALE}" \
      -v STATEFULSET_COMPARE_EQUAL_STRICT="${STATEFULSET_COMPARE_EQUAL_STRICT}" \
      'NR>1 { \
        if((storageClassName == $1) && \
          (storageCapacity == $2) && \
          (limitCPU == $3) && \
          (limitMemory == $4) && \
          (requestCPU == $5) && \
          (requestMemory == $6)) { \
            for(i=8; i<=NF; i++) { \
              if(match($i, MAX_HEAP_SIZE) || match($i, HEAP_NEWSIZE)) { \
                x=$i;
                i++; \
                split($i, value, ":"); \
                sub("]", "", value[2]); \
                if(match(x, MAX_HEAP_SIZE)) \
                  currentMaxHeapSize=value[2]; \
                if(match(x, HEAP_NEWSIZE)) \
                  currentHeapNewSize=value[2]; \
              } \
            } \
            if((maxHeapSize == currentMaxHeapSize) && \
              (heapNewSize == currentHeapNewSize)) \
              if(replicas==$7) print STATEFULSET_COMPARE_EQUAL_STRICT; \
              else print STATEFULSET_COMPARE_EQUAL_SCALE; \
          } \
        }';
    return 0;
  else
    echoerr "${errmsg} kubectl:" "${err}";
    return 1;
  fi
}

function createStatefulSet {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local namespace="${1:?"${errmsg} Missing namespace"}";
  checkNamespace "${namespace}";
  if [[ ! ${?} -eq 0 ]];
  then
    return 1;
  fi
  shift 1;
  local storageType="";
  local storageCapacity="";
  local limitCPU="";
  local limitMemory="";
  local requestCPU="";
  local requestMemory="";
  local maxHeapSize="";
  local heapNewSize="";
  local desireClusterList="";
  local desiredDataCenterList="";
  local desiredRackList="";
  local desiredReplicas="";
  local overwrite="";
  local filter;
  local option;
  while [[ ${#} -gt 0 ]]
  do
    case "${1}" in
      "${OVERWRITE_OPTION}")
        overwrite="${1}";
        shift 1;
        ;;
      "${STORAGETYPE_OPTION}"| \
      "${STORAGECAPACITY_OPTION}"| \
      "${CPULIMIT_OPTION}"| \
      "${MEMORYLIMIT_OPTION}"| \
      "${CPUREQUEST_OPTION}"| \
      "${MEMORYREQUEST_OPTION}"| \
      "${MAXHEAPSIZE_OPTION}"| \
      "${NEWHEAPSIZE_OPTION}"| \
      "${REPLICAS_OPTION}")
        option="${1}";
        shift 1;
        if [[ "${1}" =~ ^-(.*)+$ ]];
        then
          echoerr "${errmsg} Missing value for option \"${option}\"";
          return 1;
        fi
        case "${option}" in
          "${STORAGETYPE_OPTION}")
            storageType="${1}";
            ;;
          "${STORAGECAPACITY_OPTION}")
            storageCapacity="${1}";
            ;;
          "${CPULIMIT_OPTION}")
            limitCPU="${1}";
            ;;
          "${MEMORYLIMIT_OPTION}")
            limitMemory="${1}";
            ;;
          "${CPUREQUEST_OPTION}")
            requestCPU="${1}";
            ;;
          "${MEMORYREQUEST_OPTION}")
            requestMemory="${1}";
            ;;
          "${MAXHEAPSIZE_OPTION}")
            maxHeapSize="${1}";
            ;;
          "${NEWHEAPSIZE_OPTION}")
            heapNewSize="${1}";
            ;;
          "${REPLICAS_OPTION}")
            desiredReplicas="${1}";
            ;;
        esac
        shift 1;
        ;;
      "${CLUSTER_OPTION}"|"${DATACENTER_OPTION}"|"${RACK_OPTION}")
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
            "${CLUSTER_OPTION}")
              desireClusterList="${filter}";
              ;;
            "${DATACENTER_OPTION}")
              desiredDataCenterList="${filter}";
              ;;
            "${RACK_OPTION}")
              desiredRackList="${filter}";
              ;;
          esac
        fi
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
  storageType="${storageType:?"${errmsg} Missing storage type"}";
  local storageClassName;
  storageClassName="$(getStorageClassName "${storageType}")";
  if [[ ! ${?} -eq 0 ]];
  then
    return 1;
  fi
  storageCapacity="${storageCapacity:?"${errmsg} Missing storage capacity"}";
  limitCPU="${limitCPU:?"${errmsg} Missing CPU limit"}";
  limitMemory="${limitMemory:?"${errmsg} Missing memory limit"}";
  requestCPU="${requestCPU:?"${errmsg} Missing CPU request"}";
  requestMemory="${requestMemory:?"${errmsg} Missing memory request"}";
  maxHeapSize="${maxHeapSize:?"${errmsg} Missing max heap size"}";
  heapNewSize="${heapNewSize:?"${errmsg} Missing heap new size"}";
  local cluster;
  local dataCenter;
  local rack;
  local seedList;
  local replicas;
  local instances;
  local err;
  local errCode;
  local clusterErrCode;
  local rackErrCode;
  local i;
  local x;
  local statefulSetFile;
  declare -A clusterList;
  declare -A dataCenterList;
  declare -A rackList;
  getTopology clusterList dataCenterList rackList;
  errCode=${?};
  if [[ ${errCode} -eq 0 ]];
  then
    for cluster in ${desireClusterList:-${!clusterList[*]}};
    do
      clusterErrCode=0;
      if [[ -n "${clusterList[${cluster}]}" ]];
      then
        # From https://docs.datastax.com/en/dse/6.0/dse-admin/datastax_enterprise/production/multiDCperWorkloadType.html:
        # Important: Include at least one seed node from each datacenter.
        # DataStax recommends more than one seed node per datacenter,
        # in more than one rack. Do not make all nodes seed nodes.
        # Or from http://cassandra.apache.org/doc/latest/faq/#what-are-seeds:
        # Recommended usage of seeds:
        # - pick two (or more) nodes per data center as seed nodes.
        # - sync the seed list to all your nodes
        seedList="";
        for dataCenter in ${clusterList[${cluster}]};
        do
          if [[ -n "${rackList[${cluster}.${dataCenter}.${SEED_RACK}]}" ]];
          then
            instances=$(sumNodeInstances \
              "${rackList[${cluster}.${dataCenter}.${SEED_RACK}]}");
            if [[ ${instances} -gt ${MAX_SEEDS} ]];
            then
              x=${MAX_SEEDS};
            else
              x=${instances};
            fi
            for (( i=0; i<x; i++ ));
            do
              seedList="${cluster,,}-${dataCenter,,}-${SEED_RACK,,}-${i}.${cluster,,}-${dataCenter,,}.${namespace,,}.${LOCAL_DOMAIN,,},${seedList}";
            done
          else
            echoerr "${errmsg} Rack \"${cluster}.${dataCenter}.${SEED_RACK}\" was not found";
          fi
        done
        if [[ -n ${seedList} ]];
        then
          seedList="${seedList%,}";
          for dataCenter in ${desiredDataCenterList:-${clusterList[${cluster}]}};
          do
            if [[ -n "${dataCenterList[${cluster}.${dataCenter}]}" ]];
            then
              x="${desiredRackList:-${dataCenterList[${cluster}.${dataCenter}]}}";
              # If the seed rack is in the rack list, we start the seed rack first
              if [[ -n "$(isInList "${SEED_RACK}" "${x}")" ]]
              then
                x="${SEED_RACK} $(removeList "${SEED_RACK}" "${x}")";
              fi
              for rack in ${x};
              do
                rackErrCode=0;
                if [[ -n "${rackList[${cluster}.${dataCenter}.${rack}]}" ]];
                then
                  instances=$(sumNodeInstances \
                    "${rackList[${cluster}.${dataCenter}.${rack}]}");
                  if [[ -z "${desiredReplicas}" ]];
                  then
                    replicas="${instances}";
                  else
                    if [[ ${desiredReplicas} -gt ${instances} ]];
                    then
                      echoerr "WARN: ${FUNCNAME[0]}: Not enough instances in rack \"${cluster}.${dataCenter}.${rack}\": desired replicas: \"${desiredReplicas}\", available instances: \"${instances}\"";
                      echoerr "WARN: ${FUNCNAME[0]}: Scale down desired replicas to available instances";
                      replicas="${instances}";
                    else
                      replicas="${desiredReplicas}";
                    fi
                  fi
                  err="$(kubectl get "${STATEFULSET_CLASS}" \
                    "${cluster,,}-${dataCenter,,}-${rack,,}" \
                    -n "${namespace}" 2>&1)";
                  if [[ ${?} -eq 0 ]]
                  then
                    if [[ -n "${overwrite}" ]];
                    then
                      deleteStatefulSet "${namespace}" \
                        "${CLUSTER_OPTION}" "${cluster}" \
                        "${DATACENTER_OPTION}" "${dataCenter}" \
                        "${RACK_OPTION}" "${rack}" 1>/dev/null;
                      rackErrCode=${?};
                    else
                      echoerr "${errmsg} statefulSet \"${cluster,,}-${dataCenter,,}-${rack,,}\" already exist";
                      rackErrCode=1;
                    fi
                  fi
                  if [[ ${rackErrCode} -eq 0 ]];
                  then
                    statefulSetFile="${GENERATED_DIR}/${STATEFULTSET_FILENAME_PREFIX}.${cluster}.${dataCenter}.${rack}.yaml";
                    err="$(sed -e \
                      '/<clusterDNS>/{s/<clusterDNS>/'"${cluster,,}"'/g}; /<dataCenterDNS>/{s/<dataCenterDNS>/'"${dataCenter,,}"'/g}; /<rackDNS>/{s/<rackDNS>/'"${rack,,}"'/g}; /<cluster>/{s/<cluster>/'"${cluster}"'/g}; /<dataCenter>/{s/<dataCenter>/'"${dataCenter}"'/g}; /<rack>/{s/<rack>/'"${rack}"'/g}; /<seeds>/{s/<seeds>/'"${seedList}"'/g}; /<replicas>/{s/<replicas>/'"${replicas}"'/g}; /<storageClassName>/{s/<storageClassName>/'"${storageClassName}"'/g}; /<storageCapacity>/{s/<storageCapacity>/'"${storageCapacity}"'/g}; /<limitCPU>/{s/<limitCPU>/'"${limitCPU}"'/g}; /<limitMemory>/{s/<limitMemory>/'"${limitMemory}"'/g}; /<requestCPU>/{s/<requestCPU>/'"${requestCPU}"'/g}; /<requestMemory>/{s/<requestMemory>/'"${requestMemory}"'/g}; /<maxHeapSize>/{s/<maxHeapSize>/'"${maxHeapSize}"'/g}; /<heapNewSize>/{s/<heapNewSize>/'"${heapNewSize}"'/g}' \
                      "${OPERATOR_ROOT}/yaml/${STATEFULTSET_FILENAME_PREFIX}.cluster.dataCenter.rack.yaml.template" \
                      > "${statefulSetFile}")";
                    if [[ ${?} -eq 0 ]];
                    then
                      err="$(kubectl create \
                        -f "${statefulSetFile}" \
                        -n "${namespace}" 2>&1)";
                      if [[ ${?} -eq 0 ]];
                      then
                        echoerr "DEBUG: ${FUNCNAME[0]}: kubectl:" "${err}";
                        waitUntilRunning \
                          "${namespace}" \
                          "${cluster}" \
                          "${dataCenter}" \
                          "${rack}";
                      else
                        rackErrCode=1;
                        echoerr "${errmsg} kubectl:" "${err}";
                      fi
                    else
                      rackErrCode=1;
                      echoerr "${errmsg} Unable to generate YAML file for statafulSet for rack \"${cluster}.${dataCenter}.${rack}\":" "${err}";
                    fi
                  fi
                else
                  rackErrCode=1;
                  echoerr "${errmsg} Rack \"${cluster}.${dataCenter}.${rack}\" was not found";
                fi
                if [[ ! ${rackErrCode} -eq 0 ]];
                then
                  errCode=1;
                  printf "%s\n" "${cluster}.${dataCenter}.${rack}";
                fi
              done
            else
              errCode=1;
              echoerr "${errmsg} Data center \"${cluster}.${dataCenter}\" was not found";
              printf "%s\n" "${cluster}.${dataCenter}";
            fi
          done
        else
          clusterErrCode=1;
          echoerr "${errmsg} Failed to create list of seed for cluster \"${cluster}\"";
        fi
      else
        clusterErrCode=1;
        echoerr "${errmsg} Cluster \"${cluster}\" was not found";
      fi
      if [[ ! ${clusterErrCode} -eq 0 ]];
      then
        errCode=1;
        printf "%s\n" "${cluster}";
      fi
    done
  fi
  unset clusterList;
  unset dataCenterList;
  unset rackList;
  return ${errCode};
}

function deleteStatefulSet {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local namespace="${1:?"${errmsg} Missing namespace"}";
  checkNamespace "${namespace}";
  if [[ ! ${?} -eq 0 ]];
  then
    return 1;
  fi
  local desireClusterList="";
  local desiredDataCenterList="";
  local desiredRackList="";
  local filter;
  local option;
  shift 1;
  while [[ ${#} -gt 0 ]]
  do
    case "${1}" in
      "${CLUSTER_OPTION}"|"${DATACENTER_OPTION}"|"${RACK_OPTION}")
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
            "${CLUSTER_OPTION}")
              desireClusterList="${filter}";
              ;;
            "${DATACENTER_OPTION}")
              desiredDataCenterList="${filter}";
              ;;
            "${RACK_OPTION}")
              desiredRackList="${filter}";
              ;;
          esac
        fi
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
  local cluster;
  local dataCenter;
  local rack;
  local err;
  local errCode=0;
  local rackErrCode;
  declare -A clusterList;
  declare -A dataCenterList;
  declare -A rackList;
  getTopology clusterList dataCenterList rackList;
  errCode=${?};
  if [[ ${errCode} -eq 0 ]];
  then
    for cluster in ${desireClusterList:-${!clusterList[*]}};
    do
      if [[ -n "${clusterList[${cluster}]}" ]];
      then
        for dataCenter in ${desiredDataCenterList:-${clusterList[${cluster}]}};
        do
          if [[ -n "${dataCenterList[${cluster}.${dataCenter}]}" ]];
          then
            for rack in ${desiredRackList:-${dataCenterList[${cluster}.${dataCenter}]}};
            do
              rackErrCode=0;
              if [[ -n "${rackList[${cluster}.${dataCenter}.${rack}]}" ]];
              then
                echoerr "DEBUG: ${FUNCNAME[0]}: Deleting statefulSet \"${cluster,,}-${dataCenter,,}-${rack,,}\"...";
                err="$(kubectl delete "${STATEFULSET_CLASS}" \
                  "${cluster,,}-${dataCenter,,}-${rack,,}" \
                  -n "${namespace}" 2>&1)";
                if [[ ${?} -eq 0 ]];
                then
                  echoerr "DEBUG: ${FUNCNAME[0]}: kubectl:" "${err}";
                  releasePersistentVolumeClaim \
                    "${namespace}" \
                    "$(getObjectList \
                      "${namespace}" \
                      "${PERSISTENTVOLUMECLAIM_CLASS}" \
                      "${CLUSTER_OPTION}" "${cluster}" \
                      "${DATACENTER_OPTION}" "${dataCenter}" \
                      "${RACK_OPTION}" "${rack}")" 1>/dev/null;
                  rackErrCode=${?};
                else
                  rackErrCode=1;
                  echoerr "${errmsg} kubectl:" "${err}";
                fi
              else
                rackErrCode=1;
                echoerr "${errmsg} Rack \"${cluster}.${dataCenter}.${rack}\" was not found";
              fi
              if [[ ! ${rackErrCode} -eq 0 ]];
              then
                errCode=1;
                printf "%s\n" "${cluster}.${dataCenter}.${rack}";
              fi
            done
          else
            errCode=1;
            echoerr "${errmsg} Data center \"${cluster}.${dataCenter}\" was not found";
            printf "%s\n" "${cluster}.${dataCenter}";
          fi
        done
      else
        errCode=1;
        echoerr "${errmsg} Cluster \"${cluster}\" was not found";
        printf "%s\n" "${cluster}";
      fi
    done
  fi
  unset clusterList;
  unset dataCenterList;
  unset rackList;
  return ${errCode};
}

# Under a timeout, wait until all desired pods in a statefulset are in
# 'Running' state
function waitUntilRunning {
  local errmsg="DEBUG: ${FUNCNAME[0]}:";
  local namespace="${1:?"${errmsg} Missing namespace"}";
  checkNamespace "${namespace}";
  if [[ ! ${?} -eq 0 ]];
  then
    return 1;
  fi
  local cluster="${2:?"${errmsg} Missing cluster"}";
  local dataCenter="${3:?"${errmsg} Missing data center"}";
  local rack="${4:?"${errmsg} Missing rack"}";
  local desiredReplicas;
  local podList;
  local runningPods;
  local err;
  local errCode=0;
  local startTime;
  local previousPods=0;
  startTime=$(date +%s);
  err="$(kubectl get "${STATEFULSET_CLASS}" \
    "${cluster,,}-${dataCenter,,}-${rack,,}" \
    -o=custom-columns=REPLICAS:.spec.replicas \
    -n "${namespace}" 2>&1)";
  if [[ ${?} -eq 0 ]];
  then
    desiredReplicas="$(printf "%s\n" "${err}" | \
      awk 'NR>1{print $1;}')";
  else
    echoerr "${errmsg} kubectl:" "${err}";
    return 1;
  fi
  echoerr "${errmsg} Waiting for Pods...";
  while true;
  do
    podList="$(getObjectList \
      "${namespace}" \
      "${PODS_CLASS}" \
      "${CLUSTER_OPTION}" "${cluster}" \
      "${DATACENTER_OPTION}" "${dataCenter}" \
      "${RACK_OPTION}" "${rack}")";
    if [[ ${?} -eq 0 ]] && [[ -n "${podList}" ]];
    then
      err="$(kubectl get "${PODS_CLASS}" ${podList} \
        -o=custom-columns=STATUS:.status.phase \
        -n ${namespace} 2>&1)"
      if [[ ${?} -eq 0 ]];
      then
        runningPods=$(printf "%s\n" "${err}" | \
          awk '$1~/Running/' | wc -l);
        if [[ ! ${desiredReplicas} -eq ${runningPods} ]];
        then
          echoerr "${errmsg} ${runningPods}/${desiredReplicas} pods in rack \"${cluster}.${dataCenter}.${rack}\" are in running state.";
        else
          break;
        fi
        if [[ ${runningPods} -gt ${previousPods} ]];
        then
          startTime=$(date +%s);
        fi
        previousPods=${runningPods};
      else
        errCode=1;
      fi
    else
      errCode=1;
    fi
    if [[ $(date +%s) -gt $((${startTime}+${WAITRUNNING_TIMEOUT})) ]];
    then
      echoerr "${errmsg} Enough waiting";
      break;
    fi
  done
  if [[ ${desiredReplicas} -eq ${runningPods} ]];
  then
    echoerr "${errmsg} All pods (${desiredReplicas}) in rack \"${cluster}.${dataCenter}.${rack}\" are in running state.";
  fi
  return ${errCode};
}

function restartStatefulSet {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local namespace="${1:?"${errmsg} Missing namespace"}";
  checkNamespace "${namespace}";
  if [[ ! ${?} -eq 0 ]];
  then
    return 1;
  fi
  shift 1;
  local desireClusterList="";
  local desiredDataCenterList="";
  local desiredRackList="";
  local filter;
  local option;
  while [[ ${#} -gt 0 ]]
  do
    case "${1}" in
      "${CLUSTER_OPTION}"|"${DATACENTER_OPTION}"|"${RACK_OPTION}")
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
            "${CLUSTER_OPTION}")
              desireClusterList="${filter}";
              ;;
            "${DATACENTER_OPTION}")
              desiredDataCenterList="${filter}";
              ;;
            "${RACK_OPTION}")
              desiredRackList="${filter}";
              ;;
          esac
        fi
        ;;
      *)
        echoerr "${errmsg} Option \"${1}\" is unknownn";
        return 1;
        ;;
    esac
  done
  local cluster;
  local dataCenter;
  local rack;
  local err;
  local errCode;
  local rackErrCode;
  local statefulSet;
  local storageClassName;
  local storageType;
  local storageCapacity;
  local limitCPU;
  local limitMemory;
  local requestCPU;
  local requestMemory;
  local replicas;
  local maxHeapSize;
  local heapNewSize;
  local x;
  declare -A clusterList;
  declare -A dataCenterList;
  declare -A rackList;
  getTopology clusterList dataCenterList rackList;
  errCode=${?};
  if [[ ${errCode} -eq 0 ]];
  then
    for cluster in ${desireClusterList:-${!clusterList[*]}};
    do
      if [[ -n "${clusterList[${cluster}]}" ]];
      then
        for dataCenter in ${desiredDataCenterList:-${clusterList[${cluster}]}};
        do
          if [[ -n "${dataCenterList[${cluster}.${dataCenter}]}" ]];
          then
            x="${desiredRackList:-${dataCenterList[${cluster}.${dataCenter}]}}";
            # If the seed rack is in the rack list, we start the seed rack first
            if [[ -n "$(isInList "${SEED_RACK}" "${x}")" ]]
            then
              x="${SEED_RACK} $(removeList "${SEED_RACK}" "${x}")";
            fi
            for rack in ${x};
            do
              rackErrCode=0;
              if [[ -n "${rackList[${cluster}.${dataCenter}.${rack}]}" ]];
              then
                statefulSet="${cluster,,}-${dataCenter,,}-${rack,,}";
                err="$(kubectl get "${STATEFULSET_CLASS}" "${statefulSet}" -n "${namespace}" \
                -o=custom-columns=STORAGECLASSNAME:.spec.volumeClaimTemplates[*].spec.storageClassName,STORAGECAPACITY:.spec.volumeClaimTemplates[*].spec.resources.requests.storage,LCPU:.spec.template.spec.containers[*].resources.limits.cpu,LMEM:.spec.template.spec.containers[*].resources.limits.memory,RCPU:.spec.template.spec.containers[*].resources.requests.cpu,RMEM:.spec.template.spec.containers[*].resources.requests.memory,REPLICAS:.spec.replicas,ENV:.spec.template.spec.containers[*].env 2>&1)";
                if [[ ${?} -eq 0 ]];
                then
                  storageClassName="$(printf "%s\n" "${err}" | \
                    awk 'NR>1{print $1;}')";
                  storageType="$(getStorageType "${storageClassName}")";
                  storageCapacity="$(printf "%s\n" "${err}" | \
                    awk 'NR>1{print $2;}')";
                  limitCPU="$(printf "%s\n" "${err}" | \
                    awk 'NR>1{print $3;}')";
                  limitMemory="$(printf "%s\n" "${err}" | \
                    awk 'NR>1{print $4;}')";
                  requestCPU="$(printf "%s\n" "${err}" | \
                    awk 'NR>1{print $5;}')";
                  requestMemory="$(printf "%s\n" "${err}" | \
                    awk 'NR>1{print $6;}')";
                  replicas="$(printf "%s\n" "${err}" | \
                    awk 'NR>1{print $7;}')";
                  maxHeapSize="$(printf "%s\n" "${err}" | \
                    awk -v TOFIND="${MAX_HEAP_SIZE}" \
                      'NR>1 { \
                        for(i=8; i<=NF; i++) { \
                          if(match($i, TOFIND)) { \
                            i++; \
                            split($i, value, ":"); \
                            sub("]", "", value[2]); \
                            print value[2]; \
                          } \
                        } \
                      }')";
                  heapNewSize="$(printf "%s\n" "${err}" | \
                    awk -v TOFIND="${HEAP_NEWSIZE}" \
                      'NR>1 { \
                        for(i=8; i<=NF; i++) { \
                          if(match($i, TOFIND)) { \
                            i++; \
                            split($i, value, ":"); \
                            sub("]", "", value[2]); \
                            print value[2]; \
                          } \
                        } \
                      }')";
                  echoerr "DEBUG: ${FUNCNAME[0]}: Deleting statefulSet \"${statefulSet}\"";
                  err="$(deleteStatefulSet "${namespace}" \
                    "${CLUSTER_OPTION}" "${cluster}" \
                    "${DATACENTER_OPTION}" "${dataCenter}" \
                    "${RACK_OPTION}" "${rack}")";
                  if [[ ${?} -eq 0 ]];
                  then
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
                    errRackCode=${?};
                  else
                    echoerr "${errmsg}" "${err}";
                    rackErrCode=1;
                  fi
                else
                  echoerr "${errmsg} kubectl:" "${err}";
                  rackErrCode=1;
                fi
              else
                rackErrCode=1;
                echoerr "${errmsg} Rack \"${cluster}.${dataCenter}.${rack}\" was not found";
              fi
              if [[ ! ${rackErrCode} -eq 0 ]];
              then
                errCode=1;
                printf "%s\n" "${cluster}.${dataCenter}.${rack}";
              fi
            done
          else
            errCode=1;
            echoerr "${errmsg} Data center \"${cluster}.${dataCenter}\" was not found";
            printf "%s\n" "${cluster}.${dataCenter}.";
          fi
        done
      else
        errCode=1;
        echoerr "${errmsg} Cluster \"${cluster}\" was not found";
        printf "%s\n" "${cluster}";
      fi
    done
  fi
  unset clusterList;
  unset dataCenterList;
  unset rackList;
  return ${errCode};
}

function scaleStatefulSet {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local namespace="${1:?"${errmsg} Missing namespace"}";
  checkNamespace "${namespace}";
  if [[ ! ${?} -eq 0 ]];
  then
    return 1;
  fi
  shift 1;
  local desireClusterList="";
  local desiredDataCenterList="";
  local desiredRackList="";
  local desiredReplicas="";
  local filter;
  local option;
  while [[ ${#} -gt 0 ]]
  do
    case "${1}" in
      "${REPLICAS_OPTION}")
        desiredReplicas="${2}";
        shift 2;
        ;;
      "${CLUSTER_OPTION}"|"${DATACENTER_OPTION}"|"${RACK_OPTION}")
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
            "${CLUSTER_OPTION}")
              desireClusterList="${filter}";
              ;;
            "${DATACENTER_OPTION}")
              desiredDataCenterList="${filter}";
              ;;
            "${RACK_OPTION}")
              desiredRackList="${filter}";
              ;;
          esac
        fi
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
  local cluster;
  local dataCenter;
  local rack;
  local instances;
  local currentReplicas;
  local replicas;
  local err;
  local errCode;
  local rackErrCode;
  local storageName;
  local pod;
  local pvcList;
  local x;
  local i;
  declare -A clusterList;
  declare -A dataCenterList;
  declare -A rackList;
  getTopology clusterList dataCenterList rackList;
  errCode=${?};
  if [[ ${errCode} -eq 0 ]];
  then
    for cluster in ${desireClusterList:-${!clusterList[*]}};
    do
      if [[ -n "${clusterList[${cluster}]}" ]];
      then
        for dataCenter in ${desiredDataCenterList:-${clusterList[${cluster}]}};
        do
          if [[ -n "${dataCenterList[${cluster}.${dataCenter}]}" ]];
          then
            x="${desiredRackList:-${dataCenterList[${cluster}.${dataCenter}]}}";
            # If the seed rack is in the rack list, we start the seed rack first
            if [[ -n "$(isInList "${SEED_RACK}" "${x}")" ]]
            then
              x="${SEED_RACK} $(removeList "${SEED_RACK}" "${x}")";
            fi
            for rack in ${x};
            do
              rackErrCode=0;
              if [[ -n "${rackList[${cluster}.${dataCenter}.${rack}]}" ]];
              then
                err="$(kubectl get "${STATEFULSET_CLASS}" \
                  "${cluster,,}-${dataCenter,,}-${rack,,}" \
                  -o=custom-columns=REPLICAS:.spec.replicas \
                  -n "${namespace}" 2>&1)";
                if [[ ${?} -eq 0 ]];
                then
                  currentReplicas="$(printf "%s\n" "${err}" | \
                    awk 'NR>1{print $1;}')";
                  instances=$(sumInstances \
                    "${CLUSTER_OPTION}" "${cluster}" \
                    "${DATACENTER_OPTION}" "${dataCenter}" \
                    "${RACK_OPTION}" "${rack}");
                  if [[ -z "${desiredReplicas}" ]];
                  then
                    replicas=${instances};
                  else
                    if [[ "${desiredReplicas}" =~ ^[+|-](.*)+$ ]];
                    then
                      desiredReplicas=$((${currentReplicas}+${desiredReplicas}));
                    fi
                    replicas=${desiredReplicas};
                    if [[ ${replicas} -lt 0 ]];
                    then
                      echoerr "${errmsg} The result desired replicas (${desiredReplicas}) must be >= 0";
                      echoerr "WARN: ${FUNCNAME[0]}: Scale up desired replicas to 0";
                      replicas=0;
                    fi
                    if [[ ${replicas} -gt ${instances} ]];
                    then
                      echoerr "WARN: ${FUNCNAME[0]}: Not enough instances in rack \"${cluster}.${dataCenter}.${rack}\": desired replicas: \"${desiredReplicas}\", available instances: \"${instances}\"";
                      echoerr "WARN: ${FUNCNAME[0]}: Scale down desired replicas to available instances (${instances})";
                      replicas=${instances};
                    fi
                  fi
                  if [[ ${replicas} -eq 0 ]];
                  then
                    echoerr "DEBUG: ${FUNCNAME[0]}: The statefulSet \"${cluster}.${dataCenter}.${rack}\" will be deleted because desired replicas is (${replicas})";
                    deleteStatefulSet \
                      "${namespace}" \
                      "${CLUSTER_OPTION}" "${cluster}" \
                      "${DATACENTER_OPTION}" "${dataCenter}" \
                      "${RACK_OPTION}" "${rack}" 1>/dev/null;
                    rackErrCode=${?};
                  else
                    if [[ ${replicas} -eq ${currentReplicas} ]];
                    then
                      echoerr "DEBUG: ${FUNCNAME[0]}: Desired replicas (${replicas}) is equal to current replicas (${currentReplicas}): Nothing to scale";
                    else
                      echoerr "DEBUG: ${FUNCNAME[0]}: Attempting to scale current replicas (${currentReplicas}) to (${replicas}) for statefulSet ${cluster,,}-${dataCenter,,}-${rack,,}";
                      if [[ ${replicas} -lt ${currentReplicas} ]];
                      then
                        storageName="";
                        err="$(kubectl get "${STATEFULSET_CLASS}" \
                          "${cluster,,}-${dataCenter,,}-${rack,,}" \
                          -n "${namespace}" \
                          -ocustom-columns=STORAGENAME:.spec.volumeClaimTemplates[*].metadata.name 2>&1)";
                        if [[ ${?} -eq 0 ]];
                        then
                          storageName="$(printf "%s\n" "${err}" | \
                            awk 'NR>1{print $1;}')";
                          for (( i=replicas; i<currentReplicas; i++ ));
                          do
                            # Decommissioning pod
                            pod="${cluster,,}-${dataCenter,,}-${rack,,}-${i}";
                            echoerr "DEBUG: ${FUNCNAME[0]}: Decommissioning pod \"${pod}\"...";
                            err="$(kubectl exec "${pod}" \
                              -n "${namespace}" -- \
                              nodetool decommission 2>&1)";
                            if [[ ${?} -eq 0 ]];
                            then
                              echoerr "DEBUG: ${FUNCNAME[0]}: ...Pod \"${pod}\" was decommissioned";
                            else
                              rackErrCode=1;
                              echoerr "${errmsg} kubectl:" "${err}";
                            fi
                          done
                        else
                          rackErrCode=1;
                          echoerr "${errmsg} kubectl:" "${err}";
                        fi
                      fi
                      echoerr "DEBUG: ${FUNCNAME[0]}: Scaling...";
                      err="$(kubectl scale "${STATEFULSET_CLASS}" \
                        "${cluster,,}-${dataCenter,,}-${rack,,}" \
                        --replicas="${replicas}" \
                        -n "${namespace}" 2>&1)";
                      if [[ ${?} -eq 0 ]];
                      then
                        echoerr "DEBUG: ${FUNCNAME[0]}: kubectl:" "${err}";
                        waitUntilRunning \
                          "${namespace}" \
                          "${cluster}" \
                          "${dataCenter}" \
                          "${rack}";
                      else
                        rackErrCode=1;
                        echoerr "${errmsg} kubectl:" "${err}";
                      fi
                      if [[ ${replicas} -lt ${currentReplicas} ]] && \
                        [[ -n "${storageName}" ]];
                      then
                        pvcList="";
                        for (( i=replicas; i<currentReplicas; i++ ));
                        do
                          pvcList="${storageName}-${cluster,,}-${dataCenter,,}-${rack,,}-${i} \
                            ${pvcList}";
                        done
                        releasePersistentVolumeClaim \
                          "${namespace}" \
                          "${pvcList}" 1>/dev/null;
                        rackErrCode=${?};
                      fi
                    fi
                  fi
                else
                  rackErrCode=1;
                  echoerr "${errmsg} kubectl:" "${err}";
                fi
              else
                rackErrCode=1;
                echoerr "${errmsg} Rack \"${cluster}.${dataCenter}.${rack}\" was not found";
              fi
              if [[ ! ${rackErrCode} -eq 0 ]];
              then
                errCode=1;
                printf "%s\n" "${cluster}.${dataCenter}.${rack}";
              fi
            done
          else
            errCode=1;
            echoerr "${errmsg} Data center \"${cluster}.${dataCenter}\" was not found";
            printf "%s\n" "${cluster}.${dataCenter}.";
          fi
        done
      else
        errCode=1;
        echoerr "${errmsg} Cluster \"${cluster}\" was not found";
        printf "%s\n" "${cluster}";
      fi
    done
  fi
  unset clusterList;
  unset dataCenterList;
  unset rackList;
  return ${errCode};
}

# Return a list of string, in a submitted list of string,
# which don't have statefulset
function checkStatefulSet {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local namespace="${1:?"${errmsg} Missing namespace"}";
  checkNamespace "${namespace}";
  if [[ ! ${?} -eq 0 ]];
  then
    return 1;
  fi
  local desireClusterList="";
  local desiredDataCenterList="";
  local desiredRackList="";
  local action="";
  local storageType="";
  local storageCapacity="";
  local limitCPU="";
  local limitMemory="";
  local requestCPU="";
  local requestMemory="";
  local maxHeapSize="";
  local heapNewSize="";
  local desiredReplicas="";
  local debug="";
  local filter;
  local option;
  shift 1;
  while [[ ${#} -gt 0 ]]
  do
    case "${1}" in
      "${DEBUG_OPTION}")
        debug="${1}";
        shift 1;
        ;;
      "${CREATEIFNOTEXIST_OPTION}"|"${RESTART_OPTION}"|"${SCALE_OPTION}")
        action="${1}";
        shift 1;
        ;;
      "${STORAGETYPE_OPTION}"| \
      "${STORAGECAPACITY_OPTION}"| \
      "${CPULIMIT_OPTION}"| \
      "${MEMORYLIMIT_OPTION}"| \
      "${CPUREQUEST_OPTION}"| \
      "${MEMORYREQUEST_OPTION}"| \
      "${MAXHEAPSIZE_OPTION}"| \
      "${NEWHEAPSIZE_OPTION}"| \
      "${REPLICAS_OPTION}")
        option="${1}";
        shift 1;
        if [[ "${1}" =~ ^-(.*)+$ ]];
        then
          echoerr "${errmsg} Missing value for option \"${option}\"";
          return 1;
        fi
        case "${option}" in
          "${STORAGETYPE_OPTION}")
            storageType="${1}";
            ;;
          "${STORAGECAPACITY_OPTION}")
            storageCapacity="${1}";
            ;;
          "${CPULIMIT_OPTION}")
            limitCPU="${1}";
            ;;
          "${MEMORYLIMIT_OPTION}")
            limitMemory="${1}";
            ;;
          "${CPUREQUEST_OPTION}")
            requestCPU="${1}";
            ;;
          "${MEMORYREQUEST_OPTION}")
            requestMemory="${1}";
            ;;
          "${MAXHEAPSIZE_OPTION}")
            maxHeapSize="${1}";
            ;;
          "${NEWHEAPSIZE_OPTION}")
            heapNewSize="${1}";
            ;;
          "${REPLICAS_OPTION}")
            desiredReplicas="${REPLICAS_OPTION} ${1}";
            ;;
        esac
        shift 1;
        ;;
      "${CLUSTER_OPTION}"|"${DATACENTER_OPTION}"|"${RACK_OPTION}")
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
            "${CLUSTER_OPTION}")
              desireClusterList="${filter}";
              ;;
            "${DATACENTER_OPTION}")
              desiredDataCenterList="${filter}";
              ;;
            "${RACK_OPTION}")
              desiredRackList="${filter}";
              ;;
          esac
        fi
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
  local cluster;
  local dataCenter;
  local rack;
  local err;
  local errCode;
  local errRackCode;
  local x;
  declare -A clusterList;
  declare -A dataCenterList;
  declare -A rackList;
  getTopology clusterList dataCenterList rackList;
  errCode=${?};
  if [[ ${errCode} -eq 0 ]];
  then
    for cluster in ${desireClusterList:-${!clusterList[*]}};
    do
      if [[ -n "${clusterList[${cluster}]}" ]];
      then
        for dataCenter in ${desiredDataCenterList:-${clusterList[${cluster}]}};
        do
          if [[ -n "${dataCenterList[${cluster}.${dataCenter}]}" ]];
          then
            x="${desiredRackList:-${dataCenterList[${cluster}.${dataCenter}]}}";
            # If the seed rack is in the rack list, we start the seed rack first
            if [[ -n "$(isInList "${SEED_RACK}" "${x}")" ]]
            then
              x="${SEED_RACK} $(removeList "${SEED_RACK}" "${x}")";
            fi
            for rack in ${x};
            do
              errRackCode=0;
              if [[ -n "${rackList[${cluster}.${dataCenter}.${rack}]}" ]];
              then
                err="$(kubectl get "${STATEFULSET_CLASS}" \
                  "${cluster,,}-${dataCenter,,}-${rack,,}" \
                  -n "${namespace}" 2>&1)";
                if [[ ${?} -eq 0 ]];
                then
                  case "${action}" in
                    "${RESTART_OPTION}")
                      restartStatefulSet \
                        "${namespace}" \
                        "${CLUSTER_OPTION}" "${cluster}" \
                        "${DATACENTER_OPTION}" "${dataCenter}" \
                        "${RACK_OPTION}" "${rack}" 1>/dev/null;
                      errRackCode=${?};
                      ;;
                    "${SCALE_OPTION}")
                      scaleStatefulSet \
                        "${namespace}" \
                        "${CLUSTER_OPTION}" "${cluster}" \
                        "${DATACENTER_OPTION}" "${dataCenter}" \
                        "${RACK_OPTION}" "${rack}" \
                        ${desiredReplicas} 1>/dev/null;
                      errRackCode=${?};
                      ;;
                    *)
                      if [[ -n "${debug}" ]];
                      then
                        echoerr "DEBUG: ${FUNCNAME[0]}: kubectl:" "${err}";
                      fi
                      ;;
                  esac
                else
                  if [[ "${action}" == "${CREATEIFNOTEXIST_OPTION}" ]];
                  then
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
                      ${desiredReplicas} 1>/dev/null;
                    errRackCode=${?};
                  else
                    errRackCode=1;
                    echoerr "${errmsg} kubectl:" "${err}";
                  fi
                fi
              else
                errRackCode=1;
                echoerr "${errmsg} Rack \"${cluster}.${dataCenter}.${rack}\" was not found";
              fi
              if [[ ! ${errRackCode} -eq 0 ]];
              then
                errCode=1;
                printf "%s\n" "${cluster}.${dataCenter}.${rack}";
              fi
            done
          else
            errCode=1;
            echoerr "${errmsg} Data center \"${cluster}.${dataCenter}\" was not found";
            printf "%s\n" "${cluster}.${dataCenter}";
          fi
        done
      else
        errCode=1;
        echoerr "${errmsg} Cluster \"${cluster}\" was not found";
        printf "%s\n" "${cluster}";
      fi
    done
  fi
  unset clusterList;
  unset dataCenterList;
  unset rackList;
  return ${errCode};
}
