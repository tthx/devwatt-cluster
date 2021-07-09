PERSISTENTVOLUME_CLASS="persistentvolumes";
PERSISTENTVOLUME_SHORT="pv";
PERSISTENTVOLUME_OBJECT="persistentvolume";

PERSISTENTVOLUMECLAIM_CLASS="persistentvolumeclaims";
PERSISTENTVOLUMECLAIM_SHORT="pvc";
PERSISTENTVOLUMECLAIM_OBJECT="persistentvolumeclaim";

PERSISTENTVOLUME_FILENAME_PREFIX="persistentVolume";

function boundInstancePersistentVolume {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local cluster="${1:?"${errmsg} Missing cluster"}";
  local dataCenter="${2:?"${errmsg} Missing data center"}";
  local rack="${3:?"${errmsg} Missing rack"}";
  local node="${4:?"${errmsg} Missing Kubernetes node"}";
  local i="${5:?"${errmsg} Missing instance"}";
  local capacity="${6:?"${errmsg} Missing capacity"}";
  local storageType="${7:?"${errmsg} Missing storage type"}";
  local dataDirectory="${8:?"${errmsg} Missing data directory"}";
  local storageClassName;
  local persistentVolumeFile;
  local err;
  local errCode;
  storageType="$(checkStorageType "${storageType}")";
  if [[ ! ${?} -eq 0 ]];
  then
    return 1;
  fi
  storageClassName="$(getStorageClassName "${storageType}")";
  persistentVolumeFile="${GENERATED_DIR}/${PERSISTENTVOLUME_FILENAME_PREFIX}.${node}.${i}.yaml";
  err="$(sed -e \
    '/<clusterDNS>/{s/<clusterDNS>/'"${cluster,,}"'/g}; /<dataCenterDNS>/{s/<dataCenterDNS>/'"${dataCenter,,}"'/g}; /<rackDNS>/{s/<rackDNS>/'"${rack,,}"'/g}; /<hostname>/{s/<hostname>/'"${node}"'/g}; /<instance>/{s/<instance>/'"${i}"'/g}; /<cluster>/{s/<cluster>/'"${cluster}"'/g}; /<dataCenter>/{s/<dataCenter>/'"${dataCenter}"'/g}; /<rack>/{s/<rack>/'"${rack}"'/g}; /<capacity>/{s/<capacity>/'"${capacity}"'/g}; /<storageClassName>/{s/<storageClassName>/'"${storageClassName}"'/g}; /<dataDirectory>/{s:<dataDirectory>:'"${dataDirectory}"':g}' \
    "${OPERATOR_ROOT}/yaml/${storageType}PersistentVolume-${K8S_VERSION}.cluster.dataCenter.rack.yaml.template" \
    > "${persistentVolumeFile}")";
  errCode=${?};
  if [[ ${errCode} -eq 0 ]];
  then
    err="$(kubectl create -f "${persistentVolumeFile}" 2>&1)";
    errCode=${?};
    if [[ ${errCode} -eq 0 ]];
    then
      echoerr "DEBUG: ${FUNCNAME[0]}: kubectl:" "${err}";
    else
      echoerr "${errmsg} kubectl:" "${err}";
    fi
  else
    echoerr "${errmsg} Unable to generate YAML file for persistent volume for instance \"${i}\" on node \"${node}\":" "${err}";
  fi
  return ${errCode};
}

