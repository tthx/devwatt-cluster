#!/bin/bash
WORKERS_USER="ubuntu";
WORKERS_HOST_NAME="worker-1 worker-2 worker-3 worker-4";
K8S_CONF_DIR="/etc/kubernetes";
KUBELET_CONF_FILENAME="kubelet.conf";
NET_INTERFACE="ens3";
for i in ${WORKERS_HOST_NAME};
do
  ssh ${WORKERS_USER}@${i} sudo kubeadm join \
  --token "$(kubeadm token list|awk 'NR!=1 {print $1}')" \
  "$(ip -f inet -4 address show dev ${NET_INTERFACE}|awk '/inet/{split($2,x,"/");print x[1]}')":6443 \
  --discovery-token-ca-cert-hash sha256:"$(openssl x509 -pubkey -in ${K8S_CONF_DIR}/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')";
done

for i in ${WORKERS_HOST_NAME};
do
  cert_finename="$(ssh ${WORKERS_USER}@${i} "sudo awk '/client-certificate:/{print \$2}' ${K8S_CONF_DIR}/${KUBELET_CONF_FILENAME}")";
  key_filename="$(ssh ${WORKERS_USER}@${i} "sudo awk '/client-key:/{print \$2}' ${K8S_CONF_DIR}/${KUBELET_CONF_FILENAME}")";
  ssh ${WORKERS_USER}@${i} sudo cp /tmp/certs/${worker_hostname}.crt ${cert_finename}
  ssh ${WORKERS_USER}@${i} sudo cp /tmp/certs/${worker_hostname}.key ${key_filename}
done