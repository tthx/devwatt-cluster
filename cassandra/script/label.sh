NODE_CLASS="nodes";
NODE_SHORT="no";
NODE_OBJECT="node";

CLUSTER_LABEL="cassandra.cluster";
DATACENTER_LABEL="cassandra.dataCenter";
RACK_LABEL="cassandra.rack";
NODE_LABEL="cassandra.node";
INSTANCES_LABEL="cassandra.instances";
LABEL_LIST=( \
  "${CLUSTER_LABEL}" \
  "${DATACENTER_LABEL}" \
  "${RACK_LABEL}" \
  "${INSTANCES_LABEL}" );

SEED_RACK="${SEED_RACK:-"seed"}";

EQUAL_LABELS=0;
NOT_EQUAL_INSTANCES=1;
NOT_EQUAL=3;
NOT_CASSANDRA_NODE=4;

# Print the submitted string if it is a valid label
function isLabel {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local label="${1:?"${errmsg} Missing label"}";
  isInList "${label}" "${LABEL_LIST[*]}";
}

# Print a list of string, from a submitted list of string,
# which are not Kubernetes nodes
function isK8SNode {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local debug="";
  if [[ "${1}" == "${DEBUG_OPTION}" ]];
  then
    debug="${DEBUG_OPTION}";
    shift 1;
  fi
  local nodeList="${*:?"${errmsg} Missing list of Kubernetes node"}";
  local node;
  local err;
  local errCode=0;
  for node in ${nodeList};
  do
    err="$(kubectl get "${NODE_CLASS}" "${node}" 2>&1)";
    if [[ ${?} -eq 0  ]];
    then
      if [[ -n "${debug}" ]];
      then
        echoerr "DEBUG: ${FUNCNAME[0]}:" "${err}";
      fi
    else
      errCode=1;
      printf "%s\n" "${node}";
      echoerr "${errmsg} kubectl:" "${err}";
    fi
  done
  return ${errCode};
}

function getPodsOnNode {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local node="${1:?"${errmsg} Missing Kubernetes node"}";
  local err;
  local errCode;
  err="$(isCassandraNode "${node}")";
  errCode=${?};
  if [[ ${errCode} -eq 0 ]] && [[ -z "${err}" ]];
  then
    err="$(kubectl get "${PODS_CLASS}" \
      --all-namespaces \
      -o=custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,LABELS:.metadata.labels \
      2>&1)";
    errCode=${?};
    if [[ ${errCode} -eq 0 ]];
    then
      printf "%s\n" "${err}" | \
        awk \
          -v CLUSTER_LABEL="${CLUSTER_LABEL}" \
          -v DATACENTER_LABEL="${DATACENTER_LABEL}" \
          -v RACK_LABEL="${RACK_LABEL}" \
          -v node="${node}" '{ \
            cluster=0;
            dataCenter=0;
            rack=0;
            for(i=3; i<=NF; i++) { \
              if(match($i, CLUSTER_LABEL))
                cluster=1;
              if(match($i, DATACENTER_LABEL))
                dataCenter=1;
              if(match($i, RACK_LABEL))
                rack=1;
            } \
            if(node == $2 && cluster == 1 && dataCenter == 1 && rack == 1)
              print $1;
          }'
      errCode=${?};
    else
      echoerr "${errmsg} kubectl:" "${err}";
    fi
  fi
  return ${errCode};
}

