#!/bin/sh
CA_KEY_LENGTH="4096";
CERT_DURATION="365000";
GHOST_CA="ghost-ca";
ETCD_CA="etcd-ca";
K8S_CA="kubernetes-ca";
K8S_FRONT_PROXY_CA="kubernetes-front-proxy-ca";
CERTS_DIR="certs";
# Generate root CA
mkdir -p ${CERTS_DIR} && \
rm -f ${GHOST_CA}.key ${GHOST_CA}.crt ${GHOST_CA}.srl && \
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
  for i in ${ETCD_CA} ${K8S_CA} ${K8S_FRONT_PROXY_CA};
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
      -CAserial ${GHOST_CA}.srl \
      -out ${i}.crt \
      -days ${CERT_DURATION}
    if [[ ${?} -ne 0 ]];
    then
      exit 1;
    fi
  done
fi

cat ${GHOST_CA}.crt ${ETCD_CA}.crt ${K8S_CA}.crt ${K8S_FRONT_PROXY_CA}.crt > ${GHOST_CA}-bundle.crt && \
rm -f ${ETCD_CA}.csr ${K8S_CA}.csr ${K8S_FRONT_PROXY_CA}.csr && \
openssl verify -CAfile ${GHOST_CA}.crt ${GHOST_CA}-bundle.crt

# Generate CA configuration
for i in ${ETCD_CA} ${K8S_CA} ${K8S_FRONT_PROXY_CA};
do
  touch ./${i}.txt && \
  echo "01" > ./${i}.srl && \
  tee ${i}.cfg <<EOF
[ca]
default_ca=my_ca
[my_ca]
serial=./${i}.srl
database=./${i}.txt
new_certs_dir=./${CERTS_DIR}
certificate=./${i}.crt
private_key=./${i}.key
default_md=sha256
default_days=${CERT_DURATION}
policy=my_policy
[my_policy]
countryName=optional
stateOrProvinceName=optional
organizationName=optional
commonName=supplied
organizationalUnitName=optional
EOF
  if [[ ${?} -ne 0 ]];
  then
    exit 1;
  fi
done

# Certificates signed by etcd CA
KEY_LENGTH="2048";
KUBE_ETCD="kube-etcd";
tee ./${CERTS_DIR}/${KUBE_ETCD}.cfg <<EOF
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,dataEncipherment
extendedKeyUsage=serverAuth,clientAuth
subjectAltName=DNS:localhost,IP:127.0.0.1
EOF
KUBE_ETCD_PEER="kube-etcd-peer";
tee ./${CERTS_DIR}/${KUBE_ETCD_PEER}.cfg <<EOF
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,dataEncipherment
extendedKeyUsage=serverAuth,clientAuth
subjectAltName=DNS:$(hostname),IP:$(ifconfig ens3|awk '$1~/^inet$/{print $2}'),DNS:localhost,IP:127.0.0.1
EOF
KUBE_ETCD_HEALTHCHECK_CLIENT="kube-etcd-healthcheck-client";
tee ./${CERTS_DIR}/${KUBE_ETCD_HEALTHCHECK_CLIENT}.cfg <<EOF
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,dataEncipherment
extendedKeyUsage=clientAuth
EOF
KUBE_APISERVER_ETCD_CLIENT="kube-apiserver-etcd-client";
tee ./${CERTS_DIR}/${KUBE_APISERVER_ETCD_CLIENT}.cfg <<EOF
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,dataEncipherment
extendedKeyUsage=clientAuth
EOF
for i in \
  ${KUBE_ETCD} \
  ${KUBE_ETCD_PEER} \
  ${KUBE_ETCD_HEALTHCHECK_CLIENT} \
  ${KUBE_APISERVER_ETCD_CLIENT};
do
  rm -f ./${CERTS_DIR}/${i}.key ./${CERTS_DIR}/${i}.csr ./${CERTS_DIR}/${i}.crt && \
  openssl req -new -sha256 \
    -nodes -newkey rsa:${KEY_LENGTH} \
    -keyout ./${CERTS_DIR}/${i}.key \
    -subj "/CN=${i}$(echo ${i}|awk '/kube-apiserver-etcd-client/{print "/O=system:masters"}')" \
    -out ./${CERTS_DIR}/${i}.csr && \
  yes yes | openssl ca \
    -config ${ETCD_CA}.cfg \
    -extfile ./${CERTS_DIR}/${i}.cfg \
    -out ./${CERTS_DIR}/${i}.crt \
    -infiles ./${CERTS_DIR}/${i}.csr && \
  rm -f ./${CERTS_DIR}/${i}.csr
  if [[ ${?} -ne 0 ]];
  then
    exit 1;
  fi
done

KUBE_APISERVER="kube-apiserver";
tee ./${CERTS_DIR}/${KUBE_APISERVER}.cfg <<EOF
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,dataEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:master,IP:192.168.0.49,DNS:kubernetes,DNS:kubernetes.default,DNS:kubernetes.default.svc,DNS:kubernetes.default.svc.cluster,DNS:kubernetes.default.svc.cluster.local
EOF
KUBE_APISERVER_KUBELET_CLIENT="kube-apiserver-kubelet-client";
tee ./${CERTS_DIR}/${KUBE_APISERVER_KUBELET_CLIENT}.cfg <<EOF
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,dataEncipherment
extendedKeyUsage=clientAuth
EOF
for i in \
  ${KUBE_APISERVER} \
  ${KUBE_APISERVER_KUBELET_CLIENT};
do
  rm -f ./${CERTS_DIR}/${i}.key ./${CERTS_DIR}/${i}.csr ./${CERTS_DIR}/${i}.crt && \
  openssl req -new -sha256 \
    -nodes -newkey rsa:${KEY_LENGTH} \
    -keyout ./${CERTS_DIR}/${i}.key \
    -subj "/CN=${i}$(echo ${i}|awk '/kube-apiserver-kubelet-client/{print "/O=system:masters"}')" \
    -out ./${CERTS_DIR}/${i}.csr && \
  yes yes | openssl ca \
    -config ${K8S_CA}.cfg \
    -extfile ./${CERTS_DIR}/${i}.cfg \
    -out ./${CERTS_DIR}/${i}.crt \
    -infiles ./${CERTS_DIR}/${i}.csr && \
  rm -f ./${CERTS_DIR}/${i}.csr
  if [[ ${?} -ne 0 ]];
  then
    exit 1;
  fi
done

FRONT_PROXY_CLIENT="front-proxy-client";
tee ./${CERTS_DIR}/${FRONT_PROXY_CLIENT}.cfg <<EOF
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,dataEncipherment
extendedKeyUsage=clientAuth
EOF
for i in \
  ${FRONT_PROXY_CLIENT};
do
  rm -f ./${CERTS_DIR}/${i}.key ./${CERTS_DIR}/${i}.csr ./${CERTS_DIR}/${i}.crt && \
  openssl req -new -sha256 \
    -nodes -newkey rsa:${KEY_LENGTH} \
    -keyout ./${CERTS_DIR}/${i}.key \
    -subj "/CN=${i}" \
    -out ./${CERTS_DIR}/${i}.csr && \
  yes yes | openssl ca \
    -config ${K8S_FRONT_PROXY_CA}.cfg \
    -extfile ./${CERTS_DIR}/${i}.cfg \
    -out ./${CERTS_DIR}/${i}.crt \
    -infiles ./${CERTS_DIR}/${i}.csr && \
  rm -f ./${CERTS_DIR}/${i}.csr
  if [[ ${?} -ne 0 ]];
  then
    exit 1;
  fi
done