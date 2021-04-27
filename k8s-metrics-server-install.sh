#!/bin/bash
CA_KEY_LENGTH="4096";
CERT_DURATION="365000";
CA_CN="metrics-server-ca";
CA_DIR="ca";
CERT_DIR="cert";
KEY_LENGTH="2048";
CERT_CN="metrics-server.kube-system.svc";
DOCKER_IMAGE_REPO="dockerfactory-playground.tech.orange";

rm -rf ./${CA_DIR} ./${CERT_DIR} && \
mkdir -p ./${CA_DIR} ./${CERT_DIR} && \
openssl req \
  -x509 -new -sha256 -nodes \
  -newkey rsa:${CA_KEY_LENGTH} \
  -keyout ./${CA_DIR}/${CA_CN}.key \
  -subj "/CN=${CA_CN}" \
  -addext "keyUsage=critical,digitalSignature,keyEncipherment,keyCertSign" \
  -addext "subjectAltName=DNS:${CA_CN}" \
  -days ${CERT_DURATION} \
  -out ./${CA_DIR}/${CA_CN}.crt && \
touch ./${CA_DIR}/${CA_CN}.txt && \
echo "01" > ./${CA_DIR}/${CA_CN}.srl && \
tee ./${CA_DIR}/${CA_CN}.cfg <<EOF
[ca]
default_ca=my_ca
[my_ca]
serial=./${CA_DIR}/${CA_CN}.srl
database=./${CA_DIR}/${CA_CN}.txt
new_certs_dir=./${CERT_DIR}
certificate=./${CA_DIR}/${CA_CN}.crt
private_key=./${CA_DIR}/${CA_CN}.key
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
tee ./${CERT_DIR}/${CERT_CN/.*/}.cfg <<EOF
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:${CERT_CN}
EOF

openssl req -new -sha256 \
  -nodes -newkey rsa:${KEY_LENGTH} \
  -keyout ./${CERT_DIR}/${CERT_CN/.*/}.key \
  -subj "/CN=${CERT_CN}" \
  -out ./${CERT_DIR}/${CERT_CN/.*/}.csr && \
yes yes | openssl ca \
  -config ./${CA_DIR}/${CA_CN}.cfg \
  -extfile ./${CERT_DIR}/${CERT_CN/.*/}.cfg \
  -out ./${CERT_DIR}/${CERT_CN/.*/}.crt \
  -infiles ./${CERT_DIR}/${CERT_CN/.*/}.csr && \
openssl verify -CAfile ./${CA_DIR}/${CA_CN}.crt ./${CERT_DIR}/${CERT_CN/.*/}.crt && \
rm -f ./${CERT_DIR}/${CERT_CN/.*/}.cfg ./${CERT_DIR}/${CERT_CN/.*/}.csr;
if [[ ${?} -ne 0 ]];
then
  echo "ERROR: Unable to create certificate for ${CERT_CN}" >&2;
  exit 1;
fi

tee ${CERT_CN/.*/}.yml <<EOF
$(curl -Ls https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml|\
  sed -e '/image:\([[:space:]].*\)k8s.gcr.io\//s/\(^.*\)k8s.gcr.io\/\(.*$\)/\1'${DOCKER_IMAGE_REPO}'\/\2/g')
  insecureSkipTLSVerify: false
  caBundle: $(base64 --wrap=0 ./${CA_DIR}/${CA_CN}.crt)
EOF