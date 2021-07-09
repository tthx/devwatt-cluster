#!/bin/bash
. "$(dirname "${BASH_SOURCE[0]}")"/k8s-env.sh
function metrics_server_install {
  local metrics_ca_cn="metrics-server-ca";
  local ca_dir="metrics-server/ca";
  local cert_dir="metrics-server/cert";
  local metrics_cert_cn="metrics-server.kube-system.svc";
  local debug_level="0"; # 0 to 9
  local manifests_dir="metrics-server/manifests";
  local metrics_deploy_file="components.yaml";
  local deploy_patch_file="deployment-patch.yaml";
  local apiservice_patch_file="apiservice-patch.yaml";
  local metrics_secret="metrics-server-tls";
  local metrics_server_port="443";
  rm -rf ./${ca_dir} ./${cert_dir};
  mkdir -p ./${ca_dir} ./${cert_dir};
  openssl req \
    -x509 -new -sha256 -nodes \
    -newkey $(get_ca_keyparams) \
    -keyout ./${ca_dir}/${metrics_ca_cn}.key \
    -subj "/CN=${metrics_ca_cn}" \
    -addext "keyUsage=critical,digitalSignature,keyEncipherment,keyCertSign" \
    -addext "subjectAltName=DNS:${metrics_ca_cn}" \
    -days $((CERT_DURATION*CA_CERT_DURATION_FACTOR)) \
    -out ./${ca_dir}/${metrics_ca_cn}.crt;
  touch ./${ca_dir}/${metrics_ca_cn}.txt;
  echo "01" > ./${ca_dir}/${metrics_ca_cn}.srl;
  echo \
"[ca]
default_ca=my_ca
[my_ca]
serial=./${ca_dir}/${metrics_ca_cn}.srl
database=./${ca_dir}/${metrics_ca_cn}.txt
new_certs_dir=./${cert_dir}
certificate=./${ca_dir}/${metrics_ca_cn}.crt
private_key=./${ca_dir}/${metrics_ca_cn}.key
default_md=sha256
default_days=${CERT_DURATION}
policy=my_policy
[my_policy]
countryName=optional
stateOrProvinceName=optional
organizationName=optional
commonName=supplied
organizationalUnitName=optional" | \
    tee ./${ca_dir}/${metrics_ca_cn}.cfg > /dev/null;
  echo \
"subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:${metrics_cert_cn}" | \
    tee ./${cert_dir}/${metrics_cert_cn/.*/}.cfg > /dev/null;
  openssl req \
    -new -sha256 -nodes \
    -newkey $(get_keyparams) \
    -keyout ./${cert_dir}/${metrics_cert_cn/.*/}.key \
    -subj "/CN=${metrics_cert_cn}" \
    -out ./${cert_dir}/${metrics_cert_cn/.*/}.csr;
  set +o pipefail;
  yes yes | openssl ca \
    -config ./${ca_dir}/${metrics_ca_cn}.cfg \
    -extfile ./${cert_dir}/${metrics_cert_cn/.*/}.cfg \
    -out ./${cert_dir}/${metrics_cert_cn/.*/}.crt \
    -infiles ./${cert_dir}/${metrics_cert_cn/.*/}.csr;
  set -o pipefail;
  openssl verify \
    -CAfile ./${ca_dir}/${metrics_ca_cn}.crt \
    ./${cert_dir}/${metrics_cert_cn/.*/}.crt;
  rm -f \
    ./${cert_dir}/${metrics_cert_cn/.*/}.cfg \
    ./${cert_dir}/${metrics_cert_cn/.*/}.csr || \
    { echo "ERROR: Unable to create certificate for ${metrics_cert_cn}" >&2; return 1; }
  mkdir -p ./${manifests_dir};
  mv -f \
    ./${ca_dir}/${metrics_ca_cn}.crt \
    ./${cert_dir}/${metrics_cert_cn/.*/}.crt \
    ./${cert_dir}/${metrics_cert_cn/.*/}.key \
    ${manifests_dir}/.;
  curl -Ls https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml | \
    sed \
      -e '/image:\([[:space:]].*\)k8s.gcr.io\//s/\(^.*\)k8s.gcr.io\/\(.*\$\)/\1'\${METRICS_SERVER_DOCKER_IMAGE_REPO}'\/\2/g' > \
    ./${manifests_dir}/${metrics_deploy_file}
  echo \
"apiVersion: apps/v1
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
        - --secure-port=${metrics_server_port}
        - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
        - --kubelet-certificate-authority=${K8S_PKI_DIR}/ca.crt
        - --tls-cert-file=${K8S_PKI_DIR}/metrics/tls.crt
        - --tls-private-key-file=${K8S_PKI_DIR}/metrics/tls.key
        - --kubelet-use-node-status-port
        - --metric-resolution=15s
        - --v=${debug_level}
        volumeMounts:
        - name: kubernetes-ca
          mountPath: ${K8S_PKI_DIR}/ca.crt
          readOnly: true
        - name: metrics-secrets
          mountPath: ${K8S_PKI_DIR}/metrics
          readOnly: true
        - name: tmp-dir
          mountPath: /tmp
      volumes:
      - name: kubernetes-ca
        hostPath:
          type: File
          path: ${K8S_PKI_DIR}/ca.crt
      - name: metrics-secrets
        secret:
          secretName: ${metrics_secret}
      - name: tmp-dir
        emptyDir: {}" | \
    tee ./${manifests_dir}/${deploy_patch_file} > /dev/null;
  echo \
"apiVersion: apiregistration.k8s.io/v1
kind: APIService
metadata:
  name: v1beta1.metrics.k8s.io
spec:
  insecureSkipTLSVerify: false
  caBundle: $(base64 --wrap=0 ./${manifests_dir}/${metrics_ca_cn}.crt)" | \
  tee ./${manifests_dir}/${apiservice_patch_file} > /dev/null;
echo \
"namespace: kube-system
secretGenerator:
- name: ${metrics_secret}
  files:
  - tls.crt=${metrics_cert_cn/.*/}.crt
  - tls.key=${metrics_cert_cn/.*/}.key
  type: "kubernetes.io/tls"
resources:
- ${metrics_deploy_file}
patchesStrategicMerge:
- ${deploy_patch_file}
- ${apiservice_patch_file}" | \
    tee ./${manifests_dir}/kustomization.yaml > /dev/null;
  ssh ${SSH_OPTS} ${SUDO_USER}@${CTRL_PLANE} \
    "mkdir -p ~${SUDO_USER}/tmp/$$/${manifests_dir}";
  scp ${SSH_OPTS} \
    ./${manifests_dir}/* \
    ${SUDO_USER}@${CTRL_PLANE}:~${SUDO_USER}/tmp/$$/${manifests_dir}/.;
  ssh ${SSH_OPTS} ${SUDO_USER}@${CTRL_PLANE} " \
    set -euo pipefail;
    cd ~${SUDO_USER}/tmp/$$;
    kubectl kustomize ./${manifests_dir} > /dev/null;
    kubectl apply -k ./${manifests_dir};
    rm -rf ~${SUDO_USER}/tmp/$$;";

  return ${?};
}
