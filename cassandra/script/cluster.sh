CASSANDRA_STATUS_UP="UN";

function clustertool {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local namespace="${1:?"${errmsg} Missing namespace"}";
  checkNamespace "${namespace}";
  if [[ ! ${?} -eq 0 ]];
  then
    return 1;
  fi
  local args="";
  local clusterList="";
  local dataCenterList="";
  local rackList="";
  local instanceList="";
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
      --)
        shift 1;
        args="${*}";
        shift ${#};
        ;;
      "${CLUSTER_OPTION}"|"${DATACENTER_OPTION}"|"${RACK_OPTION}"|"${INSTANCE_OPTION}")
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
              clusterList="${filter}";
              ;;
            "${DATACENTER_OPTION}")
              dataCenterList="${filter}";
              ;;
            "${RACK_OPTION}")
              rackList="${filter}";
              ;;
            "${INSTANCE_OPTION}")
              instanceList="${filter}";
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
  if [[ -z "${args}" ]];
  then
    echoerr "${errmsg} Missing nodetool arguments";
    return 1;
  fi
  local nodeList;
  local errCode;
  nodeList="$(getObjectList \
    "x" \
    "${NODE_CLASS}" \
    "${CLUSTER_OPTION}" "${clusterList}" \
    "${DATACENTER_OPTION}" "${dataCenterList}" \
    "${RACK_OPTION}" "${rackList}")";
  errCode=${?};
  if [[ ${errCode} -eq 0 ]] && [[ -n "${nodeList}" ]];
  then
    nodetool "${namespace}" \
      "${debug}" \
      "${NODE_OPTION}" "${nodeList}" \
      "${INSTANCE_OPTION}" "${instanceList}" \
      -- "${args}";
    errCode=${?};
  else
    echoerr "DEBUG: ${FUNCNAME[0]}: No node for nodetool";
  fi
  return ${errCode};
}

function searchInArray {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local -n localArray="${1:?"${errmsg} Missing array"}";
  local cluster="${2}";
  local dataCenter="${3}";
  local rack="${4}";
  local node="${5}";
  local result="";
  if [[ -n "${cluster}" ]];
  then
    result="${localArray["${cluster}"]:-${result}}";
    if [[ -n "${dataCenter}" ]];
    then
      result="${localArray["${cluster}.${dataCenter}"]:-${result}}";
      if [[ -n "${rack}" ]];
      then
        result="${localArray["${cluster}.${dataCenter}.${rack}"]:-${result}}";
        if [[ -n "${node}" ]];
        then
          result="${localArray["${cluster}.${dataCenter}.${rack}.${node}"]:-${result}}";
        fi
      fi
    fi
  fi
  printf "%s\n" "${result}";
}

