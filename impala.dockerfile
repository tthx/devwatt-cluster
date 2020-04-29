FROM ubuntu:20.04

RUN printf "http_proxy=\"http://devwatt-proxy.si.fr.intraorange:8080\"\n\
https_proxy=\"http://devwatt-proxy.si.fr.intraorange:8080\"\n\
HTTPS_PROXY=\"http://devwatt-proxy.si.fr.intraorange:8080\"\n\
HTTP_PROXY=\"http://devwatt-proxy.si.fr.intraorange:8080\"\n\
no_proxy=\"localhost,127.0.0.1,master,worker-1,worker-2,worker-3,worker-4,127.0.0.0/8,192.168.0.0/16,10.96.0.0/12,10.244.0.0/16,orange-labs.fr,10.171.44.14,dbsp.dw,10.165.0.4,10.165.0.7,k8s.local,10.166.1.8,10.166.1.9,10.166.1.10,10.166.1.11,10.166.1.12,10.166.1.13,10.166.1.15,10.166.1.16,10.166.1.17\"\n\
NO_PROXY=\"localhost,127.0.0.1,master,worker-1,worker-2,worker-3,worker-4,127.0.0.0/8,192.168.0.0/16,10.96.0.0/12,10.244.0.0/16,orange-labs.fr,10.171.44.14,dbsp.dw,10.165.0.4,10.165.0.7,k8s.local,10.166.1.8,10.166.1.9,10.166.1.10,10.166.1.11,10.166.1.12,10.166.1.13,10.166.1.15,10.166.1.16,10.166.1.17\"\n" >> /etc/environment

RUN apt-get update \
&& apt-get -y install build-essential libpython2-dev python-is-python2 libssl-dev libsasl2-dev libkrb5-dev vim sudo \
&& tar xf /exchange/jdk-8u251-linux-x64.tar.gz -C /opt \
&& tar xf /exchange/apache-maven-3.6.3-bin.tar.gz -C /opt \
&& cd /opt \
&& ln -sf jdk1.8.0_251 jdk \
&& ln -sf apache-maven-3.6.3 maven \
&& adduser --disabled-password --gecos '' impala \
&& echo 'impala ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
&& su - impala

RUN mkdir src \
&& cd src \
&& tar xf /exchange/apache-impala-3.4.0.tar.gz \
&& cd apache-impala-3.4.0 \
&& export CC="gcc" \
&& export CFLAGS="-O2" \
&& export CXX="g++" \
&& export CXXFLAGS="-O2" \"
&& export JAVA_HOME="/opt/jdk" \
&& export JAVA_OPTS="-XX:+UseG1GC" \
&& export M2_HOME="/opt/maven" \
&& export MAVEN_OPTS="${JAVA_OPTS} -Xms256m -Xmx512m" \
&& epxort PATH="${JAVA_HOME}/bin:${M2_HOME}/bin" \
&& export IMPALA_HOME=`pwd` \
&& $IMPALA_HOME/buildall.sh -notests -release
