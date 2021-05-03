#!/bin/bash
CA_KEY_LENGTH="4096";
CERT_DURATION="365000";
GHOST_CA="ghost-ca";
ETCD_CA="etcd-ca";
# from kubeadm init command:
K8S_CA="kubernetes";
K8S_FRONT_PROXY_CA="front-proxy-ca";
# from https://kubernetes.io/docs/setup/best-practices/certificates/:
K8S_CA="kubernetes-ca";
K8S_FRONT_PROXY_CA="kubernetes-front-proxy-ca";
CA_DIR="ca";
CERT_DIR="cert";
KEY_LENGTH="2048";
KUBE_ETCD="kube-etcd";
KUBE_ETCD_PEER="kube-etcd-peer";
KUBE_ETCD_HEALTHCHECK_CLIENT="kube-etcd-healthcheck-client";
KUBE_APISERVER_ETCD_CLIENT="kube-apiserver-etcd-client";
KUBE_APISERVER="kube-apiserver";
KUBE_APISERVER_KUBELET_CLIENT="kube-apiserver-kubelet-client";
FRONT_PROXY_CLIENT="front-proxy-client";
K8S_PKI_DIR="/etc/kubernetes/pki";
NET_INTERFACE="ens3";
CTRL_PLANE_HOST_NAME="$(hostname)";
CTRL_PLANE_HOST_IP="$(ip -f inet -4 address show dev ${NET_INTERFACE}|awk '/inet/{split($2,x,"/");print x[1]}')";
WORKERS_USER="ubuntu";
WORKERS_HOST_NAME="worker-1 worker-2 worker-3 worker-4";
FIRST_SRV_IP="172.19.0.1"; # We assume that service CIDR is 172.19.0.1/16

rm -rf ./${CA_DIR} ./${CERT_DIR} && \
mkdir -p ./${CA_DIR} ./${CERT_DIR};

# Generate CA configurations
for i in \
  ${GHOST_CA} \
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

# Generate root CA
openssl req \
  -x509 -new -sha256 -nodes \
  -newkey rsa:${CA_KEY_LENGTH} \
  -keyout ./${CA_DIR}/${GHOST_CA}.key \
  -subj "/CN=${GHOST_CA}" \
  -addext "keyUsage=critical,digitalSignature,keyEncipherment,keyCertSign" \
  -addext "subjectAltName=DNS:${GHOST_CA}" \
  -days ${CERT_DURATION} \
  -out ./${CA_DIR}/${GHOST_CA}.crt;

