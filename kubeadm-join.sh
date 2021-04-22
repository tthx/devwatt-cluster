#!/bin/sh
sudo kubeadm join \
  --token "$(kubeadm token list|awk 'NR!=1 {print $1}')" \
  "$(ip -f inet -4 address show dev ens3|awk '/inet/{split($2,x,"/");print x[1]}')":6443 \
  --discovery-token-ca-cert-hash sha256:"$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')"
