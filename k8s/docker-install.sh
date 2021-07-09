#!/bin/bash
. "$(dirname "${BASH_SOURCE[0]}")"/k8s-env.sh
function docker_install {
  local i;
  local release;
  for i in ${CTRL_PLANE} ${WORKERS};
  do
    release="$(ssh ${SSH_OPTS} ${SUDO_USER}@${i} lsb_release -cs)";
    ssh ${SSH_OPTS} ${SUDO_USER}@${i} " \
      set -euo pipefail;
      sudo apt-get remove docker docker.io containerd runc;
      sudo apt-get update;
      sudo apt-get -y install \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release;
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg;
      echo \"deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu ${release} stable\" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null;
      sudo apt-get update;
      sudo apt-get -y install docker-ce docker-ce-cli containerd.io;
      sudo usermod -aG docker ${SUDO_USER};
      sudo mkdir /etc/docker;
      echo \
\"{
  \\\"registry-mirrors\\\": [\\\"https://dockerfactory-playground.tech.orange\\\", \\\"https://dockerfactory-playground-iva.si.francetelecom.fr\\\", \\\"https://dockerfactory.tech.orange\\\", \\\"https://dockerfactory-iva.si.francetelecom.fr\\\"],
  \\\"exec-opts\\\": [\\\"native.cgroupdriver=systemd\\\"],
  \\\"log-driver\\\": \\\"json-file\\\",
  \\\"log-opts\\\": {
    \\\"max-size\\\": \\\"100m\\\"
  },
  \\\"storage-driver\\\": \\\"overlay2\\\"
}\" | \
        sudo tee /etc/docker/daemon.json > /dev/null;
      sudo mkdir -p /etc/systemd/system/docker.service.d;
      echo \
\"[Service]
Environment=\\\"HTTP_PROXY=http://devwatt-proxy.si.fr.intraorange:8080\\\"
Environment=\\\"HTTPS_PROXY=http://devwatt-proxy.si.fr.intraorange:8080\\\"
Environment=\\\"NO_PROXY=127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,master,worker-1,worker-2,worker-3,worker-4,cattle-system.svc,.svc,.cluster.local,docker-mirror-orange-product-devops,ftgroup,intraorange,francetelecom.fr,orange-labs.fr,tech.orange\\\"\" | \
        sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf > /dev/null;
      echo \
\"[Service]
MountFlags=shared\" | \
        sudo tee /etc/systemd/system/docker.service.d/mount-propagation.conf > /dev/null;
      sudo systemctl stop docker;
      sudo systemctl stop docker.socket;
      sudo systemctl start docker.socket;
      sudo systemctl start docker;
      mkdir ~${SUDO_USER}/.docker;
      echo \
\"{
  \\\"proxies\\\": {
    \\\"default\\\": {
      \\\"httpProxy\\\": \\\"http://devwatt-proxy.si.fr.intraorange:8080\\\",
      \\\"httpsProxy\\\": \\\"http://devwatt-proxy.si.fr.intraorange:8080\\\",
      \\\"noProxy\\\": \\\"127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,master,worker-1,worker-2,worker-3,worker-4,cattle-system.svc,.svc,.cluster.local,docker-mirror-orange-product-devops,ftgroup,intraorange,francetelecom.fr,orange-labs.fr,tech.orange\\\"
    }
  }
}\" | \
        tee ~${SUDO_USER}/.docker/config.json > /dev/null";
  done
  return ${?};
}
