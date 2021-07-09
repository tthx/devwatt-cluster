#!/bin/bash
. "$(dirname "${BASH_SOURCE[0]}")"/k8s-env.sh
function calico_and_dashboard_install {
  ssh ${SSH_OPTS} ${SUDO_USER}@${CTRL_PLANE} \
    "set -euo pipefail;
    POD_CIDR=\"${POD_CIDR}\";
    CALICO_DOCKER_IMAGE_REPO=\"${CALICO_DOCKER_IMAGE_REPO}\";
    curl -Ls https://docs.projectcalico.org/manifests/calico.yaml | \
    sed \
      -e '/CALICO_IPV4POOL_CIDR/s/\(^.*\)# \(-.*\$\)/\1\2/g' \
      -e '/\"192.168.0.0\/16\"/s/\(^.*\)#.*\$/\1  value: \"'\${POD_CIDR/\//\\\/}'\"/g' \
      -e '/image:\([[:space:]].*\)docker.io\//s/\(^.*\)docker.io\/\(.*\$\)/\1'\${CALICO_DOCKER_IMAGE_REPO}'\/\2/g' | \
      kubectl apply -f -;
    kubectl apply -f https://docs.projectcalico.org/manifests/calicoctl.yaml;
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended.yaml;
    echo \
\"apiVersion: v1
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
  namespace: kubernetes-dashboard\" | \
      kubectl apply -f -";
  return ${?};
}