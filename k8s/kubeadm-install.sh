#!/bin/bash
. "$(dirname "${BASH_SOURCE[0]}")"/k8s-env.sh
function kubeadm_install {
  local i;
  for i in ${CTRL_PLANE} ${WORKERS};
  do
    ssh ${SSH_OPTS} ${SUDO_USER}@${i} " \
      set -euo pipefail;
      echo \
\"overlay
br_netfilter\" | \
        sudo tee /etc/modules-load.d/k8s.conf > /dev/null;
      echo \
\"net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1\" | \
        sudo tee /etc/sysctl.d/k8s.conf > /dev/null;
      sudo sysctl --system;
      sudo apt-get update;
      sudo apt-get -y install network-manager;
      sudo mkdir -p /etc/NetworkManager/conf.d;
      echo \
\"[keyfile]
unmanaged-devices=interface-name:cali*;interface-name:tunl*;interface-name:vxlan.calico;interface-name:flannel*\" | \
        sudo tee /etc/NetworkManager/conf.d/unmanaged-devices.conf > /dev/null;
      sudo systemctl reload NetworkManager;
      sudo apt-get update;
      sudo apt-get install -y apt-transport-https ca-certificates open-iscsi nfs-common curl grep gawk jq haveged;
      sudo curl -fsSLo \
        /usr/share/keyrings/kubernetes-archive-keyring.gpg \
        https://packages.cloud.google.com/apt/doc/apt-key.gpg;
      echo \"deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main\" | \
        sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null;
      sudo apt-get update;
      sudo apt-get install -y kubelet kubeadm kubectl;
      sudo apt-mark hold kubelet kubeadm kubectl"
  done
return ${?};
}
