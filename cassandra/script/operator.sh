#!/bin/bash

if [[ "$(uname)" == Darwin ]];
then
  readlinkf(){ perl -MCwd -e 'print Cwd::abs_path shift' "${1}";}
else
  readlinkf(){ readlink -f "${1}"; }
fi
OPERATOR_ROOT="$(cd "$(dirname "$(readlinkf "${BASH_SOURCE}")")/.."; pwd)";

GENERATED_DIR="${OPERATOR_ROOT}/generated";
if [[ ! -d "${GENERATED_DIR}" ]];
then
  mkdir -p "${GENERATED_DIR}";
  if [[ ! ${?} -eq 0 ]];
  then
    printf "%s\n" \
      "ERROR: ${0}: Unable to create directory \"${GENERATED_DIR}\"" \
      >&2;
    exit 1;
  fi
fi

K8S_VERSION="";

CLUSTER_OPTION="-cl";
DATACENTER_OPTION="-dc";
RACK_OPTION="-rk";
NODE_OPTION="-kn";
INSTANCE_OPTION="-i";
STORAGETYPE_OPTION="-st";
STORAGECAPACITY_OPTION="-sc";
CPULIMIT_OPTION="-lcpu";
MEMORYLIMIT_OPTION="-lmem";
CPUREQUEST_OPTION="-rcpu";
MEMORYREQUEST_OPTION="-rmem";
MAXHEAPSIZE_OPTION="-mhs";
NEWHEAPSIZE_OPTION="-nhs";
REPLICAS_OPTION="-r";
DEBUG_OPTION="-debug";
CREATEIFNOTEXIST_OPTION="-cine";
OVERWRITE_OPTION="-ow";
FORCE_OPTION="--force";
RESTART_OPTION="-restart";
SCALE_OPTION="-scale";

. "${OPERATOR_ROOT}/script/tools.sh";
. "${OPERATOR_ROOT}/script/namespace.sh";
. "${OPERATOR_ROOT}/script/label.sh";
. "${OPERATOR_ROOT}/script/storageClass.sh";
. "${OPERATOR_ROOT}/script/persistentVolume.sh";
. "${OPERATOR_ROOT}/script/service.sh";
. "${OPERATOR_ROOT}/script/statefulSet.sh";
. "${OPERATOR_ROOT}/script/node.sh";
. "${OPERATOR_ROOT}/script/cluster.sh";

