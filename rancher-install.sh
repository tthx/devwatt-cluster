#!/bin/sh
docker run -d --restart=unless-stopped \
  -p 80:80 -p 443:443 \
  -e HTTP_PROXY="http://devwatt-proxy.si.fr.intraorange:8080" \
  -e HTTPS_PROXY="http://devwatt-proxy.si.fr.intraorange:8080" \
  -e NO_PROXY="127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,master,worker-1,worker-2,worker-3,worker-4,cattle-system.svc,.svc,.cluster.local,docker-mirror-orange-product-devops,ftgroup,intraorange,francetelecom.fr,orange-labs.fr,tech.orange" \
  --privileged \
  rancher/rancher:latest