#!/bin/bash
HOST_IP="$(ip -f inet -4 address show dev ens3|awk '/inet/{split($2,x,"/");print x[1]}')";
CLUSTER_NAME="ghost-0";
POD_CIDR="172.18.0.0/16";
SRV_CIDR="172.19.0.0/16";
DOCKER_IMAGE_REPO="dockerfactory-playground.tech.orange";
tee ./${CLUSTER_NAME}.cfg <<EOF
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
    advertise-address: ${HOST_IP}
    requestheader-client-ca-file: /etc/kubernetes/pki/front-proxy-ca.crt
    requestheader-allowed-names: ""
    requestheader-extra-headers-prefix: X-Remote-Extra-
    requestheader-group-headers: X-Remote-Group
    requestheader-username-headers: X-Remote-User
    proxy-client-cert-file: /etc/kubernetes/pki/front-proxy-client.crt
    proxy-client-key-file: /etc/kubernetes/pki/front-proxy-client.key
    enable-aggregator-routing: "true"
EOF
kubeadm config images pull --image-repository ${DOCKER_IMAGE_REPO} && \
sudo kubeadm init \
  --config=./${CLUSTER_NAME}.cfg && \
rm -f ./${CLUSTER_NAME}.cfg && \
mkdir -p $HOME/.kube && \
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config && \
sudo chown $(id -u):$(id -g) $HOME/.kube/config && \
curl -s https://docs.projectcalico.org/manifests/calico.yaml | \
  sed -e '/CALICO_IPV4POOL_CIDR/s/\(^.*\)# \(-.*$\)/\1\2/g' \
    -e '/"192.168.0.0\/16"/s/\(^.*\)#.*$/\1  value: "'${POD_CIDR/\//\\\/}'"/g' \
    -e '/image:\([[:space:]].*\)docker.io\//s/\(^.*\)docker.io\/\(.*$\)/\1\2/g' | \
  kubectl apply -f - && \
kubectl apply -f https://docs.projectcalico.org/manifests/calicoctl.yaml && \
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended.yaml && \
kubectl apply -f <(echo "
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
  namespace: kubernetes-dashboard")
