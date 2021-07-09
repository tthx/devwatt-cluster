#!/bin/bash
. "$(dirname "${BASH_SOURCE[0]}")"/k8s-env.sh
function kubeadm_join {
  local debug_level="0"; # 0 to 9
  local token="$(ssh ${SSH_OPTS} ${SUDO_USER}@${CTRL_PLANE} " \
    set -euo pipefail;
    kubeadm token list | awk 'NR!=1 {print \$1}'")";
  local token_ca_cert_hash="$(ssh ${SSH_OPTS} ${SUDO_USER}@${CTRL_PLANE} " \
    set -euo pipefail;
    openssl x509 -pubkey -in ${K8S_CONF_DIR}/pki/ca.crt | \
      openssl ${KEY_TYPE//dsa/} -pubin -outform der 2>/dev/null | \
      openssl dgst -sha256 -hex | \
      sed 's/^.* //'")";
  local pending_csr;
  local i;
  for i in ${WORKERS};
  do
    ssh ${SSH_OPTS} ${SUDO_USER}@${i} " \
      sudo kubeadm join \
        --v=${debug_level} \
        --token ${token} \
        ${CTRL_PLANE_IP}:6443 \
        --discovery-token-ca-cert-hash sha256:${token_ca_cert_hash}";
  done
  pending_csr="$(ssh ${SSH_OPTS} ${SUDO_USER}@${CTRL_PLANE} \
    "set -euo pipefail; kubectl get csr | awk '\$5~/Pending/{print \$1}'")";
  for i in ${pending_csr};
  do
    ssh ${SSH_OPTS} ${SUDO_USER}@${CTRL_PLANE} \
      "kubectl certificate approve ${i}";
  done
  return ${?};
}
