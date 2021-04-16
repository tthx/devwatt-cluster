#!/bin/sh
cd ${HOME}/src/devwatt-cluster && \
MASTER_IP="$(ifconfig ens3|awk '$1~/^inet$/{print $2}')" && \
KEY_LENGTH="2048" && \
CERT_DURATION="365000" && \
CLIENT_CA="client-ca" && \
PROXY_CLIENT="proxy-client" && \
PKI_DEST_DIR="/etc/kubernetes/pki" && \
rm -f ${CLIENT_CA}.crt ${CLIENT_CA}.key ${PROXY_CLIENT}.crt ${PROXY_CLIENT}.key && \
openssl genrsa -out ${CLIENT_CA}.key ${KEY_LENGTH} && \
openssl req -x509 -new -nodes -key ${CLIENT_CA}.key -subj "/CN=${MASTER_IP}" -days ${CERT_DURATION} -out ${CLIENT_CA}.crt && \
openssl genrsa -out ${PROXY_CLIENT}.key ${KEY_LENGTH} && \
openssl req -new -key ${PROXY_CLIENT}.key -subj "/CN=${MASTER_IP}" -out ${PROXY_CLIENT}.csr && \
openssl x509 -req -in ${PROXY_CLIENT}.csr -CA ${CLIENT_CA}.crt -CAkey ${CLIENT_CA}.key -CAcreateserial -out ${PROXY_CLIENT}.crt -days ${CERT_DURATION} && \
METRIC_SVR="metric-server" && \
openssl genrsa -out ${METRIC_SVR}.key ${KEY_LENGTH} && \
openssl req -new -key ${METRIC_SVR}.key -subj "/CN=${METRIC_SVR}" -out ${METRIC_SVR}.csr && \
openssl x509 -req -in ${METRIC_SVR}.csr -CA ${CLIENT_CA}.crt -CAkey ${CLIENT_CA}.key -CAcreateserial -out ${METRIC_SVR}.crt -days ${CERT_DURATION} && \
sudo mkdir -p ${PKI_DEST_DIR} && \
sudo mv ${CLIENT_CA}.crt ${CLIENT_CA}.key ${PROXY_CLIENT}.crt ${PROXY_CLIENT}.key ${METRIC_SVR}.csr ${METRIC_SVR}.key ${PKI_DEST_DIR}/. && \
sudo chown -R root:root ${PKI_DEST_DIR} && \
sudo chmod 600 ${PKI_DEST_DIR}/${CLIENT_CA}.key ${PKI_DEST_DIR}/${PROXY_CLIENT}.key ${PKI_DEST_DIR}/${METRIC_SVR}.key && \
kubeadm config images pull && \
CLUSTER_NAME="ghost-0" && \
sudo kubeadm init \
  --config="kubeadm-${CLUSTER_NAME}-config.yml" && \
mkdir -p $HOME/.kube && \
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config && \
sudo chown $(id -u):$(id -g) $HOME/.kube/config && \
POD_CIDR="$(awk '/podSubnet/{gsub("/", "\\/", $2);print $2}' kubeadm-${CLUSTER_NAME}-config.yml)" && \
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
  