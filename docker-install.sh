#!/bin/sh
sudo apt-get remove docker docker.io containerd runc && \
sudo apt-get update && \
sudo apt-get -y install \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release && \
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && \
sudo apt-get update && \
sudo apt-get -y install docker-ce docker-ce-cli containerd.io && \
sudo usermod -aG docker $USER

sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]
  Environment="HTTP_PROXY=http://devwatt-proxy.si.fr.intraorange:8080"
  Environment="HTTPS_PROXY=http://devwatt-proxy.si.fr.intraorange:8080"
  Environment="NO_PROXY=127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,cattle-system.svc,.svc,.cluster.local,docker-mirror-orange-product-devops,ftgroup,intraorange,francetelecom.fr,orange-labs.fr,tech.orange"
EOF

sudo mkdir /etc/docker
sudo tee /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

mkdir $HOME/.docker
tee $HOME/.docker/config.json <<EOF
{
 "proxies": {
    "default": {
      "httpProxy": "http://devwatt-proxy.si.fr.intraorange:8080",
      "httpsProxy": "http://devwatt-proxy.si.fr.intraorange:8080",
      "noProxy": "127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,cattle-system.svc,.svc,.cluster.local,docker-mirror-orange-product-devops,ftgroup,intraorange,francetelecom.fr,orange-labs.fr,tech.orange"
    }
  }
}
EOF