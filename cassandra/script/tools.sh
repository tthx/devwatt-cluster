function echoerr { printf "%s\n" "${@}" >&2; }

function countWord { printf "%s\n" "${#}"; }

# Print the submitted string if it is in a list of string, null if not
function isInList {
  local item="${1}";
  shift 1;
  local list="${*}";
  local i;
  for i in ${list};
  do
    if [[ "${i}" == "${item}" ]];
    then
      printf "%s\n" "${item}";
      return ${?};
    fi
  done
}

# Add a submitted string in a submitted list of string if the submitted string
# don't exist in the list. Print the result list of string.
function addList {
  local item="${1}";
  shift 1;
  local list="${*}";
  local result="${list}";
  if [[ -z "$(isInList "${item}" "${result}")" ]];
  then
    result="${item} ${result}";
  fi
  printf "%s\n" "${result%%+([[:space:]])}";
}

function addList2List {
  local errmsg="ERROR: ${FUNCNAME[0]}:";
  local result="";
  while [[ ${#} -gt 0 ]]
  do
    case "${1}" in
      -l)
        shift 1;
        while [[ ${#} -gt 0 ]]
        do
          if [[ "${1}" =~ ^-(.*)+$ ]];
          then
            break;
          fi
          result="$(addList ${1} ${result})";
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
  printf "%s\n" "${result}";
}

# Remove a submitted string in a submitted list of string if the submitted string
# exist in the list. Print the result list of string.
function removeList {
  local item="${1}";
  shift 1;
  local list="${*}";
  local result="";
  local i;
  for i in ${list};
  do
    if [[ "${i}" != "${item}" ]];
    then
      result="${i} ${result}";
    fi
  done
  printf "%s\n" "${result%%+([[:space:]])}";
}
