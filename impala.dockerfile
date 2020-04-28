FROM ubuntu:18.04
RUN printf "http_proxy=\"http://devwatt-proxy.si.fr.intraorange:8080\"\n\
https_proxy=\"http://devwatt-proxy.si.fr.intraorange:8080\"\n\
HTTPS_PROXY=\"http://devwatt-proxy.si.fr.intraorange:8080\"\n\
HTTP_PROXY=\"http://devwatt-proxy.si.fr.intraorange:8080\"\n\
no_proxy=\"localhost,127.0.0.1,master,worker-1,worker-2,worker-3,worker-4,127.0.0.0/8,192.168.0.0/16,10.96.0.0/12,10.244.0.0/16,orange-labs.fr,10.171.44.14,dbsp.dw,10.165.0.4,10.165.0.7,k8s.local,10.166.1.8,10.166.1.9,10.166.1.10,10.166.1.11,10.166.1.12,10.166.1.13,10.166.1.15,10.166.1.16,10.166.1.17\"\n\
NO_PROXY=\"localhost,127.0.0.1,master,worker-1,worker-2,worker-3,worker-4,127.0.0.0/8,192.168.0.0/16,10.96.0.0/12,10.244.0.0/16,orange-labs.fr,10.171.44.14,dbsp.dw,10.165.0.4,10.165.0.7,k8s.local,10.166.1.8,10.166.1.9,10.166.1.10,10.166.1.11,10.166.1.12,10.166.1.13,10.166.1.15,10.166.1.16,10.166.1.17\"\n" >> /etc/environment \
&& apt-get update \
&& apt-get -y install vim sudo wget \
&& adduser --disabled-password --gecos '' impala \
&& echo 'impala ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
&& su - impala

RUN mkdir src \
&& cd src \
&& wget https://downloads.apache.org/impala/3.4.0/apache-impala-3.4.0.tar.gz \
&& tar xf apache-impala-3.4.0.tar.gz \
&& cd apache-impala-3.4.0 \
&& export IMPALA_HOME=`pwd` \
&& $IMPALA_HOME/bin/bootstrap_development.sh