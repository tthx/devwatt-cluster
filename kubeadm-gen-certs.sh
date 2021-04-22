#!/bin/sh
CA_KEY_LENGTH="4096";
CERT_DURATION="365000";
GHOST_CA="ghost-ca";
ETCD_CA="etcd-ca";
K8S_CA="kubernetes-ca";
K8S_FRONT_PROXY_CA="kubernetes-front-proxy-ca";
CA_DIR="ca";
CERT_DIR="cert";
HOST_NAME="$(hostname)";
HOST_IP="$(ip -f inet -4 address show dev ens3|awk '/inet/{split($2,x,"/");print x[1]}')";
# Generate root CA
rm -rf ./${CA_DIR} ./${CERT_DIR} && \
mkdir -p ./${CA_DIR} ./${CERT_DIR} && \
openssl genrsa \
  -out ./${CA_DIR}/${GHOST_CA}.key \
  ${CA_KEY_LENGTH} && \
openssl req \
  -x509 -new -nodes \
  -key ./${CA_DIR}/${GHOST_CA}.key \
  -subj "/CN=${GHOST_CA}" \
  -addext "keyUsage=critical,digitalSignature,keyEncipherment,keyCertSign" \
  -days ${CERT_DURATION} \
  -out ./${CA_DIR}/${GHOST_CA}.crt;
# Generate k8s, etcd and k8s front proxy CA
if [[ ${?} -eq 0 ]];
then
  for i in ${ETCD_CA} ${K8S_CA} ${K8S_FRONT_PROXY_CA};
  do
    openssl genrsa \
      -out ./${CA_DIR}/${i}.key \
      ${CA_KEY_LENGTH} && \
    openssl req \
      -new -key ./${CA_DIR}/${i}.key \
      -subj "/CN=${i}" \
      -addext "keyUsage=critical,digitalSignature,keyEncipherment,keyCertSign" \
      -out ./${CA_DIR}/${i}.csr && \
    openssl x509 \
      -req -in ./${CA_DIR}/${i}.csr \
      -CA ./${CA_DIR}/${GHOST_CA}.crt \
      -CAkey ./${CA_DIR}/${GHOST_CA}.key \
      -CAcreateserial \
      -CAserial ./${CA_DIR}/${GHOST_CA}.srl \
      -out ./${CA_DIR}/${i}.crt \
      -days ${CERT_DURATION};
    if [[ ${?} -ne 0 ]];
    then
      echo "ERROR: Unable to create certificate for ${i}" >&2;
      exit 1;
    fi
  done
fi

cat ./${CA_DIR}/${GHOST_CA}.crt \
  ./${CA_DIR}/${ETCD_CA}.crt \
  ./${CA_DIR}/${K8S_CA}.crt \
  ./${CA_DIR}/${K8S_FRONT_PROXY_CA}.crt > \
  ./${CA_DIR}/${GHOST_CA}-bundle.crt && \
openssl verify \
  -CAfile ./${CA_DIR}/${GHOST_CA}.crt \
  ./${CA_DIR}/${GHOST_CA}-bundle.crt;
if [[ ${?} -ne 0 ]];
then
  echo "ERROR: Unable to create CA bundle" >&2;
  exit 1;
fi

# Generate CA configuration
for i in \
  ${ETCD_CA} \
  ${K8S_CA} \
  ${K8S_FRONT_PROXY_CA};
do
  touch ./${CA_DIR}/${i}.txt && \
  echo "01" > ./${CA_DIR}/${i}.srl && \
  tee ./${CA_DIR}/${i}.cfg <<EOF
[ca]
default_ca=my_ca
[my_ca]
serial=./${CA_DIR}/${i}.srl
database=./${CA_DIR}/${i}.txt
new_certs_dir=./${CERT_DIR}
certificate=./${CA_DIR}/${i}.crt
private_key=./${CA_DIR}/${i}.key
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
done

