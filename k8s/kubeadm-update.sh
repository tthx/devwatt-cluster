#!/bin/bash
. "$(dirname "${BASH_SOURCE[0]}")"/k8s-env.sh
function kubeadm_update {
  local i;
  for i in ${CTRL_PLANE} ${WORKERS};
  do
    ssh ${SSH_OPTS} ${SUDO_USER}@${i} " \
      set -euo pipefail;
      sudo apt-mark unhold kubelet kubeadm kubectl;
      sudo apt-get update;
      sudo apt-get install -y kubelet kubeadm kubectl;
      sudo apt-mark hold kubelet kubeadm kubectl";
  done
  return ${?};
}