# Print a list of string, from a submitted list of string,
# where label creation failed
function createNodeLabel {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local cluster="${1:?"${errmsg} Missing cluster"}";
  local dataCenter="${2:?"${errmsg} Missing data center"}";
  local rack="${3:?"${errmsg} Missing rack"}";
  local instances="${4:?"${errmsg} Missing instances"}";
  local overwrite="";
  if [[ "${5}" == "${OVERWRITE_OPTION}" ]];
  then
    overwrite="--overwrite";
    shift 5;
  else
    shift 4;
  fi
  local nodeList="${*:?"${errmsg} Missing list of Kubernetes node"}";
  local err;
  local errCode=0;
  local errNodeCode;
  local podList;
  local pvList;
  local nodeToDeleteList="";
  local nodeToLabelList="";
  for node in ${nodeList};
  do
    err="$(compareNodeLabel \
      "${node}" \
      "${cluster}" \
      "${dataCenter}" \
      "${rack}" \
      "${instances}")";
    errNodeCode=${?};
    if [[ ${errNodeCode} -eq 0 ]];
    then
      case "${err}" in
        "${EQUAL_LABELS}")
          echoerr "DEBUG: ${FUNCNAME[0]}: The node \"${node}\" is already labeled with equal values";
          ;;
        "${NOT_CASSANDRA_NODE}")
          nodeToLabelList="$(addList "${node}" "${nodeToLabelList}")";
          ;;
        "${NOT_EQUAL_INSTANCES}"|"${NOT_EQUAL}")
          podList="$(getPodsOnNode "${node}")";
          pvList="$(getObjectList \
            "x" "${PERSISTENTVOLUME_CLASS}" "${NODE_OPTION}" "${node}")";
          if [[ -n "${podList}" ]] || [[ -n "${pvList}" ]];
          then
            if [[ -n "${overwrite}" ]];
            then
              nodeToDeleteList="$(addList "${node}" "${nodeToDeleteList}")";
            else
              errNodeCode=1;
              if [[ -n "${podList}" ]];
              then
                echoerr "${errmsg} You can't create labels on node \"${node}\" because following pods:" "${podList}" "are running on it";
              fi
              if [[ -n "${pvList}" ]];
              then
                echoerr "${errmsg} You can't create labels on node \"${node}\" because following persistent volumes:" "${pvList}" "remain on it";
              fi
              echoerr "${errmsg} To create node labels, you must first delete corresponding statefulSets and/or persistent volumes, or delete the node, or use the ${OVERWRITE_OPTION} option to create node labels";
            fi
          else
            nodeToLabelList="$(addList "${node}" "${nodeToLabelList}")";
          fi
          ;;
      esac
    fi
    if [[ ! ${errNodeCode} -eq 0 ]];
    then
      errCode=1;
      printf "%s\n" "${node}";
    fi
  done
  if [[ -n "${nodeToDeleteList}" ]];
  then
    deleteNode "${nodeToDeleteList}";
    errCode=${?};
  fi
  for node in $(addList2List -l ${nodeToDeleteList} -l ${nodeToLabelList});
  do
    err="$(kubectl label "${NODE_CLASS}" "${node}" ${overwrite} \
      "${CLUSTER_LABEL}"="${cluster}" \
      "${DATACENTER_LABEL}"="${dataCenter}" \
      "${RACK_LABEL}"="${rack}" \
      "${INSTANCES_LABEL}"="${instances}" 2>&1)";
    if [[ ${?} -eq 0 ]];
    then
      echoerr "DEBUG: ${FUNCNAME[0]}: kubectl:" "${err}";
    else
      errCode=1;
      printf "%s\n" "${node}";
      echoerr "${errmsg} kubectl:" "${err}";
    fi
  done
  return ${errCode};
}

# Print a list of string, from a submitted list of string,
# where label deletion failed
function deleteNodeLabel {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local force="";
  if [[ "${1}" == "${FORCE_OPTION}" ]];
  then
    force="${1}";
    shift 1;
  fi
  local nodeList="${*:?"${errmsg} Missing list of Kubernetes node"}";
  local err;
  local errCode=0;
  local errNodeCode;
  local podList;
  local pvList;
  local nodeToDeleteList="";
  local nodeToLabelList="";
  for node in ${nodeList};
  do
    err="$(isCassandraNode "${node}")";
    errNodeCode=${?};
    if [[ -z "${err}" ]];
    then
      podList="$(getPodsOnNode "${node}")";
      pvList="$(getObjectList \
        "x" "${PERSISTENTVOLUME_CLASS}" "${NODE_OPTION}" "${node}")";
      if [[ -n "${podList}" ]] || [[ -n "${pvList}" ]];
      then
        if [[ -n "${force}" ]];
        then
          nodeToDeleteList="$(addList "${node}" "${nodeToDeleteList}")";
        else
          errNodeCode=1;
          if [[ -n "${podList}" ]];
          then
            echoerr "${errmsg} You can't create labels on node \"${node}\" because following pods:" "${podList}" "are running on it";
          fi
          if [[ -n "${pvList}" ]];
          then
            echoerr "${errmsg} You can't create labels on node \"${node}\" because following persistent volumes:" "${pvList}" "remain on it";
          fi
          echoerr "${errmsg} To delete node labels, you must first delete corresponding statefulSets and/or persistent volumes, or delete the node, or use the ${FORCE_OPTION} option to delete node labels";
        fi
      else
        nodeToLabelList="$(addList "${node}" "${nodeToLabelList}")";
      fi
    else
      echoerr "${errmsg} Node \"${node}\" is not a Cassandra node";
    fi
    if [[ ! ${errNodeCode} -eq 0 ]];
    then
      errCode=1;
      printf "%s\n" "${node}";
    fi
  done
  if [[ -n "${nodeToDeleteList}" ]];
  then
    deleteNode "${nodeToDeleteList}";
    errCode=${?};
  fi
  for node in ${nodeToLabelList};
  do
    err="$(kubectl label "${NODE_CLASS}" "${node}" \
      "${CLUSTER_LABEL}"- \
      "${DATACENTER_LABEL}"- \
      "${RACK_LABEL}"- \
      "${INSTANCES_LABEL}"- 2>&1)";
    if [[ ${?} -eq 0 ]];
    then
      echoerr "DEBUG: ${FUNCNAME[0]}: kubectl:" "${err}";
    else
      errCode=1;
      printf "%s\n" "${node}";
      echoerr "${errmsg} kubectl:" "${err}";
    fi
  done
  return ${errCode};
}

