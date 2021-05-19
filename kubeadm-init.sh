#!/bin/bash
NET_INTERFACE="ens3";
HOST_IP="$(ip -f inet -4 address show dev ${NET_INTERFACE}|awk '/inet/{split($2,x,"/");print x[1]}')";
CLUSTER_NAME="ghost-0";
POD_CIDR="172.18.0.0/16";
SRV_CIDR="172.19.0.0/16";
DOCKER_IMAGE_REPO="dockerfactory-playground.tech.orange";
K8S_CONF_DIR="/etc/kubernetes";
K8S_PKI_DIR="${K8S_CONF_DIR}/pki";
# NOTE: we put the following file in ${K8S_CONF_DIR}/pki because it is mounted by default in docker container
REST_ENCRYPTION_CONF="${K8S_PKI_DIR}/rest-encryption.yml";
DEBUG_LEVEL="10";
sudo mkdir -p ${K8S_PKI_DIR};
sudo tee ${REST_ENCRYPTION_CONF} <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
    - secrets
    providers:
    - aescbc:
        keys:
        - name: key1
          secret: $(head -c 32 /dev/urandom | base64)
    - identity: {}
EOF
sudo chown -R root:root ${K8S_PKI_DIR};
sudo chmod 600 ${REST_ENCRYPTION_CONF};
tee /tmp/${CLUSTER_NAME}.cfg <<EOF
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
networking:
  serviceSubnet: ${SRV_CIDR}
  podSubnet: ${POD_CIDR}
controlPlaneEndpoint: ${HOST_IP}
imageRepository: ${DOCKER_IMAGE_REPO}
clusterName: ${CLUSTER_NAME}
apiServer:
  extraArgs:
    insecure-port: '0'
    enable-bootstrap-token-auth: 'true'
    allow-privileged: 'true'
    enable-admission-plugins: 'NamespaceLifecycle,LimitRanger,ResourceQuota,ServiceAccount,PersistentVolumeLabel,DefaultStorageClass,DefaultTolerationSeconds,NodeRestriction'
    kubelet-preferred-address-types: 'InternalIP,ExternalIP,Hostname'
    runtime-config: 'v1=true,api/all=true'
    advertise-address: '${HOST_IP}'
    requestheader-allowed-names: 'front-proxy-client'
    requestheader-extra-headers-prefix: 'X-Remote-Extra-'
    requestheader-group-headers: 'X-Remote-Group'
    requestheader-username-headers: 'X-Remote-User'
    requestheader-client-ca-file: '${K8S_PKI_DIR}/front-proxy-ca.crt'
    proxy-client-cert-file: '${K8S_PKI_DIR}/front-proxy-client.crt'
    proxy-client-key-file: '${K8S_PKI_DIR}/front-proxy-client.key'
    enable-aggregator-routing: 'true'
    encryption-provider-config: '${REST_ENCRYPTION_CONF}'
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
readOnlyPort: 0
serverTLSBootstrap: true
EOF
tee /tmp/dashboard.yml <<EOF
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
  namespace: kubernetes-dashboard
EOF
kubeadm config images pull --image-repository ${DOCKER_IMAGE_REPO} && \
sudo kubeadm init \
  --v=${DEBUG_LEVEL} \
  --config=/tmp/${CLUSTER_NAME}.cfg && \
rm -f /tmp/${CLUSTER_NAME}.cfg && \
mkdir -p $HOME/.kube && \
sudo cp -f ${K8S_CONF_DIR}/admin.conf $HOME/.kube/config && \
sudo chown $(id -u):$(id -g) $HOME/.kube/config && \
curl -Ls https://docs.projectcalico.org/manifests/calico.yaml | \
  sed -e '/CALICO_IPV4POOL_CIDR/s/\(^.*\)# \(-.*$\)/\1\2/g' \
    -e '/"192.168.0.0\/16"/s/\(^.*\)#.*$/\1  value: "'${POD_CIDR/\//\\\/}'"/g' \
    -e '/image:\([[:space:]].*\)docker.io\//s/\(^.*\)docker.io\/\(.*$\)/\1'${DOCKER_IMAGE_REPO}'\/\2/g' | \
  kubectl apply -f - && \
kubectl apply -f https://docs.projectcalico.org/manifests/calicoctl.yaml && \
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended.yaml && \
kubectl apply -f /tmp/dashboard.yml && \
rm -f /tmp/dashboard.yml
