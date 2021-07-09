#!/bin/bash
. "$(dirname "${BASH_SOURCE[0]}")"/k8s-env.sh
function kubeadm_gen_certs {
  local duration;
  local ghost_ca="${CLUSTER_NAME/-*/}-ca";
  local etcd_ca="etcd-ca";
  # from kubeadm init command:
  local k8s_ca="kubernetes";
  local k8s_front_proxy_ca="front-proxy-ca";
  # from https://kubernetes.io/docs/setup/best-practices/certificates/:
  local k8s_ca="kubernetes-ca";
  local k8s_front_proxy_ca="kubernetes-front-proxy-ca";
  local ca_dir="${ghost_ca}/ca";
  local cert_dir="${ghost_ca}/cert";
  local kube_etcd="kube-etcd";
  local kube_etcd_peer="kube-etcd-peer";
  local kube_etcd_healthcheck_client="kube-etcd-healthcheck-client";
  local kube_apiserver_etcd_client="kube-apiserver-etcd-client";
  local kube_apiserver="kube-apiserver";
  local kube_apiserver_kubelet_client="kube-apiserver-kubelet-client";
  local front_proxy_client="front-proxy-client";
  local first_srv_ip="172.19.0.1"; # We assume that service CIDR is 172.19.0.1/16
  local workers="";
  local renew="";
  local install="";
  local i;
  while [[ ${#} -gt 0 ]]
  do
    case "${1}" in
      w|workers)
        workers="x";
        shift 1;
        ;;
      r|renew)
        renew="x";
        shift 1;
        ;;
      i|install)
        install="x";
        shift 1;
        ;;
      *)
        if [[ -n "${1}" ]];
        then
          echo "ERROR: ${FUNCNAME[0]}: Option \"${1}\" is unknown" >&2;
          echo "Usage: ${FUNCNAME[0]} [r|renew] [i|install]" >&2;
          return 1;
        fi
        shift 1;
        ;;
    esac
  done

  if [[ -n "${renew}" ]];
  then
    if [[ -f ./${ca_dir}/${ghost_ca}-bundle.crt ]];
    then
      mv -f \
        ./${ca_dir}/${ghost_ca}-bundle.crt \
        ./${ghost_ca}-bundle-previous.crt || \
        { echo "ERROR: ${FUNCNAME[0]}: Unable to move file ./${ca_dir}/${ghost_ca}-bundle.crt to ./${ghost_ca}-bundle-previous.crt" >&2; return 1; }
    else
      echo "ERROR: ${FUNCNAME[0]}: File ./${ca_dir}/${ghost_ca}-bundle.crt does not exist" >&2;
      return 1;
    fi
  fi

  rm -rf ./${ca_dir} ./${cert_dir};
  mkdir -p ./${ca_dir} ./${cert_dir};

  # Generate CA configurations
  for i in \
    ${ghost_ca} \
    ${etcd_ca} \
    ${k8s_ca} \
    ${k8s_front_proxy_ca};
  do
    duration=${CERT_DURATION};
    if [[ "${i}" == "${ghost_ca}" ]];
    then
      duration=$((CERT_DURATION*CA_CERT_DURATION_FACTOR));
    fi
    touch ./${ca_dir}/${i}.txt;
    echo "01" > ./${ca_dir}/${i}.srl;
    echo \
  "[ca]
  default_ca=my_ca
  [my_ca]
  serial=./${ca_dir}/${i}.srl
  database=./${ca_dir}/${i}.txt
  new_certs_dir=./${cert_dir}
  certificate=./${ca_dir}/${i}.crt
  private_key=./${ca_dir}/${i}.key
  default_md=sha256
  default_days=${duration}
  policy=my_policy
  [my_policy]
  countryName=optional
  stateOrProvinceName=optional
  organizationName=optional
  commonName=supplied
  organizationalUnitName=optional" | \
      tee ./${ca_dir}/${i}.cfg > /dev/null
  done

  # Generate root CA
  openssl req \
    -x509 -new -sha256 -nodes \
    -newkey $(get_ca_keyparams) \
    -keyout ./${ca_dir}/${ghost_ca}.key \
    -subj "/CN=${ghost_ca}" \
    -addext "keyUsage=critical,digitalSignature,keyEncipherment,keyCertSign" \
    -addext "subjectAltName=DNS:${ghost_ca}" \
    -days $((CERT_DURATION*CA_CERT_DURATION_FACTOR)) \
    -out ./${ca_dir}/${ghost_ca}.crt;

  # Generate k8s, etcd and k8s front proxy CA
  if [[ ${?} -eq 0 ]];
  then
    for i in ${etcd_ca} ${k8s_ca} ${k8s_front_proxy_ca};
    do
      openssl req \
        -new -sha256 -nodes \
        -newkey $(get_ca_keyparams) \
        -keyout ./${cert_dir}/${i}.key \
        -subj "/CN=${i}" \
        -out ./${cert_dir}/${i}.csr;
      set +o pipefail;
      yes yes | openssl ca \
        -config ./${ca_dir}/${ghost_ca}.cfg \
        -extfile <(echo \
"subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer
basicConstraints=critical,CA:TRUE
keyUsage=critical,digitalSignature,keyEncipherment,keyCertSign
subjectAltName=DNS:${i}") \
        -out ./${cert_dir}/${i}.crt \
        -infiles ./${cert_dir}/${i}.csr;
      set -o pipefail;
      openssl verify \
        -CAfile ./${ca_dir}/${ghost_ca}.crt \
        ./${cert_dir}/${i}.crt;
      mv -f \
        ./${cert_dir}/${i}.key ./${cert_dir}/${i}.crt \
        ./${ca_dir}/.;
      rm -f ./${cert_dir}/${i}.csr || \
        { echo "ERROR: ${FUNCNAME[0]}: Unable to create certificate for ${i}" >&2; return 1; }
    done
  fi

  cat ./${ca_dir}/${ghost_ca}.crt \
    ./${ca_dir}/${etcd_ca}.crt \
    ./${ca_dir}/${k8s_ca}.crt \
    ./${ca_dir}/${k8s_front_proxy_ca}.crt > \
    ./${ca_dir}/${ghost_ca}-bundle.crt;
  openssl verify \
    -CAfile ./${ca_dir}/${ghost_ca}.crt \
    ./${ca_dir}/${ghost_ca}-bundle.crt || \
      { echo "ERROR: ${FUNCNAME[0]}: Unable to create CA bundle" >&2; return 1; }

  # Certificates signed by etcd CA
  echo \
"subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth,clientAuth
subjectAltName=DNS:${CTRL_PLANE_HOSTNAME},DNS:localhost,IP:${CTRL_PLANE_IP},IP:127.0.0.1,IP:0:0:0:0:0:0:0:1" | \
    tee ./${cert_dir}/${kube_etcd}.cfg > /dev/null;
  echo \
"subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth,clientAuth
subjectAltName=DNS:${CTRL_PLANE_HOSTNAME},DNS:localhost,IP:${CTRL_PLANE_IP},IP:127.0.0.1,IP:0:0:0:0:0:0:0:1" | \
    tee ./${cert_dir}/${kube_etcd_peer}.cfg > /dev/null;
  echo \
"subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=clientAuth" | \
    tee ./${cert_dir}/${kube_etcd_healthcheck_client}.cfg > /dev/null;
  echo \
"subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=clientAuth" | \
    tee ./${cert_dir}/${kube_apiserver_etcd_client}.cfg > /dev/null;

  for i in \
    ${kube_etcd} \
    ${kube_etcd_peer} \
    ${kube_etcd_healthcheck_client} \
    ${kube_apiserver_etcd_client};
  do
    openssl req \
      -new -sha256 -nodes \
      -newkey $(get_keyparams) \
      -keyout ./${cert_dir}/${i}.key \
      -subj "/CN=${i}$(echo ${i} | awk '/kube-apiserver-etcd-client|kube-etcd-healthcheck-client/{print "/O=system:masters"}')" \
      -out ./${cert_dir}/${i}.csr;
    set +o pipefail;
    yes yes | openssl ca \
      -config ./${ca_dir}/${etcd_ca}.cfg \
      -extfile ./${cert_dir}/${i}.cfg \
      -out ./${cert_dir}/${i}.crt \
      -infiles ./${cert_dir}/${i}.csr;
    set -o pipefail;
    openssl verify \
      -CAfile ./${ca_dir}/${ghost_ca}-bundle.crt \
      ./${cert_dir}/${i}.crt;
    rm -f \
      ./${cert_dir}/${i}.cfg \
      ./${cert_dir}/${i}.csr || \
      { echo "ERROR: ${FUNCNAME[0]}: Unable to create certificate for ${i}" >&2; return 1; }
  done

  # Certificates signed by kubernetes CA
  # For control plane components
  echo \
"subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:${CTRL_PLANE_HOSTNAME},IP:${CTRL_PLANE_IP},IP:${first_srv_ip},DNS:kubernetes,DNS:kubernetes.default,DNS:kubernetes.default.svc,DNS:kubernetes.default.svc.cluster,DNS:kubernetes.default.svc.cluster.local" | \
    tee ./${cert_dir}/${kube_apiserver}.cfg > /dev/null;
  echo \
"subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=clientAuth" | \
    tee ./${cert_dir}/${kube_apiserver_kubelet_client}.cfg > /dev/null;

  for i in \
    ${kube_apiserver} \
    ${kube_apiserver_kubelet_client};
  do
    rm -f \
      ./${cert_dir}/${i}.key \
      ./${cert_dir}/${i}.csr \
      ./${cert_dir}/${i}.crt;
    openssl req \
      -new -sha256 -nodes \
      -newkey $(get_keyparams) \
      -keyout ./${cert_dir}/${i}.key \
      -subj "/CN=${i}$(echo ${i} | awk '/kube-apiserver-kubelet-client/{print "/O=system:masters"}')" \
      -out ./${cert_dir}/${i}.csr;
    set +o pipefail;
    yes yes | openssl ca \
      -config ./${ca_dir}/${k8s_ca}.cfg \
      -extfile ./${cert_dir}/${i}.cfg \
      -out ./${cert_dir}/${i}.crt \
      -infiles ./${cert_dir}/${i}.csr;
    set -o pipefail;
    openssl verify \
      -CAfile ./${ca_dir}/${ghost_ca}-bundle.crt \
      ./${cert_dir}/${i}.crt;
    rm -f \
      ./${cert_dir}/${i}.cfg \
      ./${cert_dir}/${i}.csr || \
      { echo "ERROR: ${FUNCNAME[0]}: Unable to create certificate for ${i}" >&2; return 1; }
  done

  # For workers
  if [[ -n "${workers}" ]];
  then
    echo \
"subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=clientAuth" | \
      tee ./${cert_dir}/worker.cfg > /dev/null;

    for i in ${CTRL_PLANE} ${WORKERS}
    do
      rm -f \
        ./${cert_dir}/${i}.key \
        ./${cert_dir}/${i}.csr \
        ./${cert_dir}/${i}.crt;
      openssl req \
        -new -sha256 -nodes \
        -newkey $(get_keyparams) \
        -keyout ./${cert_dir}/${i}.key \
        -subj "/CN=system:node:"$(ssh ${SSH_OPTS} ${SUDO_USER}@${i} hostname)"/O=system:nodes" \
        -out ./${cert_dir}/${i}.csr;
      set +o pipefail;
      yes yes | openssl ca \
        -config ./${ca_dir}/${k8s_ca}.cfg \
        -extfile ./${cert_dir}/worker.cfg \
        -out ./${cert_dir}/${i}.crt \
        -infiles ./${cert_dir}/${i}.csr;
      set -o pipefail;
      openssl verify \
        -CAfile ./${ca_dir}/${ghost_ca}-bundle.crt \
        ./${cert_dir}/${i}.crt;
      if [[ -n "${install}" ]];
      then
        ssh ${SSH_OPTS} ${SUDO_USER}@${i} \
          "mkdir -p ~${SUDO_USER}/tmp/$$";
        scp ${SSH_OPTS} \
          ./${ca_dir}/${k8s_ca}.crt \
          ./${cert_dir}/${i}.crt \
          ./${cert_dir}/${i}.key \
          ${SUDO_USER}@${i}:~${SUDO_USER}/tmp/$$/.;
        ssh ${SSH_OPTS} ${SUDO_USER}@${i} " \
          set -euo pipefail;
          sudo mkdir -p ${K8S_PKI_DIR};
          cd ~${SUDO_USER}/tmp/$$;
          sudo cp -f ./${i}.crt ${K8S_PKI_DIR}/kubelet.crt;
          sudo cp -f ./${i}.key ${K8S_PKI_DIR}/kubelet.key;
          sudo chown -R root:root ${K8S_PKI_DIR};
          sudo chmod 600 ${K8S_PKI_DIR}/*.key;
          sudo chmod 644 ${K8S_PKI_DIR}/*.crt;
          rm -rf ~${SUDO_USER}/tmp/$$";
        echo "${FUNCNAME[0]}: Generated certificates for worker [${i}] are copied in ${K8S_PKI_DIR}";
      fi
      rm -f \
        ./${cert_dir}/${i}.csr || \
        { echo "ERROR: ${FUNCNAME[0]}: Unable to create certificate for ${i}" >&2; return 1; }
    done
    rm -f ./${cert_dir}/worker.cfg;
  fi

  # Certificates signed by front proxy CA
  echo \
"subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=clientAuth" | \
    tee ./${cert_dir}/${front_proxy_client}.cfg > /dev/null;

  for i in \
    ${front_proxy_client};
  do
    rm -f \
      ./${cert_dir}/${i}.key \
      ./${cert_dir}/${i}.csr \
      ./${cert_dir}/${i}.crt;
    openssl req \
      -new -sha256 -nodes \
      -newkey $(get_keyparams) \
      -keyout ./${cert_dir}/${i}.key \
      -subj "/CN=${i}" \
      -out ./${cert_dir}/${i}.csr;
    set +o pipefail;
    yes yes | openssl ca \
      -config ./${ca_dir}/${k8s_front_proxy_ca}.cfg \
      -extfile ./${cert_dir}/${i}.cfg \
      -out ./${cert_dir}/${i}.crt \
      -infiles ./${cert_dir}/${i}.csr;
    set -o pipefail;
    openssl verify \
      -CAfile ./${ca_dir}/${ghost_ca}-bundle.crt \
      ./${cert_dir}/${i}.crt;
    rm -f \
      ./${cert_dir}/${i}.cfg \
      ./${cert_dir}/${i}.csr || \
      { echo "ERROR: ${FUNCNAME[0]}: Unable to create certificate for ${i}" >&2; return 1; }
  done

  if [[ -n "${renew}" ]];
  then
    cat ./${ghost_ca}-bundle-previous.crt >> \
      ./${ca_dir}/${ghost_ca}-bundle.crt;
    rm -f ./${ghost_ca}-bundle-previous.crt;
    echo "${FUNCNAME[0]}: Old CAs was appended";
  fi

  if [[ -n "${install}" ]];
  then
    ssh ${SSH_OPTS} ${SUDO_USER}@${CTRL_PLANE} \
      "mkdir -p ~${SUDO_USER}/tmp/$$";
    scp ${SSH_OPTS} \
      -r ./${ghost_ca} \
      ${SUDO_USER}@${CTRL_PLANE}:~${SUDO_USER}/tmp/$$/.;
    ssh ${SSH_OPTS} ${SUDO_USER}@${CTRL_PLANE} " \
      set -euo pipefail;
      sudo mkdir -p ${K8S_PKI_DIR}/etcd;
      cd ~${SUDO_USER}/tmp/$$;
      sudo cp -f ./${ca_dir}/${ghost_ca}-bundle.crt ${K8S_PKI_DIR}/ca-bundle.crt;
      sudo cp -f ./${ca_dir}/${etcd_ca}.crt ${K8S_PKI_DIR}/etcd/ca.crt;
      sudo cp -f ./${ca_dir}/${etcd_ca}.key ${K8S_PKI_DIR}/etcd/ca.key;
      sudo cp -f ./${cert_dir}/${kube_etcd}.crt ${K8S_PKI_DIR}/etcd/server.crt;
      sudo cp -f ./${cert_dir}/${kube_etcd}.key ${K8S_PKI_DIR}/etcd/server.key;
      sudo cp -f ./${cert_dir}/${kube_etcd_peer}.crt ${K8S_PKI_DIR}/etcd/peer.crt;
      sudo cp -f ./${cert_dir}/${kube_etcd_peer}.key ${K8S_PKI_DIR}/etcd/peer.key;
      sudo cp -f ./${cert_dir}/${kube_etcd_healthcheck_client}.crt ${K8S_PKI_DIR}/etcd/healthcheck-client.crt;
      sudo cp -f ./${cert_dir}/${kube_etcd_healthcheck_client}.key ${K8S_PKI_DIR}/etcd/healthcheck-client.key;
      sudo cp -f ./${ca_dir}/${k8s_ca}.crt ${K8S_PKI_DIR}/ca.crt;
      sudo cp -f ./${ca_dir}/${k8s_ca}.key ${K8S_PKI_DIR}/ca.key;
      sudo cp -f ./${cert_dir}/${kube_apiserver_etcd_client}.crt ${K8S_PKI_DIR}/apiserver-etcd-client.crt;
      sudo cp -f ./${cert_dir}/${kube_apiserver_etcd_client}.key ${K8S_PKI_DIR}/apiserver-etcd-client.key;
      sudo cp -f ./${cert_dir}/${kube_apiserver}.crt ${K8S_PKI_DIR}/apiserver.crt;
      sudo cp -f ./${cert_dir}/${kube_apiserver}.key ${K8S_PKI_DIR}/apiserver.key;
      sudo cp -f ./${cert_dir}/${kube_apiserver_kubelet_client}.crt ${K8S_PKI_DIR}/apiserver-kubelet-client.crt;
      sudo cp -f ./${cert_dir}/${kube_apiserver_kubelet_client}.key ${K8S_PKI_DIR}/apiserver-kubelet-client.key;
      sudo cp -f ./${ca_dir}/${k8s_front_proxy_ca}.crt ${K8S_PKI_DIR}/front-proxy-ca.crt;
      sudo cp -f ./${ca_dir}/${k8s_front_proxy_ca}.key ${K8S_PKI_DIR}/front-proxy-ca.key;
      sudo cp -f ./${cert_dir}/${front_proxy_client}.crt ${K8S_PKI_DIR}/.;
      sudo cp -f ./${cert_dir}/${front_proxy_client}.key ${K8S_PKI_DIR}/.;
      sudo chown -R root:root ${K8S_PKI_DIR};
      sudo chmod 600 ${K8S_PKI_DIR}/*.key ${K8S_PKI_DIR}/etcd/*.key;
      sudo chmod 644 ${K8S_PKI_DIR}/*.crt ${K8S_PKI_DIR}/etcd/*.crt;
      rm -rf ~${SUDO_USER}/tmp/$$";
    echo "${FUNCNAME[0]}: Generated certificates are copied in ${K8S_PKI_DIR}";
  fi

  echo "${FUNCNAME[0]}: Generated certificates completed.";
  return 0;
}
