#!/bin/sh
CA_KEY_LENGTH="4096";
CERT_DURATION="365000";
GHOST_CA="ghost-ca";
K8S_CA="kubernetes-ca";
ETCD_CA="etcd-ca";
K8S_FRONT_PROXY_CA="kubernetes-front-proxy-ca";
# Generate root CA
rm -f ${GHOST_CA}.key ${GHOST_CA}.crt ${GHOST_CA}.txt && \
openssl genrsa \
  -out ${GHOST_CA}.key \
  ${CA_KEY_LENGTH} && \
openssl req \
  -x509 -new -nodes \
  -key ${GHOST_CA}.key \
  -subj "/CN=${GHOST_CA}" \
  -addext "keyUsage=critical,digitalSignature,keyEncipherment,keyCertSign" \
  -days ${CERT_DURATION} \
  -out ${GHOST_CA}.crt
# Generate k8s, etcd and k8s front proxy CA
if [[ ${?} -eq 0 ]];
then
  for i in ${K8S_CA} ${ETCD_CA} ${K8S_FRONT_PROXY_CA};
  do
    rm -f ${i}.key ${i}.csr ${i}.crt && \
    openssl genrsa \
      -out ${i}.key \
      ${CA_KEY_LENGTH} && \
    openssl req \
      -new -key ${i}.key \
      -subj "/CN=${i}" \
      -addext "keyUsage=critical,digitalSignature,keyEncipherment,keyCertSign" \
      -out ${i}.csr && \
    openssl x509 \
      -req -in ${i}.csr \
      -CA ${GHOST_CA}.crt \
      -CAkey ${GHOST_CA}.key \
      -CAcreateserial \
      -CAserial ${GHOST_CA}.txt \
      -out ${i}.crt \
      -days ${CERT_DURATION}
  done
fi
if [[ ${?} -eq 0 ]];
then
  cat ${GHOST_CA}.crt ${K8S_CA}.crt ${ETCD_CA}.crt ${K8S_FRONT_PROXY_CA}.crt > ${GHOST_CA}-bundle.crt && \
  openssl verify -CAfile ${GHOST_CA}.crt ${GHOST_CA}-bundle.crt
fi

# Certificates from etcd CA
KEY_LENGTH="2048";
KUBE_ETCD="kube-etcd";
KUBE_ETCD_PEER="kube-etcd-peer";
KUBE_ETCD_HEALTHCHECK_CLIENT="kube-etcd-healthcheck-client";
KUBE_APISERVER_ETCD_CLIENT="kube-apiserver-etcd-client";
rm -f ${KUBE_ETCD}.key ${KUBE_ETCD}.csr ${KUBE_ETCD}.crt && \
openssl genrsa \
  -out ${KUBE_ETCD}.key \
  ${KEY_LENGTH} && \
openssl req \
  -new -key ${KUBE_ETCD}.key \
  -subj "/CN=${KUBE_ETCD}" \
  -addext "keyUsage=critical,digitalSignature,keyEncipherment,keyCertSign" \
  -addext "extendedKeyUsage=serverAuth,clientAuth" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" \
  -out ${KUBE_ETCD}.csr && \
openssl x509 \
  -req -in ${KUBE_ETCD}.csr \
  -CA ${ETCD_CA}.crt \
  -CAkey ${ETCD_CA}.key \
  -CAcreateserial \
  -CAserial ${ETCD_CA}.txt \
  -out ${KUBE_ETCD}.crt \
  -days ${CERT_DURATION} && \
openssl x509 -in ${KUBE_ETCD}.crt -text