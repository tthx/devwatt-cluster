#!/bin/sh
sudo kubeadm config images pull && \
POD_CIDR="172.18.0.0/16" && \
SVR_CIDR="172.19.0.0/16" && \
sudo kubeadm init \
  --image-repository="k8s.gcr.io" \
  --control-plane-endpoint="$(ifconfig ens3|awk '$1~/^inet$/{print $2}')" \
  --apiserver-advertise-address="$(ifconfig ens3|awk '$1~/^inet$/{print $2}')" \
  --pod-network-cidr="${POD_CIDR}" \
  --service-cidr="${SVR_CIDR}" && \
mkdir -p $HOME/.kube && \
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config && \
sudo chown $(id -u):$(id -g) $HOME/.kube/config && \
POD_CIDR="172.18.0.0\/16" && \
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
  