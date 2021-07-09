NAMESPACE_CLASS="namespace";
NAMESPACE_SHORT="ns";
NAMESPACE_OBJECT="${NAMESPACE_CLASS}";

function createNamespace {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local namespace="${1:?"${errmsg} Missing namespace"}";
  local err;
  local errCode;
  err="$(kubectl create "${NAMESPACE_CLASS}" "${namespace}" 2>&1)";
  errCode=${?};
  if [[ ${errCode} -eq 0 ]];
  then
    echoerr "DEBUG: ${FUNCNAME[0]}: kubectl:" "${err}";
  else
    echoerr "${errmsg} kubectl:" "${err}";
  fi
  return ${errCode};
}

function deleteNamespace {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local namespace="${1:?"${errmsg} Missing namespace"}";
  local err;
  local errCode;
  err="$(kubectl delete "${NAMESPACE_CLASS}" "${namespace}" 2>&1)";
  errCode=${?};
  if [[ ${errCode} -eq 0 ]];
  then
    echoerr "DEBUG: ${FUNCNAME[0]}: kubectl:" "${err}";
  else
    echoerr "${errmsg} kubectl:" "${err}";
  fi
  return ${errCode};
}

function checkNamespace {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local namespace="${1:?"${errmsg} Missing namespace"}";
  local createIfNotExist="";
  local debug="";
  local err;
  local errCode;
  shift 1;
  while [[ ${#} -gt 0 ]]
  do
    case "${1}" in
      "${CREATEIFNOTEXIST_OPTION}")
        createIfNotExist="${1}";
        shift 1;
        ;;
      "${DEBUG_OPTION}")
        debug="${1}";
        shift 1;
        ;;
      *)
        return 1;
        ;;
    esac
  done
  err="$(kubectl get "${NAMESPACE_CLASS}" "${namespace}" 2>&1)";
  errCode=${?};
  if [[ ${errCode} -eq 0 ]];
  then
    if [[ -n "${debug}" ]];
    then
      echoerr "DEBUG: ${FUNCNAME[0]}: kubectl:" "${err}";
    fi
  else
    if [[ -n "${createIfNotExist}" ]];
    then
      createNamespace "${namespace}" 1>/dev/null;
      errCode=${?};
    else
      echoerr "${errmsg} kubectl:" "${err}";
    fi
  fi
  return ${errCode};
}