function deleteLabel {
  local force="";
  if [[ "${1}" == "${FORCE_OPTION}" ]];
  then
    force="${1}";
    shift 1;
  fi
  local nodeList;
  local errCode;
  nodeList="$(getObjectList \
    "x" \
    "${NODE_CLASS}" \
    "${@}")";
  errCode=${?};
  if [[ ${errCode} -eq 0 ]] && [[ -n "${nodeList}" ]];
  then
    deleteNodeLabel "${force}" ${nodeList};
    errCode=${?};
  else
    echoerr "DEBUG: ${FUNCNAME[0]}: No node to delete label";
  fi
  return ${errCode};
}

# Print a label's value of a Kubernetes object,
# Null if the submitted object is not a Kubernetes object
# or the submitted label is not a valid label
function getLabel {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local objectType="${1:?"${errmsg} Missing object type"}";
  local object="${2:?"${errmsg} Missing Kubernetes object"}";
  local label="${3:?"${errmsg} Missing label"}";
  local err;
  local errCode;
  err="$(kubectl label "${objectType}" "${object}" --list 2>&1)";
  errCode=${?};
  if [[ ${errCode} -eq 0 ]];
  then
    printf "%s\n" "${err}" | \
      awk -F= -v label="${label}" '{if($1 == label) print $2;}';
    errCode=${?};
  else
    echoerr "${errmsg} kubectl:" "${err}";
  fi
  return ${errCode};
}

# Print a list of string, from a submitted list of string,
# where label setting failed
function setLabel {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local objectType="${1:?"${errmsg} Missing object type"}";
  local label="${2:?"${errmsg} Missing label"}";
  local value="${3:?"${errmsg} Missing value"}";
  local overwrite="";
  if [[ "${4}" == "${OVERWRITE_OPTION}" ]];
  then
    overwrite="--overwrite";
    shift 4;
  else
    shift 3;
  fi
  local objectList="${*:?"${errmsg} Missing list of Kubernetes object"}";
  local object;
  local err;
  local errCode=0;
  for object in ${objectList};
  do
    err="$(kubectl label "${objectType}" "${object}" ${overwrite} \
      "${label}"="${value}" 2>&1)";
    if [[ ${?} -eq 0 ]];
    then
      echoerr "DEBUG: ${FUNCNAME[0]}: kubectl:" "${err}";
    else
      errCode=1;
      echoerr "${errmsg} kubectl:" "${err}";
      printf "%s\n" "${node}";
    fi
  done
  return ${errCode};
}

