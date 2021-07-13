#!/bin/bash
. "$(dirname "${BASH_SOURCE[0]}")"/k8s-env.sh
function kubeadm_init {
  # NOTE: we put the following file in ${K8S_CONF_DIR}/pki because it is mounted by default in docker container
  local rest_encryption_conf="${K8S_PKI_DIR}/rest-encryption.yml";
  local rest_encryption_secret="$(ssh ${SSH_OPTS} ${SUDO_USER}@${CTRL_PLANE} "set -euo pipefail; head -c 32 /dev/urandom | base64")";
  local sudo_user_id="$(ssh ${SSH_OPTS} ${SUDO_USER}@${CTRL_PLANE} "id -u")";
  local sudo_group_id="$(ssh ${SSH_OPTS} ${SUDO_USER}@${CTRL_PLANE} "id -g")";
  local debug_level="0"; # 0 to 9
  local ciphers_suite;
  case "${TLS_MIN_VERSION}" in
    "VersionTLS12")
      ciphers_suite="${CIPHERS_SUITE_TLS13},${CIPHERS_SUITE_TLS12}";
      ;;
    "VersionTLS13")
      ciphers_suite="${CIPHERS_SUITE_TLS13}";
      ;;
    *)
      echo "ERROR: ${FUNCNAME[0]}: \"${TLS_MIN_VERSION}\" is not a supported TLS level." >&2;
      return 1;
      ;;
  esac
  ssh ${SSH_OPTS} ${SUDO_USER}@${CTRL_PLANE} " \
    set -euo pipefail;
    sudo mkdir -p ${K8S_PKI_DIR};
    echo \
\"apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
    - secrets
    providers:
    - aescbc:
        keys:
        - name: key1
          secret: ${rest_encryption_secret}
    - identity: {}\" | \
      sudo tee ${rest_encryption_conf} > /dev/null;
    sudo chown -R root:root ${K8S_PKI_DIR};
    sudo chmod 600 ${rest_encryption_conf};
    echo \
\"apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
networking:
  serviceSubnet: ${SRV_CIDR}
  podSubnet: ${POD_CIDR}
controlPlaneEndpoint: ${CTRL_PLANE_IP}
imageRepository: ${K8S_DOCKER_IMAGE_REPO}
clusterName: ${CLUSTER_NAME}
# For memo {
featureGates:
  PublicKeysECDSA: true
  IPv6DualStack: true
# }
etcd:
  local:
    extraArgs:
      cipher-suites: '${CIPHERS_SUITE_TLS12}'
apiServer:
  extraArgs:
    tls-min-version: '${TLS_MIN_VERSION}'
    tls-cipher-suites: '${CIPHERS_SUITE_TLS13},${CIPHERS_SUITE_TLS12}'
    insecure-port: '0'
    # Anonymous authorization must be enable to allow kubelet join {
    #anonymous-auth: 'false' # Default: 'true'
    # }
    enable-bootstrap-token-auth: 'true'
    authorization-mode: 'RBAC,Node' # Default: 'AlwaysAllow'
    allow-privileged: 'true'
    enable-admission-plugins: 'NamespaceLifecycle,LimitRanger,ResourceQuota,ServiceAccount,PersistentVolumeLabel,DefaultStorageClass,DefaultTolerationSeconds,NodeRestriction'
    kubelet-preferred-address-types: 'InternalIP,ExternalIP,Hostname'
    runtime-config: 'v1=true,api/all=true'
    advertise-address: '${CTRL_PLANE_IP}'
    requestheader-allowed-names: 'front-proxy-client'
    requestheader-extra-headers-prefix: 'X-Remote-Extra-'
    requestheader-group-headers: 'X-Remote-Group'
    requestheader-username-headers: 'X-Remote-User'
    requestheader-client-ca-file: '${K8S_PKI_DIR}/front-proxy-ca.crt'
    proxy-client-cert-file: '${K8S_PKI_DIR}/front-proxy-client.crt'
    proxy-client-key-file: '${K8S_PKI_DIR}/front-proxy-client.key'
    enable-aggregator-routing: 'true'
    encryption-provider-config: '${rest_encryption_conf}'
controllerManager:
  extraArgs:
    tls-min-version: '${TLS_MIN_VERSION}'
    tls-cipher-suites: '${CIPHERS_SUITE_TLS13},${CIPHERS_SUITE_TLS12}'
    root-ca-file: '${K8S_PKI_DIR}/ca-bundle.crt'
    # For memo {
    cluster-signing-duration: '8760h0m0s'
    # }
scheduler:
  extraArgs:
    tls-min-version: '${TLS_MIN_VERSION}'
    tls-cipher-suites: '${CIPHERS_SUITE_TLS13},${CIPHERS_SUITE_TLS12}'
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
tlsMinVersion: ${TLS_MIN_VERSION}
tlsCipherSuites: [${CIPHERS_SUITE_TLS13},${CIPHERS_SUITE_TLS12}]
readOnlyPort: 0
serverTLSBootstrap: true
# For memo {
authentication:
  anonymous:
    enabled: false
rotateCertificates: true
# }\" | \
      tee /tmp/${CLUSTER_NAME}.cfg > /dev/null;
    sudo kubeadm config images pull \
      --v=${debug_level} \
      --image-repository ${K8S_DOCKER_IMAGE_REPO};
    sudo kubeadm init \
      --v=${debug_level} \
      --config=/tmp/${CLUSTER_NAME}.cfg;
    rm -f /tmp/${CLUSTER_NAME}.cfg;
    mkdir -p ~${SUDO_USER}/.kube;
    sudo cp -f ${K8S_CONF_DIR}/admin.conf ~${SUDO_USER}/.kube/config;
    sudo chown ${sudo_user_id}:${sudo_group_id} ~${SUDO_USER}/.kube/config;";
  return ${?};
}
