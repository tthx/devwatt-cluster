FROM ubuntu:18.04

RUN printf "\nhttp_proxy=\"http://devwatt-proxy.si.fr.intraorange:8080\"\n\
https_proxy=\"http://devwatt-proxy.si.fr.intraorange:8080\"\n\
HTTPS_PROXY=\"http://devwatt-proxy.si.fr.intraorange:8080\"\n\
HTTP_PROXY=\"http://devwatt-proxy.si.fr.intraorange:8080\"\n\
no_proxy=\"localhost,127.0.0.1,master,worker-1,worker-2,worker-3,worker-4,127.0.0.0/8,192.168.0.0/16,10.96.0.0/12,10.244.0.0/16,orange-labs.fr,10.171.44.14,dbsp.dw,10.165.0.4,10.165.0.7,k8s.local,10.166.1.8,10.166.1.9,10.166.1.10,10.166.1.11,10.166.1.12,10.166.1.13,10.166.1.15,10.166.1.16,10.166.1.17\"\n\
NO_PROXY=\"localhost,127.0.0.1,master,worker-1,worker-2,worker-3,worker-4,127.0.0.0/8,192.168.0.0/16,10.96.0.0/12,10.244.0.0/16,orange-labs.fr,10.171.44.14,dbsp.dw,10.165.0.4,10.165.0.7,k8s.local,10.166.1.8,10.166.1.9,10.166.1.10,10.166.1.11,10.166.1.12,10.166.1.13,10.166.1.15,10.166.1.16,10.166.1.17\"\n" >> /etc/environment \
&& printf "\nexport http_proxy=\"http://devwatt-proxy.si.fr.intraorange:8080\"\n\
export https_proxy=\"\${http_proxy}\"\n\
export HTTPS_PROXY=\"\${http_proxy}\"\n\
export HTTP_PROXY=\"\${http_proxy}\"\n\
export no_proxy=\"localhost,127.0.0.1,master,worker-1,worker-2,worker-3,worker-4,127.0.0.0/8,192.168.0.0/16,10.96.0.0/12,10.244.0.0/16,orange-labs.fr,10.171.44.14,dbsp.dw,10.165.0.4,10.165.0.7,k8s.local,10.166.1.8,10.166.1.9,10.166.1.10,10.166.1.11,10.166.1.12,10.166.1.13,10.166.1.15,10.166.1.16,10.166.1.17\"\n\
export NO_PROXY=\"\${no_proxy}\"\n" >> /etc/profile

RUN printf "\nexport JAVA_HOME=\"/opt/jdk\"\n\
export JAVA_OPTS=\"-XX:+UseG1GC\"\n\
export M2_HOME=\"/opt/maven\"\n\
export MAVEN_OPTS=\"\${JAVA_OPTS} -Xms256m -Xmx512m\"\n\
export ANT_HOME=\"/opt/ant\"\n\
export PATH=\"\${JAVA_HOME}/bin:\${M2_HOME}/bin:\${ANT_HOME}/bin:\${PATH}\"\n\
export CC=\"gcc\"\n\
export CFLAGS=\"-O2\"\n\
export CXX=\"g++\"\n\
export CXXFLAGS=\"-O2\"\n" >> /etc/profile \
&& tar xf /exchange/jdk-8u251-linux-x64.tar.gz -C /opt \
&& tar xf /exchange/apache-maven-3.6.3-bin.tar.gz -C /opt \
&& tar xf /exchange/apache-ant-1.10.7-bin.tar.bz2 -C /opt \
&& cd /opt \
&& ln -sf jdk1.8.0_251 jdk \
&& ln -sf apache-maven-3.6.3 maven \
&& ln -sf apache-ant-1.10.7 ant \
&& apt-get update \
&& apt-get -y install sudo \
&& adduser --disabled-password --gecos '' impala \
&& echo 'impala ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
&& su - impala

RUN mkdir -p ${HOME}/.m2 \
&& cd ${HOME}/.m2 \
&& printf "<settings>\n\
\t<proxies>\n\
\t\t<proxy>\n\
\t\t\t<id>example-proxy-1</id>\n\
\t\t\t<active>true</active>\n\
\t\t\t<protocol>http</protocol>\n\
\t\t\t<host>devwatt-proxy.si.fr.intraorange</host>\n\
\t\t\t<port>8080</port>\n\
\t\t</proxy>\n\
\t<proxy>\n\
\t\t\t<id>example-proxy-2</id>\n\
\t\t\t<active>true</active>\n\
\t\t\t<protocol>https</protocol>\n\
\t\t\t<host>devwatt-proxy.si.fr.intraorange</host>\n\
\t\t\t<port>8080</port>\n\
\t\t</proxy>\n\
\t</proxies>\n\
</settings>\n" > settings.xml

RUN mkdir -p ${HOME}/src \
&& cd ${HOME}/src \
&& tar xf /exchange/apache-impala-3.4.0.tar.gz \
&& cd apache-impala-3.4.0 \
&& export IMPALA_HOME=`pwd` \
&& export USE_GOLD_LINKER=true \
&& . ${IMPALA_HOME}/bin/bootstrap_system.sh <<< "yes" \
&& export MAX_PYTEST_FAILURES=0 \
&& . ${IMPALA_HOME}/bin/impala-config.sh \
&& export CC="gcc" \
&& export CFLAGS="-O2" \
&& export CXX="g++" \
&& export CXXFLAGS="-O2" \
&& export JAVA_HOME="/opt/jdk" \
&& export JAVA_OPTS="-XX:+UseG1GC" \
&& export M2_HOME="/opt/maven" \
&& export MAVEN_OPTS="${JAVA_OPTS} -Xms256m -Xmx512m" \
&& export ANT_HOME="/opt/ant" \
&& export PATH="${JAVA_HOME}/bin:${M2_HOME}/bin:${ANT_HOME}/bin:${PATH}" \
&& export NUM_CONCURRENT_TESTS=$(nproc) \
&& export MAX_PYTEST_FAILURES=0 \
&& ${IMPALA_HOME}/buildall.sh -notests -release
