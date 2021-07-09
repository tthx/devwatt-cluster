#!/bin/bash
set -euo pipefail;
SUDO_USER="${SUDO_USER:-"ubuntu"}";
SSH_OPTS="${SSH_OPTS:-""}";
CTRL_PLANE="${CTRL_PLANE:-"master"}";
WORKERS="${WORKERS:-"worker-1 worker-2 worker-3 worker-4"}";
CLUSTER_NAME="${CLUSTER_NAME:-"ghost-0"}";
K8S_DOCKER_IMAGE_REPO="${K8S_DOCKER_IMAGE_REPO:-"k8s.gcr.io"}";
CALICO_DOCKER_IMAGE_REPO="${CALICO_DOCKER_IMAGE_REPO:-"dockerfactory-playground.tech.orange"}";
METRICS_SERVER_DOCKER_IMAGE_REPO="${CALICO_DOCKER_IMAGE_REPO:-"dockerfactory-playground.tech.orange"}";
NET_INTERFACE="${NET_INTERFACE:-"ens3"}";
K8S_CONF_DIR="${K8S_CONF_DIR:-"/etc/kubernetes"}";
K8S_PKI_DIR="${K8S_PKI_DIR:-"${K8S_CONF_DIR}/pki"}";
POD_CIDR="${POD_CIDR:-"172.18.0.0/16"}";
SRV_CIDR="${SRV_CIDR:-"172.19.0.0/16"}";
TLS_MIN_VERSION="${TLS_MIN_VERSION:-"VersionTLS12"}";
CIPHERS_SUITE_TLS12="${CIPHERS_SUITE_TLS12:-"TLS_AES_128_GCM_SHA256,TLS_AES_256_GCM_SHA384,TLS_CHACHA20_POLY1305_SHA256,TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"}";#,TLS_DHE_RSA_WITH_AES_128_GCM_SHA256,TLS_DHE_RSA_WITH_AES_256_GCM_SHA384"}"; Recommanded by Mozilla but are unavailable in Kubernetes
CIPHERS_SUITE_TLS13="${CIPHERS_SUITE_TLS13:-"TLS_AES_128_GCM_SHA256,TLS_AES_256_GCM_SHA384,TLS_CHACHA20_POLY1305_SHA256"}";
GEN_CERTS="${GEN_CERTS:-"yes"}";
KEY_TYPE="${KEY_TYPE:-"ecdsa"}";
ECDSA_CA_KEY_CURVE="${ECDSA_CA_KEY_CURVE:-"secp384r1"}";
ECDSA_KEY_CURVE="${ECDSA_KEY_CURVE:-"prime256v1"}";
RSA_CA_KEY_LENGTH="${RSA_CA_KEY_LENGTH:-"4096"}";
RSA_KEY_LENGTH="${RSA_KEY_LENGTH:-"2048"}";
CERT_DURATION="${CERT_DURATION:-"365"}";
CA_CERT_DURATION_FACTOR="${CA_CERT_DURATION_FACTOR:-"1000"}";
CTRL_PLANE_HOSTNAME="${CTRL_PLANE_HOSTNAME:-"$(ssh ${SSH_OPTS} ${SUDO_USER}@${CTRL_PLANE} hostname)"}";
CTRL_PLANE_IP="${CTRL_PLANE_IP:-"$(ssh ${SSH_OPTS} ${SUDO_USER}@${CTRL_PLANE} "set -euo pipefail; ip -f inet -4 address show dev ${NET_INTERFACE} | awk '/inet/{ split(\$2,x,\"/\"); print x[1]; }'")"}";

function get_ca_keyparams {
  local result="";
  case "${KEY_TYPE}" in
    "ECDSA"|"ecdsa")
      result="ec -pkeyopt ec_paramgen_curve:${ECDSA_CA_KEY_CURVE}";
      ;;
    "RSA"|"rsa")
      result="rsa:${RSA_CA_KEY_LENGTH}";
      ;;
    *)
      echo "ERROR: ${FUNCNAME[0]}: \"${KEY_TYPE}\" is not a supported key type." >&2;
      return 1;
      ;;
  esac
  printf "%s" "${result}";
  return 0;
}

function get_keyparams {
  local result="";
  case "${KEY_TYPE}" in
    "ECDSA"|"ecdsa")
      result="ec -pkeyopt ec_paramgen_curve:${ECDSA_KEY_CURVE}";
      ;;
    "RSA"|"rsa")
      result="rsa:${RSA_KEY_LENGTH}";
      ;;
    *)
      echo "ERROR: ${FUNCNAME[0]}: \"${KEY_TYPE}\" is not a supported key type." >&2;
      return 1;
      ;;
  esac
  printf "%s" "${result}";
  return 0;
}