# Print a list of string, from a submitted list of string,
# which are not Cassandra nodes
function isCassandraNode {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local debug="";
  if [[ "${1}" == "${DEBUG_OPTION}" ]];
  then
    debug="${DEBUG_OPTION}";
    shift 1;
  fi
  local nodeList="${*:?"${errmsg} Missing list of Kubernetes node"}";
  local node;
  local err;
  local errCode=0;
  local nodeErrCode;
  for node in ${nodeList};
  do
    err="$(kubectl label "${NODE_CLASS}" "${node}" --list 2>&1)";
    nodeErrCode=${?};
    if [[ ${nodeErrCode} -eq 0 ]];
    then
      if [[ -z "$(printf "%s\n" "${err}" | \
        awk -F= \
          -v CLUSTER_LABEL="${CLUSTER_LABEL}" \
          -v DATACENTER_LABEL="${DATACENTER_LABEL}" \
          -v RACK_LABEL="${RACK_LABEL}" \
          -v INSTANCES_LABEL="${INSTANCES_LABEL}" \
          'BEGIN { \
            cluster=0; \
            dataCenter=0; \
            rack=0; \
            instances=0; \
          } { \
            if($1 == CLUSTER_LABEL) cluster=1; \
            if($1 == DATACENTER_LABEL) dataCenter=1; \
            if($1 == RACK_LABEL) rack=1; \
            if($1 == INSTANCES_LABEL) instances=1; \
          } END { \
            if(cluster == 1 && \
              dataCenter == 1 && \
              rack == 1 && \
              instances == 1) \
              print "1"; \
          }')" ]];
      then
        nodeErrCode=1;
        if [[ -n "${debug}" ]];
        then
          echoerr "${errmsg} Node \"${node}\" is not a Cassandra node";
        fi
      else
        if [[ -n "${debug}" ]];
        then
          echoerr "DEBUG: ${FUNCNAME[0]}: kubectl:" "${err}";
        fi
      fi
    else
      echoerr "${errmsg} kubectl:" "${err}";
    fi
    if [[ ! ${nodeErrCode} -eq 0 ]];
    then
      errCode=1;
      printf "%s\n" "${node}";
    fi
  done
  return ${errCode};
}

# Print:
# - EQUAL_LABELS, if the submitted node have labels equal values than
#   the submitted values
# - NOT_EQUAL_INSTANCES, if the submitted node have labels equal values than
#   the submitted values except instances
# - NOT_EQUAL, if the submitted node have cluster or data center or rack labels
#   not equal values than the submitted values
# - NOT_CASSANDRA_NODE, if the submitted node is not assigned in a Cassandra
#   cluster
function compareNodeLabel {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local node="${1:?"${errmsg} Missing Kubernetes node"}";
  local cluster="${2:?"${errmsg} Missing cluster"}";
  local dataCenter="${3:?"${errmsg} Missing data center"}";
  local rack="${4:?"${errmsg} Missing rack"}";
  local instances="${5:?"${errmsg} Missing instances"}";
  local err;
  local errCode;
  err="$(kubectl label "${NODE_CLASS}" ${node} --list 2>&1)";
  errCode=${?};
  if [[ ${errCode} -eq 0 ]];
  then
    printf "%s\n" "${err}" | \
      awk -F= \
        -v CLUSTER_LABEL="${CLUSTER_LABEL}" \
        -v DATACENTER_LABEL="${DATACENTER_LABEL}" \
        -v RACK_LABEL="${RACK_LABEL}"  \
        -v INSTANCES_LABEL="${INSTANCES_LABEL}" \
        -v EQUAL_LABELS="${EQUAL_LABELS}" \
        -v NOT_EQUAL_INSTANCES="${NOT_EQUAL_INSTANCES}" \
        -v NOT_EQUAL="${NOT_EQUAL}" \
        -v NOT_CASSANDRA_NODE="${NOT_CASSANDRA_NODE}" \
        -v cluster="${cluster}" \
        -v dataCenter="${dataCenter}" \
        -v rack="${rack}" \
        -v instances="${instances}" \
        'BEGIN { \
          currentCluster=""; \
          currentDataCenter=""; \
          currentRack=""; \
          currentInstances=""; \
        } { \
          if($1 == CLUSTER_LABEL) currentCluster=$2; \
          if($1 == DATACENTER_LABEL) currentDataCenter=$2; \
          if($1 == RACK_LABEL) currentRack=$2; \
          if($1 == INSTANCES_LABEL) currentInstances=$2; \
        } END { \
          if(cluster == "" || \
            dataCenter == "" || \
            rack == "" || \
            instances == "") \
            result=NOT_CASSANDRA_NODE; \
          else \
            if(cluster == currentCluster && \
              dataCenter == currentDataCenter && \
              rack == currentRack) \
              if(instances == currentInstances) \
                result=EQUAL_LABELS; \
              else \
                result=NOT_EQUAL_INSTANCES; \
            else \
              result=NOT_EQUAL; \
          printf("%d\n", result); \
        }';
    errCode=${?};
  else
    echoerr "${errmsg} kubectl:" "${err}";
  fi
  return ${errCode};
}

