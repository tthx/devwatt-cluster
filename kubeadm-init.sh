#!/bin/sh
CONFIG_FILE="${1:-"kubeadm-ghost-0-config.yml"}";
CLUSTER_NAME="$(awk '/clusterName:/{print $2}' ${CONFIG_FILE})";
KEY_LENGTH="2048";
CERT_DURATION="365000";
CLIENT_CA_CRT_FILE="$(awk '/requestheader-client-ca-file:/{print $2}' ${CONFIG_FILE})";
PROXY_CLIENT_CRT_FILE="$(awk '/proxy-client-cert-file:/{print $2}' ${CONFIG_FILE})";
PROXY_CLIENT_KEY_FILE="$(awk '/proxy-client-key-file:/{print $2}' ${CONFIG_FILE})";
METRIC_SVR="metric-server";
CSR_FILE="/tmp/request.csr";
cd ${HOME}/src/devwatt-cluster && \
sudo rm -f ${CLIENT_CA_CRT_FILE} \
  ${CLIENT_CA_CRT_FILE/%.crt/.key} \
  ${PROXY_CLIENT_CRT_FILE} \
  ${PROXY_CLIENT_KEY_FILE} && \
# Generate aggregator CA
sudo openssl genrsa \
  -out ${CLIENT_CA_CRT_FILE/%.crt/.key} \
  ${KEY_LENGTH} && \
sudo openssl req \
  -x509 -new -nodes \
  -key ${CLIENT_CA_CRT_FILE/%.crt/.key} \
  -subj "/CN=aggregator-ca" \
  -days ${CERT_DURATION} \
  -out ${CLIENT_CA_CRT_FILE} && \
# Generate apiserver client's key and certificate
sudo openssl genrsa \
  -out ${PROXY_CLIENT_KEY_FILE} \
    ${KEY_LENGTH} && \
sudo openssl req \
  -new -key ${PROXY_CLIENT_KEY_FILE} \
  -subj "/CN=aggregator" \
  -out ${CSR_FILE} && \
sudo openssl x509 \
  -req -in ${CSR_FILE} \
  -CA ${CLIENT_CA_CRT_FILE} \
  -CAkey ${CLIENT_CA_CRT_FILE/%.crt/.key} \
  -CAcreateserial \
  -out ${PROXY_CLIENT_CRT_FILE} \
  -days ${CERT_DURATION} && \
sudo rm -f ${CSR_FILE} && \
kubeadm config images pull && \
sudo kubeadm init \
  --config="${CONFIG_FILE}" && \
mkdir -p $HOME/.kube && \
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config && \
sudo chown $(id -u):$(id -g) $HOME/.kube/config && \
POD_CIDR="$(awk '/podSubnet/{gsub("/", "\\/", $2);print $2}' ${CONFIG_FILE})" && \
curl -s https://docs.projectcalico.org/manifests/calico.yaml | \
  sed -e '/CALICO_IPV4POOL_CIDR/s/\(^.*\)# \(-.*$\)/\1\2/g' \
    -e '/"192.168.0.0\/16"/s/\(^.*\)#.*$/\1  value: "'$POD_CIDR'"/g' \
    -e '/image:\([[:space:]].*\)docker.io\//s/\(^.*\)docker.io\/\(.*$\)/\1\2/g' | \
  kubectl apply -f - && \
kubectl apply -f https://docs.projectcalico.org/manifests/calicoctl.yaml && \
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended.yaml && \
echo "
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard" | kubectl apply -f -


# Generate metrics server's key and certificate
sudo openssl genrsa \
  -out ${METRIC_SVR}.key \
  ${KEY_LENGTH} && \
sudo openssl req \
  -new -key ${METRIC_SVR}.key \
  -subj "/CN=${METRIC_SVR}" \
  -out ${CSR_FILE} && \
sudo openssl x509 \
  -req -in ${CSR_FILE} \
  -CA ${CLIENT_CA_CRT_FILE} \
  -CAkey ${CLIENT_CA_CRT_FILE/%.crt/.key} \
  -out ${METRIC_SVR}.crt \
  -days ${CERT_DURATION} && \
sudo rm -f ${CSR_FILE} && \