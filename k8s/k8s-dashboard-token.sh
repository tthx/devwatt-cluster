#!/bin/bash
. "$(dirname "${BASH_SOURCE[0]}")"/k8s-env.sh
function k8s_dashboard_token {
  echo "$(ssh ${SSH_OPTS} ${SUDO_USER}@${CTRL_PLANE} " \
    set -euo pipefail;
    kubectl -n kubernetes-dashboard get secret \$(kubectl -n kubernetes-dashboard get sa/admin-user -o jsonpath=\"{.secrets[0].name}\") -o go-template=\"{{.data.token | base64decode}}\"")";
  return ${?};
}

k8s_dashboard_token;
exit ${?};