function getK8sVersion {
  kubectl version | \
    awk -v Major="Major" \
      -v Minor="Minor" '$1~/Server/ {
        for(i=1; i<=NF; i++) { \
          if(match($i, Major) || match($i, Minor)) { \
            split($i, value, ":"); \
            gsub(/"|,/, "", value[2]); \
          } \
          if(match($i, Major)) x=value[2]; \
          if(match($i, Minor)) y=value[2]; \
        }
      } END { \
        if(x>=1) { \
          if((y-9)<=0) y=9; \
          else y=10; \
          printf("%d.%d", x, y); \
        } \
      }';
}

function checkRequirements {
  if [[ ${BASH_VERSINFO[0]} -lt 3 ]];
  then
    echoerr "ERROR: ${0}: Sorry, we need at least BASH's version 4.0 to run this script.";
    return 1;
  fi
  if [[ -z "$(which docker)" ]];
  then
    echoerr "ERROR: ${0}: \"docker\" command was not found in PATH";
    return 1;
  fi
  if [[ -z "$(which kubectl)" ]];
  then
    echoerr "ERROR: ${0}: \"kubectl\" command was not found in PATH";
    return 1;
  fi
  K8S_VERSION="$(getK8sVersion)";
  if [[ -z "${K8S_VERSION}" ]];
  then
    echoerr "ERROR: ${0}: Unsupported Kubernetes version";
    return 1;
  fi
  if [[ -z "$(which awk)" ]];
  then
    echoerr "ERROR: ${0}: \"awk\" command was not found in PATH";
    return 1;
  fi
  if [[ -z "$(which sed)" ]];
  then
    echoerr "ERROR: ${0}: \"sed\" command was not found in PATH";
    return 1;
  fi
  return 0;
}

function main {
  local errmsg;
  local errCode=0;
  local options;
  local x;
  case "${1}" in
    topology|topo)
      shift 1;
      declare -A clusterList;
      declare -A dataCenterList;
      declare -A rackList;
      getTopology clusterList dataCenterList rackList;
      printf "%s\n" "CLUSTER:";
      for x in ${!clusterList[*]};
      do
        printf "%s: %s\n" "${x}" "${clusterList[${x}]}";
      done
      printf "%s\n" "DATA CENTER:";
      for x in ${!dataCenterList[*]};
      do
        printf "%s: %s\n" "${x}" "${dataCenterList[${x}]}";
      done
      printf "%s\n" "RACK:";
      for x in ${!rackList[*]};
      do
        printf "%s: %s\n" "${x}" "${rackList[${x}]}";
      done
      unset clusterList;
      unset dataCenterList;
      unset rackList;
      errCode=${?};
      ;;
    restart)
      shift 1;
      restartStatefulSet "${@}";
      errCode=${?};
      ;;
    scale)
      shift 1;
      scaleStatefulSet "${@}";
      errCode=${?};
      ;;
    sum)
      case "${2}" in
        nodelist|nl)
          shift 2;
          sumNodeInstances "${@}";
          errCode=${?};
          ;;
        clusterlist|cl)
          shift 2;
          sumInstances "${@}";
          errCode=${?};
          ;;
        *)
          errCode=1;
          options=( \
            "clusterlist|cl [${CLUSTER_OPTION} <list of cluster>] [${DATACENTER_OPTION} <list of data center>] [${RACK_OPTION} <list of rack>]" \
            "nodelist|nl <list of Kubernetes node>");
          printf -v errmsg "    %s\n" "${options[@]}";
          printf -v errmsg "%s\n%s\n  %s\n%s" \
            "ERROR: Usage:" \
            "${0}" \
            "sum" \
            "${errmsg}";
          echoerr "${errmsg}";
          ;;
      esac
      ;;
    nodetool|nt)
      case "${2}" in
        nodelist|nl)
          shift 2;
          nodetool "${@}";
          errCode=${?};
          ;;
        clusterlist|cl)
          shift 2;
          clustertool "${@}";
          errCode=${?};
          ;;
        *)
          errCode=1;
          options=( \
            "clusterlist|cl <namespace> [${CLUSTER_OPTION} <list of cluster>] [${DATACENTER_OPTION} <list of data center>] [${RACK_OPTION} <list of rack>] [${INSTANCE_OPTION} <list of instance>] [${DEBUG_OPTION}] -- <nodetool arguments>" \
            "nodelist|nl <namespace> ${NODE_OPTION} <list of Kubernetes node> [${INSTANCE_OPTION} <list of instance>] [${DEBUG_OPTION}] -- <nodetool arguments>");
          printf -v errmsg "    %s\n" "${options[@]}";
          printf -v errmsg "%s\n%s\n  %s\n%s" \
            "ERROR: Usage:" \
            "${0}" \
            "nodetool" \
            "${errmsg}";
          echoerr "${errmsg}";
          ;;
      esac
      ;;
    create|c)
      case "${2}" in
        namespace|ns)
          shift 2;
          createNamespace "${@}";
          errCode=${?};
          ;;
        nodelabel|nl)
          shift 2;
          createNodeLabel "${@}";
          errCode=${?};
          ;;
        storageclass|sc)
          shift 2;
          createStorageClass "${@}";
          errCode=${?};
          ;;
        persistentvolume|pv)
          case "${3}" in
            nodelist|nl)
              shift 3;
              createNodePersistentVolume "${@}";
              errCode=${?};
              ;;
            clusterlist|cl)
              shift 3;
              createPersistentVolume "${@}";
              errCode=${?};
              ;;
            *)
              errCode=1;
              options=( \
                "clusterlist|cl <[${LOCAL_TYPE}|${LOCAL_TYPE_SHORT}]|[${HOSTPATH_TYPE}|${HOSTPATH_TYPE_SHORT}]> <dataDirectory> <capacity> [${OVERWRITE_OPTION}] [${CLUSTER_OPTION} <list of cluster>] [${DATACENTER_OPTION} <list of data center>] [${RACK_OPTION} <list of rack>]" \
                "nodelist|nl <[${LOCAL_TYPE}|${LOCAL_TYPE_SHORT}]|[${HOSTPATH_TYPE}|${HOSTPATH_TYPE_SHORT}]> <dataDirectory> <capacity> [${OVERWRITE_OPTION}] <list of Kubernetes node>");
              printf -v errmsg "      %s\n" "${options[@]}";
              printf -v errmsg "%s\n%s\n  %s\n    %s\n%s" \
                "ERROR: Usage:" \
                "${0}" \
                "create|c" \
                "persistentvolume|pv" \
                "${errmsg}";
              echoerr "${errmsg}";
              ;;
          esac
          ;;
        service|s)
          case "${3}" in
            client|c)
              shift 3;
              createClientService "${@}";
              errCode=${?};
              ;;
            datacenter|dc)
              shift 3;
              createDataCenterService "${@}";
              errCode=${?};
              ;;
            *)
              errCode=1;
              options=( \
                "client|c <namespace> [<list of cluster>]" \
                "datacenter|dc <namespace> [${CLUSTER_OPTION} <list of cluster>] [${DATACENTER_OPTION} <list of data center>]");
              printf -v errmsg "      %s\n" "${options[@]}";
              printf -v errmsg "%s\n%s\n  %s\n    %s\n%s" \
                "ERROR: Usage:" \
                "${0}" \
                "create|c" \
                "service|s" \
                "${errmsg}";
              echoerr "${errmsg}";
              ;;
          esac
          ;;
        statefulset|sts)
          shift 2;
          createStatefulSet "${@}";
          errCode=${?};
          ;;
        cluster|cl)
          shift 2;
          createCluster "${@}";
          errCode=${?};
          ;;
        *)
          errCode=1;
          options=( \
            "namespace|ns <namespace>" \
            "nodelabel|nl <cluster> <data center> <rack> <instances> [${OVERWRITE_OPTION}] <list of Kubernetes node>" \
            "persistentvolume|pv..." \
            "service|s..." \
            "statefulset|sts <namespace> ${STORAGETYPE_OPTION} <[local|l]|[hostPath|hp]> ${STORAGECAPACITY_OPTION} <storage capacity> ${CPULIMIT_OPTION} <CPU limit> ${MEMORYLIMIT_OPTION} <memory limit> ${CPUREQUEST_OPTION} <CPU request> ${MEMORYREQUEST_OPTION} <memory request> ${MAXHEAPSIZE_OPTION} <max heap size> ${NEWHEAPSIZE_OPTION} <heap new size> [${REPLICAS_OPTION} <desired replicas>]  [${OVERWRITE_OPTION}] [${CLUSTER_OPTION} <list of cluster>] [${DATACENTER_OPTION} <list of data center>] [${RACK_OPTION} <list of rack>]" \
            "cluster|cl <cluster's properties file>" \
            "storageclass|sc <[${LOCAL_TYPE}|${LOCAL_TYPE_SHORT}]|[${HOSTPATH_TYPE}|${HOSTPATH_TYPE_SHORT}]>");
          printf -v errmsg "    %s\n" "${options[@]}";
          printf -v errmsg "%s\n%s\n  %s\n%s" \
            "ERROR: Usage:" \
            "${0}" \
            "create|c" \
            "${errmsg}";
          echoerr "${errmsg}";
          ;;
      esac
      ;;
    delete|d)
      case "${2}" in
        namespace|ns)
          shift 2;
          deleteNamespace "${@}";
          errCode=${?};
          ;;
        nodelabel|nl)
          case "${3}" in
            nodelist|nl)
              shift 3;
              deleteNodeLabel "${@}";
              errCode=${?};
              ;;
            clusterlist|cl)
              shift 3;
              deleteLabel "${@}";
              errCode=${?};
              ;;
            *)
              errCode=1;
              options=( \
                "clusterlist|cl [${FORCE_OPTION}] [${CLUSTER_OPTION} <list of cluster>] [${DATACENTER_OPTION} <list of data center>] [${RACK_OPTION} <list of rack>]" \
                "nodelist|nl [${FORCE_OPTION}] <list of Kubernetes node>");
              printf -v errmsg "      %s\n" "${options[@]}";
              printf -v errmsg "%s\n%s\n  %s\n    %s\n%s" \
                "ERROR: Usage:" \
                "${0}" \
                "delete|d" \
                "nodelabel|nl" \
                "${errmsg}";
              echoerr "${errmsg}";
              ;;
            esac
          ;;
        storageclass|sc)
          shift 2;
          deleteStorageClass "${@}";
          errCode=${?};
          ;;
        persistentvolume|pv)
          case "${3}" in
            nodelist|nl)
              shift 3;
              deleteNodePersistentVolume "${@}";
              errCode=${?};
              ;;
            clusterlist|cl)
              shift 3;
              deletePersistentVolume "${@}";
              errCode=${?};
              ;;
            *)
              errCode=1;
              options=( \
                "clusterlist|cl [${CLUSTER_OPTION} <list of cluster>] [${DATACENTER_OPTION} <list of data center>] [${RACK_OPTION} <list of rack>]" \
                "nodelist|nl <list of Kubernetes node>");
              printf -v errmsg "      %s\n" "${options[@]}";
              printf -v errmsg "%s\n%s\n  %s\n    %s\n%s" \
                "ERROR: Usage:" \
                "${0}" \
                "delete|d" \
                "persistentvolume|pv" \
                "${errmsg}";
              echoerr "${errmsg}";
              ;;
            esac
          ;;
        service|s)
          case "${3}" in
            client|c)
              shift 3;
              deleteClientService "${@}";
              errCode=${?};
              ;;
            datacenter|dc)
              shift 3;
              deleteDataCenterService "${@}";
              errCode=${?};
              ;;
            *)
              errCode=1;
              options=( \
                "client|c <namespace> [<list of cluster>]" \
                "datacenter|dc <namespace> [${CLUSTER_OPTION} <list of cluster>] [${DATACENTER_OPTION} <list of data center>]");
              printf -v errmsg "      %s\n" "${options[@]}";
              printf -v errmsg "%s\n%s\n  %s\n    %s\n%s" \
                "ERROR: Usage:" \
                "${0}" \
                "delete|d" \
                "service|s" \
                "${errmsg}";
              echoerr "${errmsg}";
              ;;
          esac
          ;;
        statefulset|sts)
          shift 2;
          deleteStatefulSet "${@}";
          errCode=${?};
          ;;
        cluster|cl)
          shift 2;
          deleteCluster "${@}";
          errCode=${?};
          ;;
        *)
          errCode=1;
          options=( \
            "cluster|cl <namespace> [${CLUSTER_OPTION} <list of cluster>] [${DATACENTER_OPTION} <list of data center>] [${RACK_OPTION} <list of rack>]" \
            "namespace|ns <namespace>" \
            "nodelabel|nl..." \
            "persistentvolume|pv..." \
            "service|s..." \
            "statefulset|sts <namespace> [${CLUSTER_OPTION} <list of cluster>] [${DATACENTER_OPTION} <list of data center>] [${RACK_OPTION} <list of rack>]" \
            "storageclass|sc <[${LOCAL_TYPE}|${LOCAL_TYPE_SHORT}]|[${HOSTPATH_TYPE}|${HOSTPATH_TYPE_SHORT}]>");
          printf -v errmsg "    %s\n" "${options[@]}";
          printf -v errmsg "%s\n%s\n  %s\n%s" \
            "ERROR: Usage:" \
            "${0}" \
            "delete|d" \
            "${errmsg}";
          echoerr "${errmsg}";
          ;;
      esac
      ;;
    get|g)
      case "${2}" in
        cluster|cl)
          getClusterList;
          errCode=${?};
          ;;
        dataCenter|dc)
          shift 2;
          getDataCenterList "${@}";
          errCode=${?};
          ;;
        rack|rk)
          shift 2;
          getRackList "${@}";
          errCode=${?};
          ;;
        node|n)
          shift 2;
          getNodeList "${@}";
          errCode=${?};
          ;;
        label|l)
          shift 2;
          local nodeLabel="";
          case "${2}" in
            cluster|cl)
              nodeLabel="${CLUSTER_LABEL}";
              ;;
            dataCenter|dc)
              nodeLabel="${DATACENTER_LABEL}";
              ;;
            rack|rk)
              nodeLabel="${RACK_LABEL}";
              ;;
            instances|i)
              nodeLabel="${INSTANCES_LABEL}";
              ;;
            *)
              errCode=1;
              echoerr "ERROR: ${0}: Unknow label \"${2}\"";
              ;;
          esac
          if [[ -n "${nodeLabel}" ]];
          then
            getLabel "${NODE_CLASS}" "${1}" "${nodeLabel}";
            errCode=${?};
          fi
          ;;
        objectType|ot)
          shift 2;
          getObjectList "${@}";
          errCode=${?};
          ;;
        podsOnNode|pon)
          shift 2;
          getPodsOnNode "${@}";
          errCode=${?};
          ;;
        *)
          errCode=1;
          options=( \
            "cluster|cl" \
            "dataCenter|dc [<list of cluster>]" \
            "label|l <Kubernetes node> <[cluster|cl]|[dataCenter|dc]|[rack|rk]|[instances|i]>" \
            "node|n [${CLUSTER_OPTION} <list of cluster>] [${DATACENTER_OPTION} <list of data center> ] [${RACK_OPTION} <list of rack>]" \
            "podsOnNode|pon <Kubernetes node>" \
            "rack|rk [${CLUSTER_OPTION} <list of cluster>] [${DATACENTER_OPTION} <list of data center>]" \
            "objectType|ot <namespace> <object type> [${CLUSTER_OPTION} <list of cluster>] [${DATACENTER_OPTION} <list of data center>] [${RACK_OPTION} <list of rack>] [${NODE_OPTION} <list of Kubernetes node>]");
          printf -v errmsg "    %s\n" "${options[@]}";
          printf -v errmsg "%s\n%s\n  %s\n%s" \
            "ERROR: Usage:" \
            "${0}" \
            "get|g" \
            "${errmsg}";
          echoerr "${errmsg}";
          ;;
      esac
      ;;
    check|ck)
      case "${2}" in
        namespace|ns)
          shift 2;
          checkNamespace "${@}" "${DEBUG_OPTION}";
          errCode=${?};
          ;;
        nodelabel|nl)
          shift 2;
          isCassandraNode "${DEBUG_OPTION}" "${@}";
          errCode=${?};
          ;;
        storageclass|sc)
          shift 2;
          checkStorageClass "${@}" "${DEBUG_OPTION}";
          errCode=${?};
          ;;
        persistentvolume|pv)
          case "${3}" in
            nodelist|nl)
              shift 3;
              checkNodePersistentVolume "${DEBUG_OPTION}" "${@}";
              errCode=${?};
              ;;
            clusterlist|cl)
              shift 3;
              checkPersistentVolume "${DEBUG_OPTION}" "${@}";
              errCode=${?};
              ;;
            *)
              errCode=1;
              options=( \
                "nodelist|nl <list of Kubernetes node>" \
                "clusterlist|cl [${CLUSTER_OPTION} <list of cluster>] [${DATACENTER_OPTION} <list of data center>] [${RACK_OPTION} <list of rack>]");
              printf -v errmsg "      %s\n" "${options[@]}";
              printf -v errmsg "%s\n%s\n  %s\n    %s\n%s" \
                "ERROR: Usage:" \
                "${0}" \
                "check|ck" \
                "persistentvolume|pv" \
                "${errmsg}";
              echoerr "${errmsg}";
              ;;
          esac
          ;;
        service|s)
          case "${3}" in
            client|c)
              shift 3;
              checkClientService "${@}" "${DEBUG_OPTION}";
              errCode=${?};
              ;;
            datacenter|dc)
              shift 3;
              checkDataCenterService "${@}" "${DEBUG_OPTION}";
              errCode=${?};
              ;;
            *)
              errCode=1;
              options=( \
                "client|c <namespace> [${CLUSTER_OPTION} <list of cluster>] [${CREATEIFNOTEXIST_OPTION}]" \
                "datacenter|dc <namespace> [${CLUSTER_OPTION} <list of cluster>] [${DATACENTER_OPTION} <list of data center>] [${CREATEIFNOTEXIST_OPTION}]");
              printf -v errmsg "      %s\n" "${options[@]}";
              printf -v errmsg "%s\n%s\n  %s\n    %s\n%s" \
                "ERROR: Usage:" \
                "${0}" \
                "check|ck" \
                "service|s" \
                "${errmsg}";
              echoerr "${errmsg}";
              ;;
          esac
          ;;
        statefulset|sts)
          shift 2;
          checkStatefulSet "${@}" "${DEBUG_OPTION}";
          errCode=${?};
          ;;
        *)
          errCode=1;
          options=( \
            "namespace|ns <namespace> [${CREATEIFNOTEXIST_OPTION}]" \
            "nodelabel|nl <list of Kubernetes node>" \
            "persistentvolume|pv..." \
            "service|s..." \
            "statefulset|sts <namespace> [${RESTART_OPTION}|${SCALE_OPTION} [${REPLICAS_OPTION} <desired replicas>]|${CREATEIFNOTEXIST_OPTION} ${STORAGETYPE_OPTION} <storage type> ${STORAGECAPACITY_OPTION} <storage capacity> ${CPULIMIT_OPTION} <CPU limit> ${MEMORYLIMIT_OPTION} <memory limit> ${CPUREQUEST_OPTION} <CPU request> ${MEMORYREQUEST_OPTION} <memory request> ${MAXHEAPSIZE_OPTION} <max heap size> ${NEWHEAPSIZE_OPTION} <heap new size> [${REPLICAS_OPTION} <desired replicas>]] [${CLUSTER_OPTION} <list of cluster>] [${DATACENTER_OPTION} <list of data center>] [${RACK_OPTION} <list of rack>]" \
            "storageclass|sc <[${LOCAL_TYPE}|${LOCAL_TYPE_SHORT}]|[${HOSTPATH_TYPE}|${HOSTPATH_TYPE_SHORT}]> [${CREATEIFNOTEXIST_OPTION}]");
          printf -v errmsg "    %s\n" "${options[@]}";
          printf -v errmsg "%s\n%s\n  %s\n%s" \
            "ERROR: Usage:" \
            "${0}" \
            "check|ck" \
            "${errmsg}";
          echoerr "${errmsg}";
          ;;
      esac
      ;;
    *)
      errCode=1;
      options=( \
        "create|c..." \
        "delete|d..." \
        "check|ck..." \
        "get|g..." \
        "nodetool..." \
        "restart <namespace> [${CLUSTER_OPTION} <list of cluster>] [${DATACENTER_OPTION} <list of data center>] [${RACK_OPTION} <list of rack>]" \
        "scale <namespace> [${REPLICAS_OPTION} <[+|-]replicas>] [${CLUSTER_OPTION} <list of cluster>] [${DATACENTER_OPTION} <list of data center>] [${RACK_OPTION} <list of rack>]" \
        "sum..." \
        "topology|topo");
      printf -v errmsg "  %s\n" "${options[@]}";
      printf -v errmsg "%s\n%s\n%s" "ERROR: Usage:" "${0}" "${errmsg}";
      echoerr "${errmsg}";
      ;;
  esac
  return ${errCode};
}

checkRequirements;
if [[ ! ${?} -eq 0 ]];
then
  exit 1;
fi

main "${@}";
exit ${?};