function createCluster {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local propertiesFile="${1:?"${errmsg} Missing properties file"}";
  if [[ ! -f "${propertiesFile}" ]];
  then
    echoerr "${errmsg} File \"${propertiesFile}\" was not found.";
    return 1;
  fi
  local overwrite="";
  local key;
  local value;
  local namespace;
  local cluster;
  local dataCenter;
  local rack;
  local nodeList;
  local node;
  local pod;
  local ip;
  local line;
  local storageType;
  local dataDirectory;
  local capacity;
  local limitCPU;
  local limitMemory;
  local requestCPU;
  local requestMemory;
  local maxHeapSize;
  local heapNewSize;
  local instances;
  local replicas;
  local index;
  local err;
  local currentCluster;
  local currentDataCenter;
  local currentRack;
  local currentInstances;
  declare -A modifiedRackList;
  declare -A storageTypeList;
  declare -A dataDirectoryList;
  declare -A capacityList;
  declare -A storageCapacityList;
  declare -A limitCPUList;
  declare -A limitMemoryList;
  declare -A requestCPUList;
  declare -A requestMemoryList;
  declare -A maxHeapSizeList;
  declare -A heapNewSizeList;
  declare -A instancesList;
  declare -A replicasList;
  declare -A currentClusterList;
  declare -A currentDataCenterList;
  declare -A currentRackList;
  declare -A clusterList;
  declare -A dataCenterList;
  declare -A rackList;
  declare -A newDataCenterList;
  # Read file ${propertiesFile} line by line and label Kubernetes nodes.
  # A line has the format key=value
  # Where "=" is the separator between a key and its value.
  line=0;
  while IFS='=' read -r key value;
  do
    line=$((${line}+1));
    if [[ ! "${key}" =~ ^[[:space:]]*#+(.*)?$ ]] && [[ -n "${key}" ]];
    then
      if [[ -z "${value}" ]];
      then
        echoerr "${errmsg} Key \"${key}\" at line \"${line}\" in file \"${propertiesFile}\" has no value.";
        return 1;
      fi
      key="${key//[[:space:]]/}";
      value="${value%%#*}";
      case "${key}" in
        namespace)
          namespace="${value}";
          ;;
        overwrite)
          if [[ "${value,,}" =~ ^[[:space:]]*true[[:space:]]*$ ]] || \
            [[ ${value} -eq 1 ]];
          then
            overwrite="${OVERWRITE_OPTION}";
          fi
          ;;
        persistentVolume\.storageType\.*)
          storageTypeList["${key/persistentVolume\.storageType\./}"]="$(checkStorageType "${value}" "${DEBUG_OPTION}")";
          if [[ ! ${?} -eq 0 ]];
          then
            echoerr "${errmsg} The value (${value}) of the key \"${key}\" at line \"${line}\" in file \"${propertiesFile}\" is incorrect";
            return 1;
          fi
          ;;
        persistentVolume\.dataDirectory\.*)
          dataDirectoryList["${key/persistentVolume\.dataDirectory\./}"]="${value}";
          ;;
        persistentVolume\.capacity\.*)
          capacityList["${key/persistentVolume\.capacity\./}"]="${value}";
          ;;
        statefulSet\.storageCapacity\.*)
          storageCapacityList["${key/statefulSet\.storageCapacity\./}"]="${value}";
          ;;
        statefulSet\.resource\.limit\.cpu\.*)
          limitCPUList["${key/statefulSet\.resource\.limit\.cpu\./}"]="${value}";
          ;;
        statefulSet\.resource\.limit\.memory\.*)
          limitMemoryList["${key/statefulSet\.resource\.limit\.memory\./}"]="${value}";
          ;;
        statefulSet\.resource\.request\.cpu\.*)
          requestCPUList["${key/statefulSet\.resource\.request\.cpu./}"]="${value}";
          ;;
        statefulSet\.resource\.request\.memory\.*)
          requestMemoryList["${key/statefulSet\.resource\.request\.memory./}"]="${value}";
          ;;
        statefulSet\.env\.maxHeapSize\.*)
          maxHeapSizeList["${key/statefulSet\.env\.maxHeapSize\./}"]="${value}";
          ;;
        statefulSet\.env\.heapNewSize\.*)
          heapNewSizeList["${key/statefulSet\.env\.heapNewSize\./}"]="${value}";
          ;;
        statefulSet\.replicas\.*)
          if [[ ${value} -le 0 ]];
            then
              echoerr "${errmsg} The value (${value}) of the key \"${key}\" at line \"${line}\" in properties file \"${propertiesFile}\" must be > 0";
              return 1;
            fi
            replicasList["${key/statefulSet\.replicas\./}"]="${value}";
          ;;
        instances\.*)
          if [[ ${value} -le 0 ]];
            then
              echoerr "${errmsg} The value (${value}) of the key \"${key}\" at line \"${line}\" in file \"${propertiesFile}\" must be > 0";
              return 1;
            fi
            instancesList["${key/instances\./}"]="${value}";
          ;;
        *)
          if [[ ! "${key}" =~ ^(.+)\.(.+)\.(.+)$ ]];
          then
            echoerr "${errmsg} Key \"${key}\" at line \"${line}\" in properties file \"${propertiesFile}\" has a wrong format (i.e.: <cluser>.<dataCenter>.<rack>)";
            return 1;
          fi
          for node in ${value};
          do
            if [[ -n "$(isK8SNode "${node}")" ]];
            then
              echoerr "${errmsg} \"${node}\" at line \"${line}\" in properties file \"${propertiesFile}\" is not a node in your Kubernetes cluster";
              return 1;
            fi
            if [[ -z "${overwrite}" ]] && \
              [[ -z "$(isCassandraNode "${node}")" ]];
            then
              echoerr "${errmsg} Node \"${node}\" at line \"${line}\" in properties file \"${propertiesFile}\" is already labeled.";
              return 1;
            fi
            if [[ -z "${overwrite}" ]] && \
              [[ -z "$(checkNodePersistentVolume "${node}")" ]];
            then
              echoerr "${errmsg} Node \"${node}\" at line \"${line}\" in properties file \"${propertiesFile}\" has already persistent volume.";
              return 1;
            fi
          done
          # Here, we process a cluster definition.
          # The format of key is: <cluster>.<dataCenter>.<rack>,
          # with '.' as a sepator.
          # The value is a Kubernetes nodes list, each node is
          # separated with space characters.
          cluster="${key%%.*}";
          dataCenter="${key#*.}";
          dataCenter="${dataCenter%.*}";
          rack="${key##*.}";
          clusterList["${cluster}"]="$(addList \
            "${dataCenter}" \
            "${clusterList["${cluster}"]}")";
          dataCenterList["${cluster}.${dataCenter}"]="$(addList \
            "${rack}" \
            "${dataCenterList["${cluster}.${dataCenter}"]}")";
          for i in ${!rackList[*]};
          do
            if [[ "${i}" != "${key}" ]];
            then
              for node in ${value};
              do
                if [[ -n "$(isInList "${node}" "${rackList["${i}"]}")" ]];
                then
                  echoerr "${errmsg} The node \"${node}\" at line \"${line}\" in properties file \"${propertiesFile}\" appears more than once:";
                  echoerr "${errmsg} It appears in rack \"${i}\"";
                  echoerr "${errmsg} And in rack \"${key}\"";
                  return 1;
                fi
              done
            fi
          done
          rackList["${cluster}.${dataCenter}.${rack}"]="$(addList \
            "${value}" \
            "${rackList["${cluster}.${dataCenter}.${rack}"]}")";
        ;;
      esac
    fi
  done < "${propertiesFile}"

  namespace="${namespace:?"${errmsg} No namespace was found in properties file \"${propertiesFile}\""}";

  # Create namespace if not exist.
  checkNamespace "${namespace}" "${CREATEIFNOTEXIST_OPTION}";
  if [[ ! ${?} -eq 0 ]];
  then
    return 1;
  fi

  if [[ ${#storageTypeList[*]} -eq 0 ]];
  then
    echoerr "${errmsg} No storage type was found in properties file \"${propertiesFile}\"";
    return 1;
  fi

  if [[ ${#dataDirectoryList[*]} -eq 0 ]];
  then
    echoerr "${errmsg} No persistent volume directory was found in properties file \"${propertiesFile}\"";
    return 1;
  fi

  if [[ ${#capacityList[*]} -eq 0 ]];
  then
    echoerr "${errmsg} No persistent volume capacity was found in properties file \"${propertiesFile}\"";
    return 1;
  fi

  if [[ ${#storageCapacityList[*]} -eq 0 ]];
  then
    echoerr "${errmsg} No storage capacity was found in properties file \"${propertiesFile}\"";
    return 1;
  fi

  if [[ ${#limitCPUList[*]} -eq 0 ]];
  then
    echoerr "${errmsg} No CPU limits was found in properties file \"${propertiesFile}\"";
    return 1;
  fi

  if [[ ${#limitMemoryList[*]} -eq 0 ]];
  then
    echoerr "${errmsg} No memory limits was found in properties file \"${propertiesFile}\"";
    return 1;
  fi

  if [[ ${#requestCPUList[*]} -eq 0 ]];
  then
    echoerr "${errmsg} No CPU requests was found in properties file \"${propertiesFile}\"";
    return 1;
  fi

  if [[ ${#requestMemoryList[*]} -eq 0 ]];
  then
    echoerr "${errmsg} No memory requests was found in properties file \"${propertiesFile}\"";
    return 1;
  fi

  if [[ ${#maxHeapSizeList[*]} -eq 0 ]];
  then
    echoerr "${errmsg} No max heap size was found in properties file \"${propertiesFile}\"";
    return 1;
  fi

  if [[ ${#heapNewSizeList[*]} -eq 0 ]];
  then
    echoerr "${errmsg} No new heap size was found in properties file \"${propertiesFile}\"";
    return 1;
  fi

  if [[ ${#instancesList[*]} -eq 0 ]];
  then
    echoerr "${errmsg} No instances was found in properties file \"${propertiesFile}\"";
    return 1;
  fi

  if [[ ${#clusterList[*]} -eq 0 ]];
  then
    echoerr "${errmsg} No cluster was found in properties file \"${propertiesFile}\"";
    return 1;
  fi

  if [[ ${#dataCenterList[*]} -eq 0 ]];
  then
    echoerr "${errmsg} No data center was found in properties file \"${propertiesFile}\"";
    return 1;
  fi

  if [[ ${#rackList[*]} -eq 0 ]];
  then
    echoerr "${errmsg} No rack was found in properties file \"${propertiesFile}\"";
    return 1;
  fi

  # TODO: Compare persistent volume capacity with volume claim storage

  # Retrieve current topology
  getTopology currentClusterList currentDataCenterList currentRackList;
  if [[ ! ${?} -eq 0 ]];
  then
    echoerr "${errmsg} Error occurred when retrieving current topology";
    return 1;
  fi

  # If we allowed to overwrite existing Cassandra nodes,
  # we remove modified nodes
  echoerr "DEBUG: ${FUNCNAME[0]}: Removing modified Cassandra nodes...";
  nodeList="";
  for index in ${!rackList[*]};
  do
    cluster="${index%%.*}";
    dataCenter="${index#*.}";
    dataCenter="${dataCenter%.*}";
    rack="${index##*.}";
    for node in ${rackList["${index}"]};
    do
      instances="$(searchInArray \
        instancesList \
        "${cluster}" \
        "${dataCenter}" \
        "${rack}" \
        "${node}")";
      if [[ -z "${instances}" ]];
      then
        echoerr "${errmsg} No instances was found for node \"${node}\" in rack \"${cluster}.${dataCenter}.${rack}\"";
        return 1;
      fi
      currentCluster="$(getLabel "${NODE_CLASS}" "${node}" "${CLUSTER_LABEL}")";
      currentDataCenter="$(getLabel "${NODE_CLASS}" "${node}" "${DATACENTER_LABEL}")";
      currentRack="$(getLabel "${NODE_CLASS}" "${node}" "${RACK_LABEL}")";
      currentInstances="$(getLabel "${NODE_CLASS}" "${node}" "${INSTANCES_LABEL}")";
      if [[ -n "${currentCluster}" && \
        -n "${currentDataCenter}" && \
        -n "${currentRack}" && \
        -n "${currentInstances}" ]] && \
        [[ "${currentCluster}" != "${cluster}" ||
        "${currentDataCenter}" != "${dataCenter}" || \
        "${currentRack}" != "${rack}" || \
        "${currentInstances}" != "${instances}" ]];
      then
        modifiedRackList["${currentCluster}.${currentDataCenter}"]="$(addList \
          "${currentRack}" \
          "${modifiedRackList["${currentCluster}.${currentDataCenter}"]}")";
        nodeList="$(addList \
          "${node}" \
          "${nodeList}")";
        echoerr "DEBUG: ${FUNCNAME[0]}: Node \"${node}\" currently in rack \"${currentCluster}.${currentDataCenter}.${currentRack}\" was modified";
      fi
    done
  done
  if [[ -n "${nodeList}" ]];
  then
    err="$(deleteNode "${nodeList}")";
    if [[ ! ${?} -eq 0 ]];
    then
      echoerr "${errmsg} Unable to delete nodes \"${err}\"";
      return 1;
    fi
  fi
  echoerr "DEBUG: ${FUNCNAME[0]}: ...Modified Cassandra nodes removed";

  # Looking for new data centers
  for cluster in ${!clusterList[*]};
  do
    if [[ -n "${currentClusterList["${cluster}"]}" ]];
    then
      for dataCenter in ${clusterList["${cluster}"]};
      do
        if [[ -z "$(isInList \
          "${dataCenter}" \
          "${currentClusterList["${cluster}"]}")" ]];
        then
          echoerr "DEBUG: ${FUNCNAME[0]}: Cluster \"${cluster}\" has a new data center \"${dataCenter}\"";
          newDataCenterList["${cluster}"]="$(addList \
            "${dataCenter}" \
            "${newDataCenterList["${cluster}"]}")";
        fi
      done
    fi
  done

  # Assign Kubernetes nodes in Cassandra cluster,
  # create storage class and create persistent volumes
  for index in ${!rackList[*]};
  do
    cluster="${index%%.*}";
    dataCenter="${index#*.}";
    dataCenter="${dataCenter%.*}";
    rack="${index##*.}";
    for node in ${rackList["${index}"]};
    do
      # Assign Kubernetes nodes in Cassandra cluster
      instances="$(searchInArray \
        instancesList \
        "${cluster}" \
        "${dataCenter}" \
        "${rack}" \
        "${node}")";
      if [[ -z "${instances}" ]];
      then
        echoerr "${errmsg} No instances was found for node \"${node}\" in rack \"${cluster}.${dataCenter}.${rack}\"";
        return 1;
      fi

      err="$(createNodeLabel \
        "${cluster}" \
        "${dataCenter}" \
        "${rack}" \
        "${instances}" \
        "${overwrite}" \
        "${node}")";
      if [[ ! ${?} -eq 0 ]];
      then
        echoerr "${errmsg} Unable to label nodes \"${err}\"";
        return 1;
      fi

      # Create storage class if it not exist.
      storageType="$(searchInArray \
        storageTypeList \
        "${cluster}" \
        "${dataCenter}" \
        "${rack}")";
      if [[ -z "${storageType}" ]];
      then
        echoerr "${errmsg} No storage type was found for rack \"${cluster}.${dataCenter}.${rack}\"";
        return 1;
      fi

      checkStorageClass \
        "${storageType}" \
        "${CREATEIFNOTEXIST_OPTION}";
      if [[ ! ${?} -eq 0 ]];
      then
        echoerr "${errmsg} Unable to create storage class for type \"${storageType}\"";
        return 1;
      fi

      # Create persistent volume
      dataDirectory="$(searchInArray \
        dataDirectoryList \
        "${cluster}" \
        "${dataCenter}" \
        "${rack}" \
        "${node}")";
      if [[ -z "${dataDirectory}" ]];
      then
        echoerr "${errmsg} No persistent volume directory was found for node \"${node}\" in rack \"${cluster}.${dataCenter}.${rack}\"";
        return 1;
      fi

      capacity="$(searchInArray \
        capacityList \
        "${cluster}" \
        "${dataCenter}" \
        "${rack}" \
        "${node}")";
      if [[ -z "${capacity}" ]];
      then
        echoerr "${errmsg} No persistent volume capacity was found for node \"${node}\" in rack \"${cluster}.${dataCenter}.${rack}\"";
        return 1;
      fi

      err="$(createNodePersistentVolume \
        "${storageType}" \
        "${dataDirectory}" \
        "${capacity}" \
        "${overwrite}" \
        "${node}")";
      if [[ ! ${?} -eq 0 ]];
      then
        echoerr "${errmsg} Unable to create persistent volumes for nodes:" "${err}";
        return 1;
      fi
    done
  done

  # Check if data centers to update have a seed rack.
  for cluster in ${!clusterList[*]};
  do
    for dataCenter in ${clusterList["${cluster}"]};
    do
      if [[ -z "$(isInList \
        "${SEED_RACK}" \
        "${dataCenterList["${cluster}.${dataCenter}"]}")" ]];
      then
        if [[ -z "${currentRackList["${cluster}.${dataCenter}.${SEED_RACK}"]}" ]];
        then
          echoerr "${errmsg} The data center \"${cluster}.${dataCenter}\" has no seed rack.";
          return 1;
        fi
      else
        # If the seed rack is in the rack list, we start the seed rack first
        dataCenterList["${cluster}.${dataCenter}"]="${SEED_RACK} \
          $(removeList \
            "${SEED_RACK}" \
            "${dataCenterList["${cluster}.${dataCenter}"]}")";
      fi
    done
  done

  # Restart current racks if new data centers are added
  if [[ ${#newDataCenterList[*]} -gt 0 ]];
  then
    echoerr "DEBUG: ${FUNCNAME[0]}: New data centers were added, so we restart unmodified current racks...";
    for dataCenter in ${!currentDataCenterList[*]};
    do
      for rack in ${currentDataCenterList["${dataCenter}"]};
      do
        if [[ -z "$(isInList "${rack}" "${dataCenterList["${dataCenter}"]}")" ]];
        then
          restartStatefulSet \
            "${namespace}" \
            "${CLUSTER_OPTION}" "${dataCenter%%.*}" \
            "${DATACENTER_OPTION}" "${dataCenter##*.}" \
            "${RACK_OPTION}" "${rack}";
          if [[ ! ${?} -eq 0 ]];
          then
            echoerr "${errmsg} Failed to restart rack \"${dataCenter}.${rack}\"";
            return 1;
          fi
        fi
      done
    done
    echoerr "DEBUG: ${FUNCNAME[0]}: ...Current racks restarted";
  fi

  # Create client service, data center service and statefulSet
  for cluster in ${!clusterList[*]};
  do
    # Create client service if not exist
    err="$(checkClientService "${namespace}" \
      "${CLUSTER_OPTION}" "${cluster}" "${CREATEIFNOTEXIST_OPTION}")";
    if [[ ! ${?} -eq 0 ]];
    then
      echoerr "${errmsg} Unable to create client service for cluster \"${err}\"";
      return 1;
    fi

    for dataCenter in ${clusterList["${cluster}"]};
    do
      # Create data center service if not exist
      err="$(checkDataCenterService "${namespace}" \
        "${CLUSTER_OPTION}" "${cluster}" \
        "${DATACENTER_OPTION}" "${dataCenter}" \
        "${CREATEIFNOTEXIST_OPTION}")";
      if [[ ! ${?} -eq 0 ]];
      then
        echoerr "${errmsg} Unable to create data center service for data center \"${err}\"";
        return 1;
      fi

      # Create statefulSet
      for rack in ${dataCenterList["${cluster}.${dataCenter}"]};
      do
        index="${cluster}.${dataCenter}.${rack}";
        storageType="$(searchInArray \
          storageTypeList \
          "${cluster}" \
          "${dataCenter}" \
          "${rack}")";
        if [[ -z "${storageType}" ]];
        then
          echoerr "${errmsg} No storage type was found for rack \"${index}\"";
          return 1;
        fi

        storageCapacity="$(searchInArray \
          storageCapacityList \
          "${cluster}" \
          "${dataCenter}" \
          "${rack}")";
        if [[ -z "${storageCapacity}" ]];
        then
          echoerr "${errmsg} No volume claim storage capacity was found for rack \"${index}\"";
          return 1;
        fi

        limitCPU="$(searchInArray \
          limitCPUList \
          "${cluster}" \
          "${dataCenter}" \
          "${rack}")";
        if [[ -z "${limitCPU}" ]];
        then
          echoerr "${errmsg} No CPU limit was found for rack \"${index}\"";
          return 1;
        fi

        limitMemory="$(searchInArray \
          limitMemoryList \
          "${cluster}" \
          "${dataCenter}" \
          "${rack}")";
        if [[ -z "${limitMemory}" ]];
        then
          echoerr "${errmsg} No memory limit was found for rack \"${index}\"";
          return 1;
        fi

        requestCPU="$(searchInArray \
          requestCPUList \
          "${cluster}" \
          "${dataCenter}" \
          "${rack}")";
        if [[ -z "${requestCPU}" ]];
        then
          echoerr "${errmsg} No CPU request was found for rack \"${index}\"";
          return 1;
        fi

        requestMemory="$(searchInArray \
          requestMemoryList \
          "${cluster}" \
          "${dataCenter}" \
          "${rack}")";
        if [[ -z "${requestMemory}" ]];
        then
          echoerr "${errmsg} No memory request was found for rack \"${index}\"";
          return 1;
        fi

        maxHeapSize="$(searchInArray \
          maxHeapSizeList \
          "${cluster}" \
          "${dataCenter}" \
          "${rack}")";
        if [[ -z "${maxHeapSize}" ]];
        then
          echoerr "${errmsg} No max heap size was found for rack \"${index}\"";
          return 1;
        fi

        heapNewSize="$(searchInArray \
          heapNewSizeList \
          "${cluster}" \
          "${dataCenter}" \
          "${rack}")";
        if [[ -z "${heapNewSize}" ]];
        then
          echoerr "${errmsg} No new heap size was found for rack \"${index}\"";
          return 1;
        fi

        replicas="$(searchInArray \
            replicasList \
            "${cluster}" \
            "${dataCenter}" \
            "${rack}")";
        if [[ -n "${replicas}" ]];
        then
          replicas="${REPLICAS_OPTION} ${replicas}";
        fi

        err="$(createStatefulSet \
          "${namespace}" \
          "${CLUSTER_OPTION}" "${cluster}" \
          "${DATACENTER_OPTION}" "${dataCenter}" \
          "${RACK_OPTION}" "${rack}" \
          "${STORAGETYPE_OPTION}" "${storageType}" \
          "${STORAGECAPACITY_OPTION}" "${storageCapacity}" \
          "${CPULIMIT_OPTION}" "${limitCPU}" \
          "${MEMORYLIMIT_OPTION}" "${limitMemory}" \
          "${CPUREQUEST_OPTION}" "${requestCPU}" \
          "${MEMORYREQUEST_OPTION}" "${requestMemory}" \
          "${MAXHEAPSIZE_OPTION}" "${maxHeapSize}" \
          "${NEWHEAPSIZE_OPTION}" "${heapNewSize}" \
          "${overwrite}" \
          ${replicas})";
        if [[ ! ${?} -eq 0 ]];
        then
          echoerr "${errmsg} Unable to create statefulSet:" "${err}";
          return 1;
        fi
      done
    done
  done

  # Wait until all new Cassandra nodes are running
  echoerr "DEBUG: ${FUNCNAME[0]}: Wait until all new/modified/restarted Cassandra nodes are running...";
  nodeList="";
  for index in ${!dataCenterList[*]};
  do
    for rack in ${dataCenterList["${index}"]};
    do
      nodeList="$(addList2List \
        -l "${nodeList}" \
        -l "${currentRackList["${index}.${rack}"]}" \
        -l "${rackList["${index}.${rack}"]}")";
    done
  done
  if [[ ${#newDataCenterList[*]} -gt 0 ]];
  then
    nodeList="$(addList2List \
      -l "${nodeList}" \
      -l "${currentRackList[*]}")";
  else
    for index in ${!modifiedRackList[*]};
    do
      for rack in ${modifiedRackList["${index}"]};
      do
        nodeList="$(addList2List \
          -l "${nodeList}" \
          -l "${currentRackList["${index}.${rack}"]}")";
      done
    done
  fi
  for node in ${nodeList};
  do
    err="$(kubectl get "${PODS_CLASS}" -n "${namespace}" \
      -o=custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,IP:.status.podIP \
      2>&1)";
    if [[ ${?} -eq 0 ]];
    then
      echoerr "DEBUG: ${FUNCNAME[0]}: Wait for Cassandra's pods on node \"${node}\"...";
      for pod in $(printf "%s\n" "${err}" | \
        awk -v node="${node}" '{if($2==node) print $1;}');
      do
        ip="$(printf "%s\n" "${err}" | \
          awk -v pod="${pod}" '{if($1==pod) print $3;}')";
        while true;
        do
          if [[ "$(kubectl exec "${pod}" -n "${namespace}" \
            -- nodetool status 2>/dev/null | \
            awk -v ip="${ip}" '{if($2==ip) print $1;}')" == \
            "${CASSANDRA_STATUS_UP}" ]];
          then
            break;
          fi
        done
        echoerr "DEBUG: ${FUNCNAME[0]}: Cassandra pod \"${pod}\" on node \"${node}\" is running";
      done
    else
      echoerr "${errmsg} kubectl:" "${err}";
    fi
  done
  echoerr "DEBUG: ${FUNCNAME[0]}: ...All new/modified/restarted Cassandra nodes are running";

  # After all new nodes are running, run nodetool cleanup on each
  # previously existing nodes to remove keys that no longer belong to those
  # nodes. Wait for cleanup to complete on one node before running nodetool
  # cleanup on the next node.
  if [[ ${#newDataCenterList[*]} -le 0 ]];
  then
    echoerr "DEBUG: ${FUNCNAME[0]}: Cleaning all previously existing nodes...";
    for node in ${currentRackList[*]};
    do
      if [[ -z "$(isInList ${node} ${rackList[*]})" ]];
      then
        err="$(nodetool "${namespace}" "${NODE_OPTION}" "${node}" -- "cleanup")";
        if [[ ! ${?} -eq 0 ]];
        then
          echoerr "${errmsg} nodetool failed on node \"${err}\"";
          return 1;
        fi
      fi
    done
    echoerr "DEBUG: ${FUNCNAME[0]}: ...All previously existing nodes were cleanup";
  fi

  # Run nodetool rebuild on each node in new data centers.
  for cluster in ${!newDataCenterList[*]};
  do
    for dataCenter in ${newDataCenterList["${cluster}"]};
    do
      for currentDataCenter in ${currentClusterList["${cluster}"]};
      do
        err="$(clustertool "${namespace}" \
          "${CLUSTER_OPTION}" "${cluster}" \
          "${DATACENTER_OPTION}" "${dataCenter}" \
          -- "rebuild -- ${currentDataCenter}")";
        if [[ ! ${?} -eq 0 ]];
        then
          echoerr "${errmsg} clustertool failed on nodes \"${err}\"";
          return 1;
        fi
      done
    done
  done

  unset storageTypeList;
  unset dataDirectoryList;
  unset capacityList;
  unset storageCapacityList;
  unset limitCPUList;
  unset limitMemoryList;
  unset requestCPUList;
  unset requestMemoryList;
  unset maxHeapSizeList;
  unset heapNewSizeList;
  unset instancesList;
  unset replicasList;
  unset currentClusterList;
  unset currentDataCenterList;
  unset currentRackList;
  unset clusterList;
  unset dataCenterList;
  unset rackList;
  unset newDataCenterList;
  unset modifiedRackList;
}

function deleteCluster {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local namespace="${1:?"${errmsg} Missing namespace"}";
  checkNamespace "${namespace}";
  if [[ ! ${?} -eq 0 ]];
  then
    return 1;
  fi
  shift 1;
  local filter;
  local clusterList="";
  local dataCenterList="";
  local rackList="";
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
              clusterList="${filter}";
              ;;
            "${DATACENTER_OPTION}")
              dataCenterList="${filter}";
              ;;
            "${RACK_OPTION}")
              rackList="${filter}";
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
  local storageClassName;
  local pv;
  local err;
  local errCode=0;
  declare -A storageClassNameList;
  echoerr "DEBUG: ${FUNCNAME[0]}: Deleting statefulset...";
  deleteStatefulSet \
    "${namespace}" \
    "${CLUSTER_OPTION}" "${clusterList}" \
    "${DATACENTER_OPTION}" "${dataCenterList}" \
    "${RACK_OPTION}" "${rackList}" 1>/dev/null;
  errCode=${?};
  echoerr "DEBUG: ${FUNCNAME[0]}: ...Statefulset deleted";
  # Looking for storage class in use
  for pv in $(getObjectList \
    "${namespace}" \
    "${PERSISTENTVOLUME_CLASS}" \
    "${CLUSTER_OPTION}" "${clusterList}" \
    "${DATACENTER_OPTION}" "${dataCenterList}" \
    "${RACK_OPTION}" "${rackList}");
  do
    err="$(kubectl get \
      "${PERSISTENTVOLUME_CLASS}" "${pv}" \
      -o=custom-columns=STORAGECLASS:.spec.storageClassName 2>&1)";
    if [[ ${?} -eq 0 ]];
    then
      storageClassName="$(printf "%s\n" "${err}" | \
        awk 'NR>1{print $1}')";
      if [[ -n "${storageClassName}" ]];
      then
        storageClassNameList["${storageClassName}"]="${storageClassName}";
      fi
    else
      errCode=1;
      echoerr "${errmsg} kubectl:" "${err}";
    fi
  done
  deletePersistentVolume \
    "${CLUSTER_OPTION}" "${clusterList}" \
    "${DATACENTER_OPTION}" "${dataCenterList}" \
    "${RACK_OPTION}" "${rackList}" 1>/dev/null;
  errCode=${?};
  deleteLabel \
    "${CLUSTER_OPTION}" "${clusterList}" \
    "${DATACENTER_OPTION}" "${dataCenterList}" \
    "${RACK_OPTION}" "${rackList}" 1>/dev/null;
  errCode=${?};
  if [[ -z "$(getObjectList \
    "${namespace}" \
    "${STATEFULSET_CLASS}" \
    "${CLUSTER_OPTION}" "${clusterList}" \
    "${DATACENTER_OPTION}" "${dataCenterList}")" ]];
  then
    deleteDataCenterService  \
      "${namespace}" \
      "${CLUSTER_OPTION}" "${clusterList}" \
      "${DATACENTER_OPTION}" "${dataCenterList}" 1>/dev/null;
    errCode=${?};
  fi
  if [[ -z "$(getObjectList \
    "${namespace}" \
    "${STATEFULSET_CLASS}" \
    "${CLUSTER_OPTION}" "${clusterList}")" ]];
  then
    deleteClientService \
      "${namespace}" \
      "${clusterList}" 1>/dev/null;
    errCode=${?};
  fi
  if [[ -z "$(getClusterList)" ]];
  then
    for storageClassName in ${storageClassNameList[*]};
    do
      deleteStorageClass \
        "$(getStorageType "${storageClassName}")";
      errCode=${?};
    done
    deleteNamespace "${namespace}";
    errCode=${?};
  fi
  unset storageClassNameList;
  return ${errCode};
}
