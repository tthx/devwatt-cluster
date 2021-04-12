#!/bin/sh
# Remove snap: read: https://www.linuxtricks.fr/wiki/ubuntu-supprimer-et-bloquer-les-snaps
sudo tee /etc/apt/preferences.d/nosnap <<EOF
Package: snapd
Pin: release *
Pin-Priority: -1
EOF

sudo tee /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

sudo tee /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

sudo apt-get update && \
sudo apt-get -y install network-manager && \
sudo mkdir -p /etc/NetworkManager/conf.d && \
sudo tee /etc/NetworkManager/conf.d/unmanaged-devices.conf << EOF
[keyfile]
unmanaged-devices=interface-name:cali*;interface-name:tunl*;interface-name:vxlan.calico;interface-name:flannel*
EOF

sudo systemctl reload NetworkManager

sudo apt-get update && \
sudo apt-get install -y apt-transport-https ca-certificates open-iscsi nfs-common curl grep gawk jq && \
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg && \
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list && \
sudo apt-get update && \
sudo apt-get install -y kubelet kubeadm kubectl && \
sudo apt-mark hold kubelet kubeadm kubectl

# Upgrade kubelet kubeadm kubectl
sudo apt-mark unhold kubelet kubeadm kubectl && \
sudo apt-get update && \
sudo apt-get install -y kubelet kubeadm kubectl && \
sudo apt-mark hold kubelet kubeadm kubectl