# Return a list of Kubernetes objects in a list of
# cluster/data center/rack
function getObjectList {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local namespace="${1:?"${errmsg} Missing namespace"}";
  local objectType="${2:?"${errmsg} Missing object type"}";
  case "${objectType}" in
    "${NODE_CLASS}"|"${PERSISTENTVOLUME_CLASS}"|"${PERSISTENTVOLUME_SHORT}")
      namespace="";
      ;;
    *)
      checkNamespace "${namespace}";
      if [[ ! ${?} -eq 0 ]];
      then
        return 1;
      fi
      namespace="-n ${namespace}";
      ;;
  esac
  shift 2;
  local label;
  local filter;
  local selector="";
  local err;
  local errCode=0;
  while [[ ${#} -gt 0 ]]
  do
    case "${1}" in
      "${CLUSTER_OPTION}"|"${DATACENTER_OPTION}"|"${RACK_OPTION}"|"${NODE_OPTION}")
        case "${1}" in
          "${CLUSTER_OPTION}")
            label="${CLUSTER_LABEL}";
            ;;
          "${DATACENTER_OPTION}")
            label="${DATACENTER_LABEL}";
            ;;
          "${RACK_OPTION}")
            label="${RACK_LABEL}";
            ;;
          "${NODE_OPTION}")
            label="${NODE_LABEL}";
            ;;
        esac
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
            filter="${1},${filter}";
          fi
          shift 1;
        done
        if [[ -n "${filter}" ]];
        then
          selector="${label} in (${filter%,}),${selector}";
          selector="${selector%,}";
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
  if [[ -n "${selector}" ]];
  then
    err="$(kubectl get "${objectType}" ${namespace} -l "${selector}" \
      -o=custom-columns=NAME:.metadata.name 2>&1)";
    errCode=${?};
    if [[ ${errCode} -eq 0 ]];
    then
      printf "%s\n" "${err}" | \
        awk 'NR>1{print $1;}';
      errCode=${?};
    else
      echoerr "${errmsg} kubectl:" "${err}";
    fi
  else
    err="$(kubectl get "${objectType}" ${namespace} \
      -o=custom-columns=NAME:.metadata.name,LABELS:.metadata.labels 2>&1)";
    errCode=${?};
    if [[ ${errCode} -eq 0 ]];
    then
      printf "%s\n" "${err}" | \
        awk -v CLUSTER_LABEL="${CLUSTER_LABEL}" \
          '{if(match($0, CLUSTER_LABEL)) print $1;}';
      errCode=${?};
    else
      echoerr "${errmsg} kubectl:" "${err}";
    fi
  fi
  return ${errCode};
}

