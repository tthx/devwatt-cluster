#!/bin/sh
sudo kubeadm init \
  --control-plane-endpoint="$(ifconfig ens3|awk '$1~/^inet$/{print $2}')" \
  --apiserver-advertise-address="$(ifconfig ens3|awk '$1~/^inet$/{print $2}')" \
  --pod-network-cidr=192.168.0.0/16 && \
mkdir -p $HOME/.kube && \
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config && \
sudo chown $(id -u):$(id -g) $HOME/.kube/config && \
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml && \
kubectl apply -f https://docs.projectcalico.org/manifests/calicoctl.yaml