# Generate k8s, etcd and k8s front proxy CA
if [[ ${?} -eq 0 ]];
then
  for i in ${ETCD_CA} ${K8S_CA} ${K8S_FRONT_PROXY_CA};
  do
    openssl req -new -sha256 \
      -nodes -newkey rsa:${CA_KEY_LENGTH} \
      -keyout ./${CERT_DIR}/${i}.key \
      -subj "/CN=${i}" \
      -out ./${CERT_DIR}/${i}.csr && \
    yes yes | openssl ca \
      -config ./${CA_DIR}/${GHOST_CA}.cfg \
      -extfile <(echo "
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer
basicConstraints=critical,CA:TRUE
keyUsage=critical,digitalSignature,keyEncipherment,keyCertSign
subjectAltName=DNS:${i}
") \
      -out ./${CERT_DIR}/${i}.crt \
      -infiles ./${CERT_DIR}/${i}.csr && \
    openssl verify -CAfile ./${CA_DIR}/${GHOST_CA}.crt ./${CERT_DIR}/${i}.crt && \
    mv ./${CERT_DIR}/${i}.key ./${CERT_DIR}/${i}.crt ./${CA_DIR}/. && \
    rm -f ./${CERT_DIR}/${i}.csr;
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

# Certificates signed by etcd CA
tee ./${CERT_DIR}/${KUBE_ETCD}.cfg <<EOF
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth,clientAuth
subjectAltName=DNS:${CTRL_PLANE_HOST_NAME},DNS:localhost,IP:${CTRL_PLANE_HOST_IP},IP:127.0.0.1,IP:0:0:0:0:0:0:0:1
EOF
tee ./${CERT_DIR}/${KUBE_ETCD_PEER}.cfg <<EOF
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth,clientAuth
subjectAltName=DNS:${CTRL_PLANE_HOST_NAME},DNS:localhost,IP:${CTRL_PLANE_HOST_IP},IP:127.0.0.1,IP:0:0:0:0:0:0:0:1
EOF
tee ./${CERT_DIR}/${KUBE_ETCD_HEALTHCHECK_CLIENT}.cfg <<EOF
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=clientAuth
EOF
tee ./${CERT_DIR}/${KUBE_APISERVER_ETCD_CLIENT}.cfg <<EOF
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
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
    -subj "/CN=${i}$(echo ${i}|awk '/kube-apiserver-etcd-client|kube-etcd-healthcheck-client/{print "/O=system:masters"}')" \
    -out ./${CERT_DIR}/${i}.csr && \
  yes yes | openssl ca \
    -config ./${CA_DIR}/${ETCD_CA}.cfg \
    -extfile ./${CERT_DIR}/${i}.cfg \
    -out ./${CERT_DIR}/${i}.crt \
    -infiles ./${CERT_DIR}/${i}.csr && \
  openssl verify -CAfile ./${CA_DIR}/${GHOST_CA}-bundle.crt ./${CERT_DIR}/${i}.crt && \
  rm -f ./${CERT_DIR}/${i}.cfg ./${CERT_DIR}/${i}.csr;
  if [[ ${?} -ne 0 ]];
  then
    echo "ERROR: Unable to create certificate for ${i}" >&2;
    exit 1;
  fi
done

tee ./${CERT_DIR}/${KUBE_APISERVER}.cfg <<EOF
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:${CTRL_PLANE_HOST_NAME},IP:${CTRL_PLANE_HOST_IP},IP:${FIRST_SRV_IP},DNS:kubernetes,DNS:kubernetes.default,DNS:kubernetes.default.svc,DNS:kubernetes.default.svc.cluster,DNS:kubernetes.default.svc.cluster.local
EOF
tee ./${CERT_DIR}/${KUBE_APISERVER_KUBELET_CLIENT}.cfg <<EOF
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
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
    -infiles ./${CERT_DIR}/${i}.csr && \
  openssl verify -CAfile ./${CA_DIR}/${GHOST_CA}-bundle.crt ./${CERT_DIR}/${i}.crt && \
  rm -f ./${CERT_DIR}/${i}.cfg ./${CERT_DIR}/${i}.csr;
  if [[ ${?} -ne 0 ]];
  then
    echo "ERROR: Unable to create certificate for ${i}" >&2;
    exit 1;
  fi
done

for i in ${WORKERS_HOST_NAME};
do
  worker_hostname="$(ssh ${WORKERS_USER}@${i} hostname)";
  worker_ip="$(ssh ${WORKERS_USER}@${i} ip -f inet -4 address show dev ${NET_INTERFACE}|awk '/inet/{split($2,x,"/");print x[1]}')";
  rm -f ./${CERT_DIR}/${worker_hostname}.key ./${CERT_DIR}/${worker_hostname}.csr ./${CERT_DIR}/${worker_hostname}.crt && \
  openssl req -new -sha256 \
    -nodes -newkey rsa:${KEY_LENGTH} \
    -keyout ./${CERT_DIR}/${worker_hostname}.key \
    -subj "/CN=system:node:${worker_hostname}/O=system:nodes" \
    -out ./${CERT_DIR}/${worker_hostname}.csr && \
  yes yes | openssl ca \
    -config ./${CA_DIR}/${K8S_CA}.cfg \
    -extfile <(echo "
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=clientAuth
subjectAltName=DNS:${worker_hostname},IP:${worker_ip}
") \
    -out ./${CERT_DIR}/${worker_hostname}.crt \
    -infiles ./${CERT_DIR}/${worker_hostname}.csr && \
  openssl verify -CAfile ./${CA_DIR}/${GHOST_CA}-bundle.crt ./${CERT_DIR}/${worker_hostname}.crt && \
  rm -f ./${CERT_DIR}/${worker_hostname}.csr;
  if [[ ${?} -ne 0 ]];
  then
    echo "ERROR: Unable to create certificate for ${worker_hostname}" >&2;
    exit 1;
  fi
done

tee ./${CERT_DIR}/${FRONT_PROXY_CLIENT}.cfg <<EOF
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
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
    -infiles ./${CERT_DIR}/${i}.csr && \
  openssl verify -CAfile ./${CA_DIR}/${GHOST_CA}-bundle.crt ./${CERT_DIR}/${i}.crt && \
  rm -f ./${CERT_DIR}/${i}.cfg ./${CERT_DIR}/${i}.csr;
  if [[ ${?} -ne 0 ]];
  then
    echo "ERROR: Unable to create certificate for ${i}" >&2;
    exit 1;
  fi
done

if [[ -n "${1}" ]];
then
  sudo mkdir -p ${K8S_PKI_DIR}/etcd && \
  sudo cp -f ./${CA_DIR}/${ETCD_CA}.crt ${K8S_PKI_DIR}/etcd/ca.crt && \
  sudo cp -f ./${CA_DIR}/${ETCD_CA}.key ${K8S_PKI_DIR}/etcd/ca.key && \
  sudo cp -f ./${CERT_DIR}/${KUBE_ETCD}.crt ${K8S_PKI_DIR}/etcd/server.crt && \
  sudo cp -f ./${CERT_DIR}/${KUBE_ETCD}.key ${K8S_PKI_DIR}/etcd/server.key && \
  sudo cp -f ./${CERT_DIR}/${KUBE_ETCD_PEER}.crt ${K8S_PKI_DIR}/etcd/peer.crt && \
  sudo cp -f ./${CERT_DIR}/${KUBE_ETCD_PEER}.key ${K8S_PKI_DIR}/etcd/peer.key && \
  sudo cp -f ./${CERT_DIR}/${KUBE_ETCD_HEALTHCHECK_CLIENT}.crt ${K8S_PKI_DIR}/etcd/healthcheck-client.crt && \
  sudo cp -f ./${CERT_DIR}/${KUBE_ETCD_HEALTHCHECK_CLIENT}.key ${K8S_PKI_DIR}/etcd/healthcheck-client.key && \
  sudo cp -f ./${CA_DIR}/${K8S_CA}.crt ${K8S_PKI_DIR}/ca.crt && \
  sudo cp -f ./${CA_DIR}/${K8S_CA}.key ${K8S_PKI_DIR}/ca.key && \
  sudo cp -f ./${CERT_DIR}/${KUBE_APISERVER_ETCD_CLIENT}.crt ${K8S_PKI_DIR}/apiserver-etcd-client.crt && \
  sudo cp -f ./${CERT_DIR}/${KUBE_APISERVER_ETCD_CLIENT}.key ${K8S_PKI_DIR}/apiserver-etcd-client.key && \
  sudo cp -f ./${CERT_DIR}/${KUBE_APISERVER}.crt ${K8S_PKI_DIR}/apiserver.crt && \
  sudo cp -f ./${CERT_DIR}/${KUBE_APISERVER}.key ${K8S_PKI_DIR}/apiserver.key && \
  sudo cp -f ./${CERT_DIR}/${KUBE_APISERVER_KUBELET_CLIENT}.crt ${K8S_PKI_DIR}/apiserver-kubelet-client.crt && \
  sudo cp -f ./${CERT_DIR}/${KUBE_APISERVER_KUBELET_CLIENT}.key ${K8S_PKI_DIR}/apiserver-kubelet-client.key && \
  sudo cp -f ./${CA_DIR}/${K8S_FRONT_PROXY_CA}.crt ${K8S_PKI_DIR}/front-proxy-ca.crt && \
  sudo cp -f ./${CA_DIR}/${K8S_FRONT_PROXY_CA}.key ${K8S_PKI_DIR}/front-proxy-ca.key && \
  sudo cp -f ./${CERT_DIR}/${FRONT_PROXY_CLIENT}.crt ${K8S_PKI_DIR}/. && \
  sudo cp -f ./${CERT_DIR}/${FRONT_PROXY_CLIENT}.key ${K8S_PKI_DIR}/. && \
  sudo chown -R root:root ${K8S_PKI_DIR} && \
  sudo chmod 600 ${K8S_PKI_DIR}/*.key ${K8S_PKI_DIR}/etcd/*.key && \
  sudo chmod 644 ${K8S_PKI_DIR}/*.crt ${K8S_PKI_DIR}/etcd/*.crt
fi

exit 0;
