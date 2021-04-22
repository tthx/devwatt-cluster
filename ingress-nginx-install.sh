#!/bin/bash
curl -s https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.45.0/deploy/static/provider/baremetal/deploy.yaml | \
  sed -e '/image:\([[:space:]].*\)docker.io\//s/\(^.*\)docker.io\/\(.*$\)/\1\2/g' | \
  kubectl apply -f -

curl -s https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.45.0/deploy/static/provider/baremetal/deploy.yaml | kubectl delete -f -