#!/bin/bash
WORKERS_USER="ubuntu";
WORKERS_HOST_NAME="worker-1 worker-2 worker-3 worker-4";
K8S_CONF_DIR="/etc/kubernetes";
NET_INTERFACE="ens3";
DEBUG_LEVEL="9"; # 0 to 9
for i in ${WORKERS_HOST_NAME};
do
  ssh ${WORKERS_USER}@${i} sudo kubeadm join \
  --v=${DEBUG_LEVEL} \
  --token "$(kubeadm token list|awk 'NR!=1 {print $1}')" \
  "$(ip -f inet -4 address show dev ${NET_INTERFACE}|awk '/inet/{split($2,x,"/");print x[1]}')":6443 \
  --discovery-token-ca-cert-hash sha256:"$(openssl x509 -pubkey -in ${K8S_CONF_DIR}/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')";
done

PENDING_CSR="$(kubectl get csr|awk '$5~/Pending/{print $1}')";
for i in ${PENDING_CSR};
do
  kubectl certificate approve ${i};
done

exit ${?};