# Certificates signed by etcd CA
KEY_LENGTH="2048";
KUBE_ETCD="kube-etcd";
tee ./${CERT_DIR}/${KUBE_ETCD}.cfg <<EOF
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,dataEncipherment
extendedKeyUsage=serverAuth,clientAuth
subjectAltName=DNS:${HOST_NAME},DNS:localhost,IP:${HOST_IP},IP:127.0.0.1,IP:::1
EOF
KUBE_ETCD_PEER="kube-etcd-peer";
tee ./${CERT_DIR}/${KUBE_ETCD_PEER}.cfg <<EOF
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,dataEncipherment
extendedKeyUsage=serverAuth,clientAuth
subjectAltName=DNS:${HOST_NAME},DNS:localhost,IP:${HOST_IP},IP:127.0.0.1,IP:::1
EOF
KUBE_ETCD_HEALTHCHECK_CLIENT="kube-etcd-healthcheck-client";
tee ./${CERT_DIR}/${KUBE_ETCD_HEALTHCHECK_CLIENT}.cfg <<EOF
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,dataEncipherment
extendedKeyUsage=clientAuth
EOF
KUBE_APISERVER_ETCD_CLIENT="kube-apiserver-etcd-client";
tee ./${CERT_DIR}/${KUBE_APISERVER_ETCD_CLIENT}.cfg <<EOF
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
  openssl req -new -sha256 \
    -nodes -newkey rsa:${KEY_LENGTH} \
    -keyout ./${CERT_DIR}/${i}.key \
    -subj "/CN=${i}$(echo ${i}|awk '/kube-apiserver-etcd-client/{print "/O=system:masters"}')" \
    -out ./${CERT_DIR}/${i}.csr && \
  yes yes | openssl ca \
    -config ./${CA_DIR}/${ETCD_CA}.cfg \
    -extfile ./${CERT_DIR}/${i}.cfg \
    -out ./${CERT_DIR}/${i}.crt \
    -infiles ./${CERT_DIR}/${i}.csr;
  if [[ ${?} -ne 0 ]];
  then
    echo "ERROR: Unable to create certificate for ${i}" >&2;
    exit 1;
  fi
done

KUBE_APISERVER="kube-apiserver";
tee ./${CERT_DIR}/${KUBE_APISERVER}.cfg <<EOF
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,dataEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:${HOST_NAME},IP:${HOST_IP},IP:172.19.0.1,DNS:kubernetes,DNS:kubernetes.default,DNS:kubernetes.default.svc,DNS:kubernetes.default.svc.cluster,DNS:kubernetes.default.svc.cluster.local
EOF
KUBE_APISERVER_KUBELET_CLIENT="kube-apiserver-kubelet-client";
tee ./${CERT_DIR}/${KUBE_APISERVER_KUBELET_CLIENT}.cfg <<EOF
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,dataEncipherment
extendedKeyUsage=clientAuth
EOF
for i in \
  ${KUBE_APISERVER} \
  ${KUBE_APISERVER_KUBELET_CLIENT};
do
  rm -f ./${CERT_DIR}/${i}.key ./${CERT_DIR}/${i}.csr ./${CERT_DIR}/${i}.crt && \
  openssl req -new -sha256 \
    -nodes -newkey rsa:${KEY_LENGTH} \
    -keyout ./${CERT_DIR}/${i}.key \
    -subj "/CN=${i}$(echo ${i}|awk '/kube-apiserver-kubelet-client/{print "/O=system:masters"}')" \
    -out ./${CERT_DIR}/${i}.csr && \
  yes yes | openssl ca \
    -config ./${CA_DIR}/${K8S_CA}.cfg \
    -extfile ./${CERT_DIR}/${i}.cfg \
    -out ./${CERT_DIR}/${i}.crt \
    -infiles ./${CERT_DIR}/${i}.csr;
  if [[ ${?} -ne 0 ]];
  then
    echo "ERROR: Unable to create certificate for ${i}" >&2;
    exit 1;
  fi
done

FRONT_PROXY_CLIENT="front-proxy-client";
tee ./${CERT_DIR}/${FRONT_PROXY_CLIENT}.cfg <<EOF
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,dataEncipherment
extendedKeyUsage=clientAuth
EOF
for i in \
  ${FRONT_PROXY_CLIENT};
