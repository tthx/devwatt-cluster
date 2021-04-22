#!/bin/bash
echo \
"{
  \"registry-mirrors\": [\"https://dockerfactory-playground.tech.orange\", \"https://dockerfactory-playground-iva.si.francetelecom.fr\", \"https://dockerfactory.tech.orange\", \"https://dockerfactory-iva.si.francetelecom.fr\"]
}
" > /tmp/toto && \
sudo cp /tmp/toto /etc/docker/daemon.json && \
echo \
"[Service]
                Environment=\"HTTP_PROXY=http://172.17.0.1:3128\"
                Environment=\"HTTPS_PROXY=http://172.17.0.1:3128\"
                Environment=\"NO_PROXY=localhost,127.0.0.1,172,17.0.1,docker-mirror-orange-product-devops,ftgroup,intraorange,francetelecom.fr,orange-labs.fr,tech.orange\"
" > /tmp/toto && \
sudo cp /tmp/toto /etc/systemd/system/docker.service.d/http-proxy.conf && \
echo \
"{
  \"proxies\": {
    \"default\": {
      \"httpProxy\": \"http://172.17.0.1:3128\",
      \"httpsProxy\": \"http://172.17.0.1:3128\",
      \"noProxy\": \"127.0.0.1,localhost,172.17.*,10.*,*.intraorange,*.ftgroup,*.francetelecom.fr,*.orange-labs.fr,*.tech.orange\"
    }
  }
}
" > $HOME/.docker/config.json && \
sudo systemctl daemon-reload && \
sudo systemctl restart docker && \
rm /tmp/toto && \
journalctl -u docker.service --since today