# The main purpose of this function is to minimize access to Kubernetes
function getTopology {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local -n refClusterList="${1:?"${errmsg} Missing cluster array"}";
  local -n refDataCenterList="${2:?"${errmsg} Missing data center array"}";
  local -n refRackList="${3:?"${errmsg} Missing rack array"}";
  local line;
  local key;
  local cluster;
  local dataCenter;
  local rack;
  local node;
  local err;
  local errCode;
  refClusterList=();
  refDataCenterList=();
  refRackList=();
  err="$(kubectl get nodes \
    -o=custom-columns=NAME:.metadata.name,LABEL:.metadata.labels 2>&1)";
  errCode=${?};
  if [[ ${errCode} -eq 0 ]];
  then
    err="$(printf "%s\n" "${err}" | \
      awk -v CLUSTER_LABEL="${CLUSTER_LABEL}" \
        -v DATACENTER_LABEL="${DATACENTER_LABEL}" \
        -v RACK_LABEL="${RACK_LABEL}" \
        'NR>1 { \
          cluster=""; \
          dataCenter=""; \
          rack=""; \
          for(i=1; i<=NF; i++) { \
            if(match($i, CLUSTER_LABEL)) { \
              split($i, value, ":"); \
              cluster=value[2]; \
              sub("]", "", cluster); \
            } \
            if(match($i, DATACENTER_LABEL)) { \
              split($i, value, ":"); \
              dataCenter=value[2]; \
              sub("]", "", dataCenter); \
            } \
            if(match($i, RACK_LABEL)) { \
              split($i, value, ":"); \
              rack=value[2]; \
              sub("]", "", rack); \
            } \
          } \
          if(cluster!="" && dataCenter!="" && rack!="") { \
            printf("%s.%s.%s=%s\n", cluster, dataCenter, rack, $1); \
          } \
        }')";
    errCode=${?};
    if [[ ${errCode} -eq 0 ]];
    then
      for line in ${err};
      do
        key="${line%=*}";
        cluster="${key%%.*}";
        dataCenter="${key#*.}";
        dataCenter="${dataCenter%.*}";
        rack="${key##*.}";
        node="${line#*=}";
        if [[ -n "${cluster}" ]] && \
          [[ -n "${dataCenter}" ]] && \
          [[ -n "${rack}" ]];
        then
          refClusterList["${cluster}"]="$(addList "${dataCenter}" \
            "${refClusterList[${cluster}]}")";
          refDataCenterList["${cluster}.${dataCenter}"]="$(addList "${rack##*.}" \
            "${refDataCenterList[${cluster}.${dataCenter}]}")";
          refRackList["${cluster}.${dataCenter}.${rack}"]="$(addList "${node}" \
            "${refRackList[${cluster}.${dataCenter}.${rack}]}")";
        fi
      done
    else
      echoerr "${errmsg}" "${err}";
    fi
  else
    echoerr "${errmsg} kubectl:" "${err}";
  fi
  return ${errCode};
}

function getClusterList {
  local errCode;
  declare -A clusterList;
  declare -A dataCenterList;
  declare -A rackList;
  getTopology clusterList dataCenterList rackList;
  errCode=${?};
  printf "%s\n" "${!clusterList[@]}";
  unset clusterList;
  unset dataCenterList;
  unset rackList;
  return ${errCode};
}

function getDataCenterList {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local desireClusterList="${*}";
  local clusterPrefix;
  local nCluster="${#}";
  local cluster;
  local label;
  local errCode;
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
        clusterPrefix="${cluster}.";
        if [[ ${nCluster} -eq 1 ]];
        then
          clusterPrefix="";
        fi
        for label in ${clusterList[${cluster}]};
        do
          printf "%s%s\n" "${clusterPrefix}" "${label}";
        done
      else
        echoerr "${errmsg} Cluster \"${cluster}\" was not found";
      fi
    done
  fi
  unset clusterList;
  unset dataCenterList;
  unset rackList;
  return ${errCode};
}

function getRackList {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local desireClusterList="";
  local desiredDataCenterList="";
  local nCluster=0;
  local nDataCenter=0;
  local n;
  local filter;
  local option;
  while [[ ${#} -gt 0 ]]
  do
    case "${1}" in
      "${CLUSTER_OPTION}"|"${DATACENTER_OPTION}")
        option="${1}";
        shift 1;
        filter="";
        n=0;
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
          n=$((${n}+1));
          shift 1;
        done
        if [[ -n "${filter}" ]];
        then
          case "${option}" in
            "${CLUSTER_OPTION}")
              desireClusterList="${filter}";
              nCluster=${n};
              ;;
            "${DATACENTER_OPTION}")
              desiredDataCenterList="${filter}";
              nDataCenter=${n};
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
  local clusterPrefix;
  local dataCenterPrefix;
  local cluster;
  local dataCenter;
  local label;
  local errCode;
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
        clusterPrefix="${cluster}.";
        for dataCenter in ${desiredDataCenterList:-${clusterList[${cluster}]}};
        do
          if [[ -n "${dataCenterList[${cluster}.${dataCenter}]}" ]];
          then
            dataCenterPrefix="${dataCenter}.";
            if [[ ${nCluster} -eq 1 ]] && \
              [[ ${nDataCenter} -eq 1 ]];
            then
              clusterPrefix="";
              dataCenterPrefix="";
            fi
            for label in ${dataCenterList[${cluster}.${dataCenter}]};
            do
              printf "%s%s%s\n" "${clusterPrefix}" "${dataCenterPrefix}" "${label}";
            done
          else
            errCode=1;
            echoerr "${errmsg} Data center \"${cluster}.${dataCenter}\" was not found";
          fi
        done
      else
        errCode=1;
        echoerr "${errmsg} Cluster \"${cluster}\" was not found";
      fi
    done
  fi
  unset clusterList;
  unset dataCenterList;
  unset rackList;
  return ${errCode};
}