# Print a list of string, from a submitted list of string,
# where persistent volume deletion failed
function releaseNodePersistentVolume {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local nodeList="${*:?"${errmsg} Missing list of Kubernetes node"}";
  local node;
  local pv;
  local pvc;
  local err;
  local errCode=0;
  local nodeErrCode;
  for node in ${nodeList};
  do
    nodeErrCode=0;
    for pv in $(getObjectList "x" \
      "${PERSISTENTVOLUME_CLASS}" \
      "${NODE_OPTION}" \
      "${node}");
    do
      err="$(kubectl get "${PERSISTENTVOLUME_CLASS}" "${pv}" \
        -o=custom-columns=NAMESPACE:.spec.claimRef.namespace,CLAIM:.spec.claimRef.name \
        2>&1)";
      nodeErrCode=${?};
      if [[ ${nodeErrCode} -eq 0 ]];
      then
        pvc="$(printf "%s\n" "${err}" | \
          awk 'NR>1{if(!match($2, none)) printf("%s/%s\n", $1, $2);}')";
        if [[ -n "${pvc}" ]];
        then
          err="$(kubectl delete "${PERSISTENTVOLUMECLAIM_CLASS}" \
            "${pvc#*\/}" -n "${pvc%\/*}" 2>&1)";
          nodeErrCode=${?};
          if [[ ${nodeErrCode} -eq 0 ]];
          then
            echoerr "DEBUG: ${FUNCNAME[0]}: kubectl:" "${err}";
          else
            echoerr "${errmsg} kubectl:" "${err}";
          fi
        fi
      else
        echoerr "${errmsg} kubectl:" "${err}";
      fi
      err="$(kubectl delete "${PERSISTENTVOLUME_CLASS}" "${pv}" 2>&1)";
      nodeErrCode=${?};
      if [[ ${nodeErrCode} -eq 0 ]];
      then
        echoerr "DEBUG: ${FUNCNAME[0]}: kubectl:" "${err}";
      else
        echoerr "${errmsg} kubectl:" "${err}";
      fi
    done
    if [[ ! ${nodeErrCode} -eq 0 ]];
    then
      errCode=1;
      printf "%s\n" "${node}";
    fi
  done
  return ${errCode};
}

function releasePersistentVolume {
  local nodeList;
  local errCode;
  nodeList="$(getObjectList \
    "x" \
    "${NODE_CLASS}" \
    "${@}")";
  errCode=${?};
  if [[ ${errCode} -eq 0 ]] && [[ -n "${nodeList}" ]];
  then
    releaseNodePersistentVolume "${nodeList}";
    errCode=${?};
  else
    echoerr "DEBUG: ${FUNCNAME[0]}: No node to release persistent volume";
  fi
  return ${errCode};
}

# Print a string if the submitted node have persistent volumes
# equal properties than the submitted properties, null if not
function compareNodePersistentVolume {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local cluster="${1:?"${errmsg} Missing cluster"}";
  local dataCenter="${2:?"${errmsg} Missing dataCenter"}";
  local rack="${3:?"${errmsg} Missing rack"}";
  local node="${4:?"${errmsg} Missing node"}";
  local storageType="${5:?"${errmsg} Missing storage type"}";
  local baseDataDirectory="${6:?"${errmsg} Missing data directory"}";
  local capacity="${7:?"${errmsg} Missing capacity"}";
  local instances="${8:?"${errmsg} Missing instances"}";
  local err;
  local storageClassName;
  storageClassName="$(getStorageClassName "${storageType}")";
  if [[ ! ${?} -eq 0 ]];
  then
    return 1;
  fi
  local pv;
  local i;
  local errCode=0;
  if [[ -n "$(compareNodeLabel \
    "${node}" \
    "${cluster}" \
    "${dataCenter}" \
    "${rack}" \
    "${instances}")" ]];
  then
    for pv in $(getObjectList \
      "x" \
      "${PERSISTENTVOLUME_CLASS}" \
      "${NODE_OPTION}" "${node}");
    do
      i="${pv##*-}";
      err="$(kubectl get "${PERSISTENTVOLUME_CLASS}" \
        "${pv}" \
        -o=custom-columns=STORAGECLASSNAME:.spec.storageClassName,CAPACITY:.spec.capacity.storage,DIRECTORY:.spec.*.path \
        2>&1)";
      if [[ ${?} -eq 0 ]];
      then
        if [[ -n "$(printf "%s\n" "${err}" | \
          awk -v storageClassName="${storageClassName}" \
            -v capacity="${capacity}" \
            -v dataDirectory="${baseDataDirectory}/${i}" \
            'NR>1{ if((storageClassName == $1) && \
              (capacity == $2) && \
              (dataDirectory == $3))
                print "1"; \
            }')" ]];
        then
          errCode=$((${errCode}+1));
        fi
      else
        echoerr "${errmsg} kubectl:" "${err}";
      fi
    done
  fi
  if [[ ${errCode} -eq ${instances} ]];
  then
    errCode=0;
    printf "1\n";
  else
    errCode=1;
  fi
  return ${errCode};
}

# Return a list of string, from a submitted list of string,
# where persistent volume creation failed
function createNodePersistentVolume {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local storageType="${1:?"${errmsg} Missing storage type"}";
  local baseDataDirectory="${2:?"${errmsg} Missing data directory"}";
  local capacity="${3:?"${errmsg} Missing capacity"}";
  local overwrite="";
  if [[ "${4}" == "${OVERWRITE_OPTION}" ]];
  then
    overwrite="${4}";
    shift 4;
  else
    shift 3;
  fi
  local nodeList="${*:?"${errmsg} Missing list of Kubernetes node"}";
  local dataDirectory;
  local cluster;
  local dataCenter;
  local rack;
  local node;
  local persistentVolumeFile;
  local err;
  local errCode=0;
  local nodeErrCode;
  local instances;
  local i;
  if [[ ! ${?} -eq 0 ]];
  then
    return 1;
  fi
  #
  # Depedencies with kubeadm-dind-cluster start
  #
  local dockerIDList;
  err="$(docker ps)";
  if [[ ${?} -eq 0 ]];
  then
    dockerIDList="${err}";
  else
    echoerr "${errmsg} docker:" "${err}";
    return 1;
  fi
  local dockerID;
  #
  # Depedencies with kubeadm-dind-cluster end
  #
  for node in ${nodeList};
  do
    cluster="$(getLabel "${NODE_CLASS}" "${node}" "${CLUSTER_LABEL}")";
    dataCenter="$(getLabel "${NODE_CLASS}" "${node}" "${DATACENTER_LABEL}")";
    rack="$(getLabel "${NODE_CLASS}" "${node}" "${RACK_LABEL}")";
    instances="$(getLabel "${NODE_CLASS}" "${node}" "${INSTANCES_LABEL}")";
    nodeErrCode=0;
    if [[ -n "${cluster}" ]] && \
      [[ -n "${dataCenter}" ]] && \
      [[ -n "${rack}" ]] && \
      [[ -n "${instances}" ]];
    then
      if [[ -z "$(compareNodePersistentVolume \
        "${cluster}" \
        "${dataCenter}" \
        "${rack}" \
        "${node}" \
        "${storageType}" \
        "${baseDataDirectory}" \
        "${capacity}" \
        "${instances}")" ]];
      then
        if [[ -n "$(getObjectList \
            "x" \
            "${PERSISTENTVOLUME_CLASS}" \
            "${NODE_OPTION}" "${node}")" ]];
        then
          if [[ -n "${overwrite}" ]];
          then
            deleteNodePersistentVolume "${node}" 1>/dev/null;
            nodeErrCode=${?};
          else
            nodeErrCode=1;
            echoerr "${errmsg} Persistent volumes already exist on node \"${node}\"";
            echoerr "${errmsg} You can use the overwrite flag \"${OVERWRITE_OPTION}\" to create persistent volumes on node \"${node}\". This will delete existing persistent volumes on node \"${node}\" and their associated storage. So remember to make necessary backup.";
          fi
        fi
        if [[ ${nodeErrCode} -eq 0 ]];
        then
          #
          # Depedencies with kubeadm-dind-cluster start
          #
          dockerID="$(printf "%s\n" "${dockerIDList}" | \
            awk -v node="${node}" '{if($NF == node) print $1;}')";
          if [[ -n "${dockerID}" ]];
          then
            if [[ -n "${overwrite}" ]];
            then
              err="$(docker exec -it "${dockerID}" \
                rm -rf "${baseDataDirectory}" 2>&1)";
            fi
          #
          # Depedencies with kubeadm-dind-cluster end
          #
            for ((i=0; i<instances; i++));
            do
              dataDirectory="${baseDataDirectory}/${i}";
              #
              # Depedencies with kubeadm-dind-cluster start
              #
              err="$(docker exec -it "${dockerID}" \
                ls -d "${dataDirectory}" 2>&1)";
              if [[ ${?} -eq 0 ]];
              then
                echoerr "${errmsg} The directory \"${dataDirectory}\" already exists on the node \"${node}\"";
                nodeErrCode=1;
                break;
              fi
              err="$(docker exec -it "${dockerID}" \
                mkdir -p "${dataDirectory}" 2>&1)";
              nodeErrCode=${?};
              if [[ ! ${nodeErrCode} -eq 0 ]];
              then
                echoerr "${errmsg} Unable to create directory \"${dataDirectory}\" on the node \"${node}\"";
                echoerr "${errmsg} docker:" "${err}";
                break;
              fi
              #
              # Depedencies with kubeadm-dind-cluster end
              #
              boundInstancePersistentVolume \
                "${cluster}" \
                "${dataCenter}" \
                "${rack}" \
                "${node}" \
                "${i}" \
                "${capacity}" \
                "${storageType}" \
                "${dataDirectory}";
              nodeErrCode=${?};
              if [[ ! ${nodeErrCode} -eq 0 ]];
              then
                break;
              fi
            done
          #
          # Depedencies with kubeadm-dind-cluster start
          #
          else
            nodeErrCode=1;
            echoerr "${errmsg} No docker is associated with the node \"${node}\"";
          fi
          #
          # Depedencies with kubeadm-dind-cluster end
          #
        fi
      else
        echoerr "DEBUG: ${FUNCNAME[0]}: Persistent volume on node \"${node}\" already exist with equal properties";
      fi
    else
      nodeErrCode=1;
      echoerr "${errmsg} Node \"${node}\" is not a Cassandra node";
    fi
    if [[ ! ${nodeErrCode} -eq 0 ]];
    then
      printf "%s\n" "${node}";
      errCode=1;
    fi
  done
  return ${errCode};
}

function createPersistentVolume {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local storageType="${1:?"${errmsg} Missing storage type"}"
  local baseDataDirectory="${2:?"${errmsg} Missing data directory"}";
  local capacity="${3:?"${errmsg} Missing capacity"}";
  local overwrite="";
  if [[ "${4}" == "${OVERWRITE_OPTION}" ]];
  then
    overwrite="${4}";
    shift 4;
  else
    shift 3;
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
    createNodePersistentVolume \
      "${storageType}" \
      "${baseDataDirectory}" \
      "${capacity}" \
      "${overwrite}" \
      "${nodeList}";
    errCode=${?};
  else
    echoerr "DEBUG: ${FUNCNAME[0]}: No node to create persistent volume";
  fi
  return ${errCode};
}

# Return a list of string, from a submitted list of string,
# where persistent volume deletion failed
function deleteNodePersistentVolume {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local nodeList="${*:?"${errmsg} Missing list of Kubernetes node"}";
  local node;
  local pv;
  local baseDataDirectory;
  local err;
  local errCode;
  local nodeErrCode;
  #
  # Depedencies with kubeadm-dind-cluster start
  #
  local dockerIDList;
  err="$(docker ps 2>&1)";
  if [[ ${?} -eq 0 ]];
  then
    dockerIDList="${err}";
  else
    echoerr "${errmsg} docker:" "${err}";
    return 1;
  fi
  local dockerID;
  #
  # Depedencies with kubeadm-dind-cluster end
  #
  for node in ${nodeList};
  do
    nodeErrCode=0;
    pv="$(getObjectList "x" "${PERSISTENTVOLUME_CLASS}" "${NODE_OPTION}" "${node}")";
    pv="${pv%%[[:space:]]*}";
    if [[ -n "${pv}" ]];
    then
      err="$(kubectl get "${PERSISTENTVOLUME_CLASS}" \
        "${pv}" \
        -o=custom-columns="${LOCAL_TYPE}":.spec."${LOCAL_TYPE}".path,"${HOSTPATH_TYPE}":.spec."${HOSTPATH_TYPE}".path \
        2>&1)";
      nodeErrCode=${?};
      if [[ ${nodeErrCode} -eq 0 ]];
      then
        baseDataDirectory="$(printf "%s\n" "${err}" | \
          awk 'NR>1{if($1!="<none>") print $1; if($2!="<none>") print $2;}')";
        releaseNodePersistentVolume "${node}" 1>/dev/null;
        nodeErrCode=${?};
        if [[ ${nodeErrCode} -eq 0 ]];
        then
          baseDataDirectory="${baseDataDirectory%\/*}";
          #
          # Depedencies with kubeadm-dind-cluster start
          #
          dockerID="$(printf "%s\n" "${dockerIDList}" | \
            awk -v node="${node}" '{if($NF == node) print $1;}')";
          if [[ -n "${dockerID}" ]];
          then
            err="$(docker exec -it "${dockerID}" \
              rm -rf "${baseDataDirectory}" 2>&1)";
            nodeErrCode=${?};
            if [[ ! ${nodeErrCode} -eq 0 ]];
            then
              echoerr "${errmsg} Unable to delete directory \"${dataDirectory}\" on the node \"${node}\"";
              echoerr "${errmsg} docker:" "${err}";
            fi
          else
            nodeErrCode=1;
            echoerr "${errmsg} No docker is associated with the node \"${node}\"";
          fi
          #
          # Depedencies with kubeadm-dind-cluster end
          #
        fi
      else
        echoerr "${errmsg} kubectl:" "${err}";
      fi
    else
      nodeErrCode=1;
      echoerr "${errmsg} Node \"${node}\" have no persistent volume";
    fi
    if [[ ! ${nodeErrCode} -eq 0 ]];
    then
      errCode=1;
      printf "%s\n" "${node}";
    fi
  done
  return ${errCode};
}

function deletePersistentVolume {
  local nodeList;
  nodeList="$(getObjectList \
    "x" \
    "${NODE_CLASS}" \
    "${@}")";
  errCode=${?};
  if [[ ${errCode} -eq 0 ]] && [[ -n "${nodeList}" ]];
  then
    deleteNodePersistentVolume ${nodeList};
    errCode=${?};
  else
    echoerr "DEBUG: ${FUNCNAME[0]}: No node to delete persistent volume";
  fi
  return ${errCode};
}

# Return a list of string, from a submitted list of string,
# which are not persistent volumes or don't have the correct number of
# persistent volume which is equal to the number of instance assigned to a
# Kubernetes node
function checkNodePersistentVolume {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local debug="";
  if [[ "${1}" == "${DEBUG_OPTION}" ]];
  then
    debug="${DEBUG_OPTION}";
    shift 1;
  fi
  local nodeList="${*:?"${errmsg} Missing list of Kubernetes node"}";
  local node;
  local instances;
  local errCode=0;
  local nodeErrCode;
  local x;
  for node in ${nodeList};
  do
    nodeErrCode=0;
    if [[ -z "$(isCassandraNode "${node}")" ]];
    then
      instances="$(getLabel "${NODE_CLASS}" "${node}" "${INSTANCES_LABEL}")";
      x=$(countWord $(getObjectList \
        "x" \
        "${PERSISTENTVOLUME_CLASS}" \
        "${NODE_OPTION}" "${node}"));
      if [[ ! ${instances} -eq ${x} ]];
      then
        nodeErrCode=1;
        if [[ -n "${debug}" ]];
        then
          echoerr "${errmsg} The existing persistent volumes (${x}) for node \"${node}\" is not equal to the expected number (${instances})";
        fi
      else
        if [[ -n "${debug}" ]];
        then
          echoerr "DEBUG: ${FUNCNAME[0]}: Node \"${node}\" have the expected number of persistent volumes (${instances})";
        fi
      fi
    else
      nodeErrCode=1;
      if [[ -n "${debug}" ]];
      then
        echoerr "${errmsg} Node \"${node}\" is not a Cassandra node";
      fi
    fi
    if [[ ! ${nodeErrCode} -eq 0 ]];
    then
      errCode=1;
      printf "%s\n" "${node}";
    fi
  done
  return ${errCode};
}

function checkPersistentVolume {
  local nodeList;
  local debug="";
  if [[ "${1}" == "${DEBUG_OPTION}" ]];
  then
    debug="${DEBUG_OPTION}";
    shift 1;
  fi
  nodeList="$(getObjectList \
    "x" \
    "${NODE_CLASS}" \
    "${@}")";
  errCode=${?};
  if [[ ${errCode} -eq 0 ]] && [[ -n "${nodeList}" ]];
  then
    checkNodePersistentVolume "${debug}" "${nodeList}";
    errCode=${?};
  else
    echoerr "DEBUG: ${FUNCNAME[0]}: No node to check persistent volume";
  fi
  return ${errCode};
}

function releasePersistentVolumeClaim {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local namespace="${1:?"${errmsg} Missing namespace"}";
  checkNamespace "${namespace}";
  if [[ ! ${?} -eq 0 ]];
  then
    return 1;
  fi
  shift 1;
  local pvcList="${*:?"${errmsg} Missing list of persistent volume claim"}";
  local pvc
  local pv;
  local cluster;
  local dataCenter;
  local rack;
  local node;
  local storageClassName;
  local capacity;
  local dataDirectory;
  local i;
  local err;
  local errCode=0;
  local pvErrCode;
  for pvc in ${pvcList};
  do
    # Delete persistent volume claim
    err="$(kubectl get "${PERSISTENTVOLUMECLAIM_CLASS}" \
      "${pvc}" -n "${namespace}" \
      -o=custom-columns=PERSISTENTVOLUME:.spec.volumeName 2>&1)";
    pvErrCode=${?};
    if [[ ${pvErrCode} -eq 0 ]];
    then
      pv="$(printf "%s\n" "${err}" | \
        awk 'NR>1{print $1;}')";
      err="$(kubectl delete "${PERSISTENTVOLUMECLAIM_CLASS}" \
        "${pvc}" -n "${namespace}" 2>&1)";
      pvErrCode=${?};
      if [[ ${pvErrCode} -eq 0 ]];
      then
        echoerr "DEBUG: ${FUNCNAME[0]}: kubectl:" "${err}";
      else
        echoerr "${errmsg} kubectl:" "${err}";
      fi
      # Delete persistent volume
      # Gather informations about the persistent volume to delete
      err="$(kubectl get "${PERSISTENTVOLUME_CLASS}" \
        "${pv}" \
        -o=custom-columns=STORAGECLASSNAME:.spec.storageClassName,CAPACITY:.spec.capacity.storage,DIRECTORY:.spec.*.path,LABELS:.metadata.labels \
        2>&1)";
      pvErrCode=${?};
      if [[ ${pvErrCode} -eq 0 ]];
      then
        i="${pv##*-}";
        storageClassName="$(printf "%s\n" "${err}" | awk 'NR>1{print $1}')";
        capacity="$(printf "%s\n" "${err}" | awk 'NR>1{print $2}')";
        dataDirectory="$(printf "%s\n" "${err}" | awk 'NR>1{print $3}')";
        cluster="$(printf "%s\n" "${err}" | \
          awk -v TOFIND="${CLUSTER_LABEL}" \
            'NR>1 { \
              for(i=4; i<=NF; i++) { \
                if(match($i, TOFIND)) { \
                  split($i, value, ":"); \
                  sub("]", "", value[2]); \
                  print value[2]; \
                } \
              } \
            }')";
        dataCenter="$(printf "%s\n" "${err}" | \
          awk -v TOFIND="${DATACENTER_LABEL}" \
            'NR>1 { \
              for(i=4; i<=NF; i++) { \
                if(match($i, TOFIND)) { \
                  split($i, value, ":"); \
                  sub("]", "", value[2]); \
                  print value[2]; \
                } \
              } \
            }')";
        rack="$(printf "%s\n" "${err}" | \
          awk -v TOFIND="${RACK_LABEL}" \
            'NR>1 { \
              for(i=4; i<=NF; i++) { \
                if(match($i, TOFIND)) { \
                  split($i, value, ":"); \
                  sub("]", "", value[2]); \
                  print value[2]; \
                } \
              } \
            }')";
        node="$(printf "%s\n" "${err}" | \
          awk -v TOFIND="${NODE_LABEL}" \
            'NR>1 { \
              for(i=4; i<=NF; i++) { \
                if(match($i, TOFIND)) { \
                  split($i, value, ":"); \
                  sub("]", "", value[2]); \
                  print value[2]; \
                } \
              } \
            }')";
        err="$(kubectl delete "${PERSISTENTVOLUME_CLASS}" \
          "${pv}" 2>&1)";
        pvErrCode=${?};
        if [[ ${pvErrCode} -eq 0 ]];
        then
          echoerr "DEBUG: ${FUNCNAME[0]}: kubectl:" "${err}";
          # Create again the deleted persistent volume
          boundInstancePersistentVolume \
            "${cluster}" \
            "${dataCenter}" \
            "${rack}" \
            "${node}" \
            "${i}" \
            "${capacity}" \
            "$(getStorageType "${storageClassName}")" \
            "${dataDirectory}";
          pvErrCode=${?};
        else
          echoerr "${errmsg} kubectl:" "${err}";
        fi
      else
        echoerr "${errmsg} kubectl:" "${err}";
      fi
    else
      echoerr "${errmsg} kubectl:" "${err}";
    fi
    if [[ ! ${pvErrCode} -eq 0 ]];
    then
      errCode=1;
    fi
  done
  return ${errCode};
}
