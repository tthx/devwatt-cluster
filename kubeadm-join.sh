#!/bin/bash
USER="ubuntu";
NODES="worker-1 worker-2 worker-3 worker-4";
K8S_PKI_DIR="/etc/kubernetes/pki";
NET_INTERFACE="ens3";
for i in ${NODES};
do
  ssh ${USER}@${i} sudo kubeadm join \
  --token "$(kubeadm token list|awk 'NR!=1 {print $1}')" \
  "$(ip -f inet -4 address show dev ${NET_INTERFACE}|awk '/inet/{split($2,x,"/");print x[1]}')":6443 \
  --discovery-token-ca-cert-hash sha256:"$(openssl x509 -pubkey -in ${K8S_PKI_DIR}/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')";
done
