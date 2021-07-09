STORAGECLASS_CLASS="storageclasses";
STORAGECLASS_SHORT="sc";
STORAGECLASS_OBJECT="storageclass";

LOCAL_TYPE="local";
LOCAL_TYPE_SHORT="l";
HOSTPATH_TYPE="hostPath";
HOSTPATH_TYPE_SHORT="hp";

declare -A STORAGETYPE_LIST;
STORAGETYPE_LIST["${LOCAL_TYPE}"]="${LOCAL_TYPE}";
STORAGETYPE_LIST["${LOCAL_TYPE_SHORT}"]="${LOCAL_TYPE}";
STORAGETYPE_LIST["${HOSTPATH_TYPE}"]="${HOSTPATH_TYPE}";
STORAGETYPE_LIST["${HOSTPATH_TYPE_SHORT}"]="${HOSTPATH_TYPE}";

STORAGECLASS_SUFFIX_FILENAME="StorageClass.yaml";

# Note: StorageClass resources aren’t in a namespace:
# 'Not All Objects are in a Namespace' (https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/#not-all-objects-are-in-a-namespace)

function checkStorageType {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local storageType="${1:?"${errmsg} Missing storage type"}";
  local debug="${2}";
  local result="${STORAGETYPE_LIST[${storageType}]}";
  printf "%s\n" "${result}";
  if [[ "${debug}" == "${DEBUG_OPTION}" ]];
  then
    if [[ -z "${result}" ]];
    then
      echoerr "${errmsg} Unknown storage type";
      echoerr "${errmsg} Supported storage types are:" "${STORAGETYPE_LIST[*]}";
    fi
  fi
  return 0;
}

function getStorageType {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local storageClassName="${1:?"${errmsg} Missing storage class name"}";
  local storageType;
  local result="";
  for storageType in ${STORAGETYPE_LIST[*]};
  do
    if [[ "${storageClassName}" == "$(getStorageClassName "${storageType}")" ]];
    then
      result="${storageType}";
      break;
    fi
  done
  printf "%s\n" "${result}";
}

function getStorageClassName {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local storageType="${1:?"${errmsg} Missing storage type"}";
  local storageClassFile;
  local storageClassName;
  storageType="$(checkStorageType "${storageType}")";
  if [[ -z "${storageType}" ]];
  then
    return 1;
  fi
  storageClassFile="${OPERATOR_ROOT}/yaml/${storageType}${STORAGECLASS_SUFFIX_FILENAME}";
  if [[ ! -f "${storageClassFile}" ]];
  then
    echoerr "${errmsg} File \"${storageClassFile}\" was not found";
    return 1;
  fi
  storageClassName="$(awk '$1~/name:/{print $2;}' "${storageClassFile}")";
  if [[ -z "${storageClassName}" ]];
  then
    echoerr "${errmsg} No storage class name in file \"${storageClassFile}\"";
    return 1;
  fi
  printf "%s\n" "${storageClassName}";
  return 0;
}

function createStorageClass {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local storageType="${1:?"${errmsg} Missing storage type"}";
  local storageClassFile;
  local storageClassName;
  local err;
  local errCode;
  storageType="$(checkStorageType "${storageType}")";
  if [[ -z "${storageType}" ]];
  then
    return 1;
  fi
  storageClassFile="${OPERATOR_ROOT}/yaml/${storageType}${STORAGECLASS_SUFFIX_FILENAME}";
  err="$(kubectl create -f "${storageClassFile}" 2>&1)";
  errCode=${?};
  if [[ ${errCode} -eq 0 ]];
  then
    echoerr "DEBUG: ${FUNCNAME[0]}: kubectl:" "${err}";
  else
    echoerr "${errmsg} kubectl:" "${err}";
  fi
  return ${errCode};
}

function deleteStorageClass {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local storageType="${1:?"${errmsg} Missing storage type"}";
  local storageClassName;
  local err;
  local errCode;
  storageClassName="$(getStorageClassName "${storageType}")";
  errCode=${?};
  if [[ ${errCode} -eq 0 ]];
  then
    err="$(kubectl delete "${STORAGECLASS_CLASS}" "${storageClassName}" 2>&1)";
    errCode=${?};
    if [[ ${errCode} -eq 0 ]];
    then
      echoerr "DEBUG: ${FUNCNAME[0]}: kubectl:" "${err}";
    else
      echoerr "${errmsg} kubectl:" "${err}";
    fi
  fi
  return ${errCode};
}

function checkStorageClass {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local storageType="${1:?"${errmsg} Missing storage type"}";
  shift 1;
  local createIfNotExist="";
  local debug="";
  while [[ ${#} -gt 0 ]]
  do
    case "${1}" in
      "${CREATEIFNOTEXIST_OPTION}")
        createIfNotExist="${CREATEIFNOTEXIST_OPTION}";
        ;;
      "${DEBUG_OPTION}")
        debug="${DEBUG_OPTION}";
        ;;
      *)
        if [[ -n "${1}" ]];
        then
          echoerr "${errmsg} Option \"${1}\" is unknown";
          return 1;
        fi
        ;;
    esac
    shift 1;
  done
  local storageClassName;
  local err;
  local errCode;
  storageClassName="$(getStorageClassName "${storageType}")";
  errCode=${?};
  if [[ ${errCode} -eq 0 ]];
  then
    err="$(kubectl get "${STORAGECLASS_CLASS}" "${storageClassName}" 2>&1)";
    errCode=${?};
    if [[ ! ${errCode} -eq 0 ]];
    then
      if [[ -n "${createIfNotExist}" ]];
      then
        createStorageClass "${storageType}";
        errCode=${?};
      else
        echoerr "${errmsg} kubectl:" "${err}";
      fi
    else
      if [[ -n "${debug}" ]];
      then
        echoerr "DEBUG: ${FUNCNAME[0]}: kubectl:" "${err}";
      fi
    fi
  fi
  return ${errCode};
}
