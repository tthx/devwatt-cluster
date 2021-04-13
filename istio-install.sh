#!/bin/sh
curl -L https://istio.io/downloadIstio | sh - && \
cd istio* && \
export PATH=$PWD/bin:$PATH && \

# demo profile
istioctl install --set profile=demo -y && \
kubectl label namespace default istio-injection=enabled && \
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml && \
kubectl get services && \
kubectl get pods -A -w

kubectl exec "$(kubectl get pod -l app=ratings -o jsonpath='{.items[0].metadata.name}')" -c ratings -- curl -sS productpage:9080/productpage | \
  grep -o "<title>.*</title>" && \
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml && \
istioctl analyze && \
kubectl get svc istio-ingressgateway -n istio-system
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
export INGRESS_HOST=$(kubectl get po -l istio=ingressgateway -n istio-system -o jsonpath='{.items[0].status.hostIP}')
export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT
curl -v http://$GATEWAY_URL/productpage

kubectl apply -f samples/addons && \
kubectl rollout status deployment/kiali -n istio-system && \
istioctl dashboard kiali

# delete
kubectl delete -f samples/addons && \
istioctl manifest generate --set profile=demo | \
  kubectl delete --ignore-not-found=true -f - && \
kubectl delete namespace istio-system && \
kubectl label namespace default istio-injection- && \
kubectl delete -f samples/bookinfo/platform/kube/bookinfo.yaml

# default profile
istioctl install --set profile=default -y
istioctl manifest generate --set profile=default | \
  kubectl delete --ignore-not-found=true -f -