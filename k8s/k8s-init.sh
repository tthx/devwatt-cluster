#!/bin/bash
. "$(dirname "${BASH_SOURCE[0]}")"/kubeadm-gen-certs.sh
. "$(dirname "${BASH_SOURCE[0]}")"/kubeadm-init.sh
. "$(dirname "${BASH_SOURCE[0]}")"/calico-and-dashboard-install.sh
. "$(dirname "${BASH_SOURCE[0]}")"/kubeadm-join.sh
. "$(dirname "${BASH_SOURCE[0]}")"/metrics-server-install.sh
function k8s_init {
  if [[ "${GEN_CERTS}" == "yes" ]];
  then
    kubeadm_gen_certs install;
  fi
  kubeadm_init;
  calico_and_dashboard_install;
  kubeadm_join;
  metrics_server_install;
  return ${?};
}

k8s_init;
exit ${?};