do
  rm -f ./${CERT_DIR}/${i}.key ./${CERT_DIR}/${i}.csr ./${CERT_DIR}/${i}.crt && \
  openssl req -new -sha256 \
    -nodes -newkey rsa:${KEY_LENGTH} \
    -keyout ./${CERT_DIR}/${i}.key \
    -subj "/CN=${i}" \
    -out ./${CERT_DIR}/${i}.csr && \
  yes yes | openssl ca \
    -config ./${CA_DIR}/${K8S_FRONT_PROXY_CA}.cfg \
    -extfile ./${CERT_DIR}/${i}.cfg \
    -out ./${CERT_DIR}/${i}.crt \
    -infiles ./${CERT_DIR}/${i}.csr;
  if [[ ${?} -ne 0 ]];
  then
    echo "ERROR: Unable to create certificate for ${i}" >&2;
    exit 1;
  fi
done

if [[ -n "${1}" ]];
then
  DEST_DIR="/etc/kubernetes/pki";
  sudo mkdir -p ${DEST_DIR}/etcd && \
  sudo cp -f ./${CA_DIR}/${ETCD_CA}.crt ${DEST_DIR}/etcd/ca.crt && \
  sudo cp -f ./${CA_DIR}/${ETCD_CA}.key ${DEST_DIR}/etcd/ca.key && \
  sudo cp -f ./${CERT_DIR}/${KUBE_ETCD}.crt ${DEST_DIR}/etcd/server.crt && \
  sudo cp -f ./${CERT_DIR}/${KUBE_ETCD}.key ${DEST_DIR}/etcd/server.key && \
  sudo cp -f ./${CERT_DIR}/${KUBE_ETCD_PEER}.crt ${DEST_DIR}/etcd/peer.crt && \
  sudo cp -f ./${CERT_DIR}/${KUBE_ETCD_PEER}.key ${DEST_DIR}/etcd/peer.key && \
  sudo cp -f ./${CERT_DIR}/${KUBE_ETCD_HEALTHCHECK_CLIENT}.crt ${DEST_DIR}/etcd/healthcheck-client.crt && \
  sudo cp -f ./${CERT_DIR}/${KUBE_ETCD_HEALTHCHECK_CLIENT}.key ${DEST_DIR}/etcd/healthcheck-client.key && \
  sudo cp -f ./${CA_DIR}/${K8S_CA}.crt ${DEST_DIR}/ca.crt && \
  sudo cp -f ./${CA_DIR}/${K8S_CA}.key ${DEST_DIR}/ca.key && \
  sudo cp -f ./${CERT_DIR}/${KUBE_APISERVER_ETCD_CLIENT}.crt ${DEST_DIR}/apiserver-etcd-client.crt && \
  sudo cp -f ./${CERT_DIR}/${KUBE_APISERVER_ETCD_CLIENT}.key ${DEST_DIR}/apiserver-etcd-client.key && \
  sudo cp -f ./${CERT_DIR}/${KUBE_APISERVER}.crt ${DEST_DIR}/apiserver.crt && \
  sudo cp -f ./${CERT_DIR}/${KUBE_APISERVER}.key ${DEST_DIR}/apiserver.key && \
  sudo cp -f ./${CERT_DIR}/${KUBE_APISERVER_KUBELET_CLIENT}.crt ${DEST_DIR}/apiserver-kubelet-client.crt && \
  sudo cp -f ./${CERT_DIR}/${KUBE_APISERVER_KUBELET_CLIENT}.key ${DEST_DIR}/apiserver-kubelet-client.key && \
  sudo cp -f ./${CA_DIR}/${K8S_FRONT_PROXY_CA}.crt ${DEST_DIR}/front-proxy-ca.crt && \
  sudo cp -f ./${CA_DIR}/${K8S_FRONT_PROXY_CA}.key ${DEST_DIR}/front-proxy-ca.key && \
  sudo cp -f ./${CERT_DIR}/${FRONT_PROXY_CLIENT}.crt ${DEST_DIR}/front-proxy-client.crt && \
  sudo cp -f ./${CERT_DIR}/${FRONT_PROXY_CLIENT}.key ${DEST_DIR}/front-proxy-client.key && \
  sudo chown -R root:root ${DEST_DIR} && \
  sudo chmod 600 ${DEST_DIR}/*.key ${DEST_DIR}/etcd/*.key && \
  sudo chmod 644 ${DEST_DIR}/*.crt ${DEST_DIR}/etcd/*.crt
fi

exit 0;