function getNodeList {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local desireClusterList="";
  local desiredDataCenterList="";
  local desiredRackList="";
  local nCluster=0;
  local nDataCenter=0;
  local nRack=0;
  local n;
  local filter;
  local option;
  while [[ ${#} -gt 0 ]]
  do
    case "${1}" in
      "${CLUSTER_OPTION}"|"${DATACENTER_OPTION}"|"${RACK_OPTION}")
        option="${1}";
        shift 1;
        filter="";
        n=0;
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
          n=$((${n}+1));
          shift 1;
        done
        if [[ -n "${filter}" ]];
        then
          case "${option}" in
            "${CLUSTER_OPTION}")
              desireClusterList="${filter}";
              nCluster=${n};
              ;;
            "${DATACENTER_OPTION}")
              desiredDataCenterList="${filter}";
              nDataCenter=${n};
              ;;
            "${RACK_OPTION}")
              desiredRackList="${filter}";
              nRack=${n};
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
  local clusterPrefix;
  local dataCenterPrefix;
  local rackPrefix;
  local cluster;
  local dataCenter;
  local rack;
  local label;
  local errCode;
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
        clusterPrefix="${cluster}.";
        for dataCenter in ${desiredDataCenterList:-${clusterList[${cluster}]}};
        do
          if [[ -n "${dataCenterList[${cluster}.${dataCenter}]}" ]];
          then
            dataCenterPrefix="${dataCenter}.";
            for rack in ${desiredRackList:-${dataCenterList[${cluster}.${dataCenter}]}};
            do
              if [[ -n "${rackList[${cluster}.${dataCenter}.${rack}]}" ]];
              then
                rackPrefix="${rack}=";
                if [[ ${nCluster} -eq 1 ]] && \
                  [[ ${nDataCenter} -eq 1 ]] && \
                  [[ ${nRack} -eq 1 ]];
                then
                  clusterPrefix="";
                  dataCenterPrefix="";
                  rackPrefix="";
                fi
                for label in ${rackList[${cluster}.${dataCenter}.${rack}]};
                do
                  printf "%s%s%s%s\n" \
                    "${clusterPrefix}" \
                    "${dataCenterPrefix}" \
                    "${rackPrefix}" \
                    "${label}";
                done
              else
                errCode=1;
                echoerr "${errmsg} Rack \"${cluster}.${dataCenter}.${rack}\" was not found";
              fi
            done
          else
            errCode=1;
            echoerr "${errmsg} Data center \"${cluster}.${dataCenter}\" was not found";
          fi
        done
      else
        errCode=1;
        echoerr "${errmsg} Cluster \"${cluster}\" was not found";
      fi
    done
  fi
  unset clusterList;
  unset dataCenterList;
  unset rackList;
  return ${errCode};
}

function sumNodeInstances {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local nodeList="${*:?"${errmsg} Missing list of Kubernetes node"}";
  local errCode;
  err="$(kubectl label nodes ${nodeList} --list 2>&1)";
  errCode=${?};
  if [[ ${errCode} -eq 0 ]];
  then
    printf "%s\n" "${err}" | \
      awk -F= -v INSTANCES_LABEL="${INSTANCES_LABEL}" \
        'BEGIN{ sum=0; } { \
          if(match($1, INSTANCES_LABEL)) sum+=$2; \
        } END {print sum;}'
    errCode=${?};
  else
    echoerr "${errmsg} kubectl:" "$(printf "%s\n" "${err}" | \
      awk '$1~/^Error/{print $0}')";
  fi
  return ${errCode};
}

function sumInstances {
  local nodeList;
  local errCode;
  nodeList="$(getObjectList "x" "${NODE_CLASS}" "${@}")";
  errCode=${?};
  if [[ ${errCode} -eq 0 ]] && [[ -n "${nodeList}" ]];
  then
    sumNodeInstances ${nodeList};
    errCode=${?};
  else
    echoerr "DEBUG: ${FUNCNAME[0]}: No node to sum instances";
  fi
  return ${errCode};
}
