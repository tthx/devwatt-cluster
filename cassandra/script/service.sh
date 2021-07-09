SERVICE_CLASS="services";
SERVICE_SHORT="svc";
SERVICE_OBJECT="service";

CLIENT_SERVICE_PREFIX="client";

CLIENT_SERVICE_FILENAME_PREFIX="service.client";

DATACENTER_SERVICE_FILENAME_PREFIX="service.client";

#
# Client Service
#
function createClientService {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local namespace="${1:?"${errmsg} Missing namespace"}";
  checkNamespace "${namespace}";
  if [[ ! ${?} -eq 0 ]];
  then
    return 1;
  fi
  shift 1;
  local desireClusterList="${*}";
  local cluster;
  local err;
  local errCode;
  local clusterErrCode;
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
        clientServiceFile="${GENERATED_DIR}/${CLIENT_SERVICE_FILENAME_PREFIX}.${cluster}.yaml";
        err="$(sed -e \
          '/<prefix>/{s/<prefix>/'"${CLIENT_SERVICE_PREFIX,,}"'/g}; /<cluserDNS>/{s/<cluserDNS>/'"${cluster,,}"'/g}; /<cluster>/{s:<cluster>:'"${cluster}"':g}' \
          "${OPERATOR_ROOT}/yaml/service.client.cluster.yaml.template" \
          > "${clientServiceFile}")";
        if [[ ${?} -eq 0 ]];
        then
          err="$(kubectl create -f "${clientServiceFile}" \
            -n "${namespace}" 2>&1)";
          if [[ ${?} -eq 0 ]];
          then
            echoerr "DEBUG: ${FUNCNAME[0]}: kubectl:" "${err}";
          else
            clusterErrCode=1;
            echoerr "${errmsg} kubectl:" "${err}";
          fi
        else
          clusterErrCode=1;
          echoerr "${errmsg} Unable to generate YAML file for client service for cluster \"${cluster}\":" "${err}";
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

function deleteClientService {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local namespace="${1:?"${errmsg} Missing namespace"}";
  checkNamespace "${namespace}";
  if [[ ! ${?} -eq 0 ]];
  then
    return 1;
  fi
  shift 1;
  local clusterList="${*}";
  local err;
  local errCode;
  local service;
  for service in $(getObjectList \
    "${namespace}" \
    "${SERVICE_CLASS}" \
    "${CLUSTER_OPTION}" "${clusterList}");
  do
    if [[ "${service}" =~ ^${CLIENT_SERVICE_PREFIX,,}(.*)$ ]];
    then
      err="$(kubectl \
        delete \
        "${SERVICE_CLASS}" "${service}" \
        -n "${namespace}" 2>&1)";
      errCode=${?};
      if [[ ${errCode} -eq 0 ]];
      then
        echoerr "DEBUG: ${FUNCNAME[0]}: kubectl:" "${err}";
      else
        echoerr "${errmsg} kubectl:" "${err}";
      fi
    fi
  done
  return ${errCode};
}

# Return a list of string, from a submitted list of string,
# which don't have client service
function checkClientService {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local namespace="${1:?"${errmsg} Missing namespace"}";
  checkNamespace "${namespace}";
  if [[ ! ${?} -eq 0 ]];
  then
    return 1;
  fi
  local desireClusterList="";
  local createIfNotExist="";
  local debug="";
  shift 1;
  while [[ ${#} -gt 0 ]]
  do
    case "${1}" in
      "${DEBUG_OPTION}")
        debug="${1}";
        shift 1;
        ;;
      "${CREATEIFNOTEXIST_OPTION}")
        createIfNotExist="${1}";
        shift 1;
        ;;
      "${CLUSTER_OPTION}")
        shift 1;
        while [[ ${#} -gt 0 ]]
        do
          if [[ "${1}" =~ ^-(.*)+$ ]];
          then
            break;
          fi
          desireClusterList="${1} ${desireClusterList} ";
          shift 1;
        done
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
  local err;
  local errCode;
  local clusterErrCode;
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
        err="$(kubectl get "${SERVICE_CLASS}" \
          "${CLIENT_SERVICE_PREFIX,,}-${cluster,,}" \
          -n "${namespace}" 2>&1)";
        if [[ ${?} -eq 0 ]];
        then
          if [[ -n "${debug}" ]];
          then
            echoerr "DEBUG: ${FUNCNAME[0]}: kubectl:" "${err}";
          fi
        else
          if [[ -n "${createIfNotExist}" ]];
          then
            createClientService "${namespace}" "${cluster}" 1>/dev/null;
            clusterErrCode=${?};
          else
            clusterErrCode=1;
            echoerr "${errmsg} kubectl:" "${err}";
          fi
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

#
# DataCenter headless service
#
function createDataCenterService {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local namespace="${1:?"${errmsg} Missing namespace"}";
  checkNamespace "${namespace}";
  if [[ ! ${?} -eq 0 ]];
  then
    return 1;
  fi
  local desireClusterList="";
  local desiredDataCenterList="";
  local filter;
  local option;
  shift 1;
  while [[ ${#} -gt 0 ]]
  do
    case "${1}" in
      "${CLUSTER_OPTION}"|"${DATACENTER_OPTION}")
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
  local dataCenterServiceFile
  local cluster;
  local dataCenter;
  local err;
  local errCode;
  local clusterErrCode;
  local dataCenterErrCode;
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
        for dataCenter in ${desiredDataCenterList:-${clusterList[${cluster}]}};
        do
          dataCenterErrCode=0;
          if [[ -n "${dataCenterList[${cluster}.${dataCenter}]}" ]];
          then
            dataCenterServiceFile="${GENERATED_DIR}/${DATACENTER_SERVICE_FILENAME_PREFIX}.${cluster}.${dataCenter}.yaml";
            err="$(sed -e \
              '/<clusterDNS>/{s/<clusterDNS>/'"${cluster,,}"'/g}; /<dataCenterDNS>/{s/<dataCenterDNS>/'"${dataCenter,,}"'/g}; /<cluster>/{s/<cluster>/'"${cluster}"'/g}; /<dataCenter>/{s/<dataCenter>/'"${dataCenter}"'/g}' \
              "${OPERATOR_ROOT}/yaml/service.cluster.dataCenter.yaml.template" \
              > "${dataCenterServiceFile}")";
            if [[ ${?} -eq 0 ]];
            then
              err="$(kubectl create \
                -f "${dataCenterServiceFile}" \
                -n "${namespace}" 2>&1)";
              if [[ ${?} -eq 0 ]];
              then
                echoerr "DEBUG: ${FUNCNAME[0]}: kubectl:" "${err}";
              else
                dataCenterErrCode=1;
                echoerr "${errmsg} kubectl:" "${err}";
              fi
            else
              dataCenterErrCode=1;
              echoerr "${errmsg} Unable to generate YAML file for headless service for data center \"${cluster}.${dataCenter}\":" "${err}";
            fi
          else
            dataCenterErrCode=1;
            echoerr "${errmsg} Data center \"${cluster}.${dataCenter}\" was not found";
          fi
          if [[ ! ${dataCenterErrCode} -eq 0 ]];
          then
            errCode=1;
            printf "%s\n" "${cluster}.${dataCenter}";
          fi
        done
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

function deleteDataCenterService {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local namespace="${1:?"${errmsg} Missing namespace"}";
  checkNamespace "${namespace}";
  if [[ ! ${?} -eq 0 ]];
  then
    return 1;
  fi
  local clusterList="";
  local dataCenterList="";
  local filter;
  local option;
  shift 1;
  while [[ ${#} -gt 0 ]]
  do
    case "${1}" in
      "${CLUSTER_OPTION}"|"${DATACENTER_OPTION}")
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
  local err;
  local errCode;
  local service;
  for service in $(getObjectList \
    "${namespace}" \
    "${SERVICE_CLASS}" \
    "${CLUSTER_OPTION}" "${clusterList}" \
    "${DATACENTER_OPTION}" "${dataCenterList}");
  do
    if [[ ! "${service}" =~ ^${CLIENT_SERVICE_PREFIX,,}(.*)$ ]];
    then
      err="$(kubectl \
        delete \
        "${SERVICE_CLASS}" "${service}" \
        -n "${namespace}" 2>&1)";
      errCode=${?};
      if [[ ${errCode} -eq 0 ]];
      then
        echoerr "DEBUG: ${FUNCNAME[0]}: kubectl:" "${err}";
      else
        echoerr "${errmsg} kubectl:" "${err}";
      fi
    fi
  done
  return ${errCode};
}

# Return a list of string, in a submitted list of string,
# which don't have headless service
function checkDataCenterService {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local namespace="${1:?"${errmsg} Missing namespace"}";
  checkNamespace "${namespace}";
  if [[ ! ${?} -eq 0 ]];
  then
    return 1;
  fi
  local desireClusterList="";
  local desiredDataCenterList="";
  local createIfNotExist="";
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
      "${CREATEIFNOTEXIST_OPTION}")
        createIfNotExist="${1}";
        shift 1;
        ;;
      "${CLUSTER_OPTION}"|"${DATACENTER_OPTION}")
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
  local err;
  local errCode;
  local clusterErrCode;
  local dataCenterErrCode;
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
        for dataCenter in ${desiredDataCenterList:-${clusterList[${cluster}]}};
        do
          if [[ -n "${dataCenterList[${cluster}.${dataCenter}]}" ]];
          then
            err="$(kubectl get "${SERVICE_CLASS}" \
              "${cluster,,}-${dataCenter,,}" \
              -n "${namespace}" 2>&1)";
            if [[ ${?} -eq 0 ]];
            then
              if [[ -n "${debug}" ]];
              then
                echoerr "DEBUG: ${FUNCNAME[0]}: kubectl:" "${err}";
              fi
            else
              if [[ -n "${createIfNotExist}" ]];
              then
                createDataCenterService "${namespace}" \
                  "${CLUSTER_OPTION}" "${cluster}" \
                  "${DATACENTER_OPTION}" "${dataCenter}" 1>/dev/null;
                dataCenterErrCode=${?};
              else
                dataCenterErrCode=1;
                echoerr "${errmsg} kubectl:" "${err}";
              fi
            fi
          else
            dataCenterErrCode=1;
            echoerr "${errmsg} Data center \"${cluster}.${dataCenter}\" was not found";
          fi
          if [[ ! ${dataCenterErrCode} -eq 0 ]];
          then
            errCode=1;
            printf "%s\n" "${cluster}.${dataCenter}";
          fi
        done
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
