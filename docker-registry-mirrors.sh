#!/bin/bash
sudo tee /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": ["https://dockerfactory-playground.tech.orange", "https://dockerfactory-playground-iva.si.francetelecom.fr", "https://dockerfactory.tech.orange", "https://dockerfactory-iva.si.francetelecom.fr"],
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]
  Environment=HTTP_PROXY=http://devwatt-proxy.si.fr.intraorange:8080
  Environment=HTTPS_PROXY=http://devwatt-proxy.si.fr.intraorange:8080
  Environment=NO_PROXY=127.0.0.0/8,10.0.0.0/8,172.0.0.0/8,192.168.0.0/16,master,worker-1,worker-2,worker-3,worker-4,cattle-system.svc,.svc,.cluster.local,docker-mirror-orange-product-devops,ftgroup,intraorange,francetelecom.fr,orange-labs.fr,tech.orange
EOF
tee $HOME/.docker/config.json <<EOF
{
 "proxies": {
    "default": {
      "httpProxy": "http://devwatt-proxy.si.fr.intraorange:8080",
      "httpsProxy": "http://devwatt-proxy.si.fr.intraorange:8080",
      "noProxy": "127.0.0.0/8,10.*,172.*,192.168.*,master,worker-1,worker-2,worker-3,worker-4,cattle-system.svc,.svc,.cluster.local,docker-mirror-orange-product-devops,ftgroup,intraorange,francetelecom.fr,orange-labs.fr,tech.orange"
    }
  }
}
EOF
sudo systemctl daemon-reload && \
sudo systemctl restart docker && \
journalctl -u docker.service --since today
