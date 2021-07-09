#!/bin/bash
. "$(dirname "${BASH_SOURCE[0]}")"/disable-hugepage.sh
. "$(dirname "${BASH_SOURCE[0]}")"/snap-remove.sh
. "$(dirname "${BASH_SOURCE[0]}")"/chrony-install.sh
. "$(dirname "${BASH_SOURCE[0]}")"/docker-install.sh
. "$(dirname "${BASH_SOURCE[0]}")"/kubeadm-install.sh
function k8s_install {
  disable_hugepage;
  snap_remove;
  chrony_install;
  docker_install;
  kubeadm_install;
  return ${?};
}

k8s_install;
exit ${?};
