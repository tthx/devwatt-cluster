#!/bin/sh
MASTER_IP="$(ifconfig ens3|awk '$1~/^inet$/{print $2}')";
KEY_LENGTH="2048";
CERT_DURATION="365000";
CLIENT_CA="client-ca";
PROXY_CLIENT="proxy-client";
DEST_DIR="/etc/kubernetes/agregator/pki";
rm -f ${CLIENT_CA}.crt ${CLIENT_CA}.key ${PROXY_CLIENT}.crt ${PROXY_CLIENT}.key && \
openssl genrsa -out ${CLIENT_CA}.key ${KEY_LENGTH} && \
openssl req -x509 -new -nodes -key ${CLIENT_CA}.key -subj "/CN=${MASTER_IP}" -days ${CERT_DURATION} -out ${CLIENT_CA}.crt && \
openssl genrsa -out ${PROXY_CLIENT}.key ${KEY_LENGTH} && \
openssl req -new -key ${PROXY_CLIENT}.key -subj "/CN=${MASTER_IP}" -out ${PROXY_CLIENT}.csr && \
openssl x509 -req -in ${PROXY_CLIENT}.csr -CA ${CLIENT_CA}.crt -CAkey ${CLIENT_CA}.key -CAcreateserial -out ${PROXY_CLIENT}.crt -days ${CERT_DURATION} && \
sudo mkdir -p ${DEST_DIR} && \
sudo cp ${CLIENT_CA}.crt ${CLIENT_CA}.key ${PROXY_CLIENT}.crt ${PROXY_CLIENT}.key ${DEST_DIR}/.
sudo chown -R root:root ${DEST_DIR} && \
sudo chmod 600 ${CLIENT_CA}.key ${PROXY_CLIENT}.key