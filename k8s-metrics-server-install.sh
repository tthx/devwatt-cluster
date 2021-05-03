#!/bin/bash
CA_KEY_LENGTH="4096";
CERT_DURATION="365000";
METRICS_CA_CN="metrics-server-ca";
CA_DIR="ca";
CERT_DIR="cert";
KEY_LENGTH="2048";
METRICS_CERT_CN="metrics-server.kube-system.svc";
DOCKER_IMAGE_REPO="dockerfactory-playground.tech.orange";

rm -rf ./${CA_DIR} ./${CERT_DIR} && \
mkdir -p ./${CA_DIR} ./${CERT_DIR} && \
openssl req \
  -x509 -new -sha256 -nodes \
  -newkey rsa:${CA_KEY_LENGTH} \
  -keyout ./${CA_DIR}/${METRICS_CA_CN}.key \
  -subj "/CN=${METRICS_CA_CN}" \
  -addext "keyUsage=critical,digitalSignature,keyEncipherment,keyCertSign" \
  -addext "subjectAltName=DNS:${METRICS_CA_CN}" \
  -days ${CERT_DURATION} \
  -out ./${CA_DIR}/${METRICS_CA_CN}.crt && \
touch ./${CA_DIR}/${METRICS_CA_CN}.txt && \
echo "01" > ./${CA_DIR}/${METRICS_CA_CN}.srl && \
tee ./${CA_DIR}/${METRICS_CA_CN}.cfg <<EOF
[ca]
default_ca=my_ca
[my_ca]
serial=./${CA_DIR}/${METRICS_CA_CN}.srl
database=./${CA_DIR}/${METRICS_CA_CN}.txt
new_certs_dir=./${CERT_DIR}
certificate=./${CA_DIR}/${METRICS_CA_CN}.crt
private_key=./${CA_DIR}/${METRICS_CA_CN}.key
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
tee ./${CERT_DIR}/${METRICS_CERT_CN/.*/}.cfg <<EOF
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:${METRICS_CERT_CN}
EOF

openssl req -new -sha256 \
  -nodes -newkey rsa:${KEY_LENGTH} \
  -keyout ./${CERT_DIR}/${METRICS_CERT_CN/.*/}.key \
  -subj "/CN=${METRICS_CERT_CN}" \
  -out ./${CERT_DIR}/${METRICS_CERT_CN/.*/}.csr && \
yes yes | openssl ca \
  -config ./${CA_DIR}/${METRICS_CA_CN}.cfg \
  -extfile ./${CERT_DIR}/${METRICS_CERT_CN/.*/}.cfg \
  -out ./${CERT_DIR}/${METRICS_CERT_CN/.*/}.crt \
  -infiles ./${CERT_DIR}/${METRICS_CERT_CN/.*/}.csr && \
openssl verify -CAfile ./${CA_DIR}/${METRICS_CA_CN}.crt ./${CERT_DIR}/${METRICS_CERT_CN/.*/}.crt && \
rm -f ./${CERT_DIR}/${METRICS_CERT_CN/.*/}.cfg ./${CERT_DIR}/${METRICS_CERT_CN/.*/}.csr;
if [[ ${?} -ne 0 ]];
then
  echo "ERROR: Unable to create certificate for ${METRICS_CERT_CN}" >&2;
  exit 1;
fi

MANIFESTS_DIR="manifests";
METRICS_DEPLOY_FILE="components.yaml";
DEPLOY_PATCH_FILE="deployment-patch.yaml";
APISERVICE_PATCH_FILE="apiservice-patch.yaml";
METRICS_SECRET="metrics-server-tls";
METRICS_CERT_PATH="/etc/kubernetes/metrics-server/certs";
mkdir ./${MANIFESTS_DIR} && \
mv -f ./${CA_DIR}/${METRICS_CA_CN}.crt ./${CERT_DIR}/${METRICS_CERT_CN/.*/}.crt ./${CERT_DIR}/${METRICS_CERT_CN/.*/}.key ${MANIFESTS_DIR}/. && \
curl -Ls https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml|\
  sed -e '/image:\([[:space:]].*\)k8s.gcr.io\//s/\(^.*\)k8s.gcr.io\/\(.*$\)/\1'${DOCKER_IMAGE_REPO}'\/\2/g' > \
  ./${MANIFESTS_DIR}/${METRICS_DEPLOY_FILE}

tee ./${MANIFESTS_DIR}/${DEPLOY_PATCH_FILE} <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: metrics-server
  namespace: kube-system
spec:
  template:
    spec:
      containers:
      - name: metrics-server
        args:
        - --secure-port=4443
        - --kubelet-preferred-address-types=Hostname,ExternalIP,InternalIP
        - --kubelet-use-node-status-port
        - --tls-cert-file=${METRICS_CERT_PATH}/tls.crt
        - --tls-private-key-file=${METRICS_CERT_PATH}/tls.key
        volumeMounts:
        - name: secret-volume
          readOnly: true
          mountPath: "${METRICS_CERT_PATH}"
      volumes:
      - name: secret-volume
        secret:
          secretName: ${METRICS_SECRET}
EOF

tee ./${MANIFESTS_DIR}/${APISERVICE_PATCH_FILE} <<EOF
apiVersion: apiregistration.k8s.io/v1
kind: APIService
metadata:
  name: v1beta1.metrics.k8s.io
spec:
  insecureSkipTLSVerify: false
  caBundle: $(base64 --wrap=0 ./${MANIFESTS_DIR}/${METRICS_CA_CN}.crt)
EOF

tee ./${MANIFESTS_DIR}/kustomization.yaml <<EOF
namespace: kube-system
secretGenerator:
- name: ${METRICS_SECRET}
  files:
  - tls.crt=${METRICS_CERT_CN/.*/}.crt
  - tls.key=${METRICS_CERT_CN/.*/}.key
  type: "kubernetes.io/tls"
resources:
- ${METRICS_DEPLOY_FILE}
patchesStrategicMerge:
- ${DEPLOY_PATCH_FILE}
- ${APISERVICE_PATCH_FILE}
EOF

#kubectl kustomize ./${MANIFESTS_DIR} && \
#kubectl apply -k ./${MANIFESTS_DIR}
