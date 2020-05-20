FROM ubuntu:18.04

RUN printf 'http_proxy="http://devwatt-proxy.si.fr.intraorange:8080"
https_proxy="http://devwatt-proxy.si.fr.intraorange:8080"
HTTPS_PROXY="http://devwatt-proxy.si.fr.intraorange:8080"
HTTP_PROXY="http://devwatt-proxy.si.fr.intraorange:8080"
no_proxy="localhost,127.0.0.1,master,worker-1,worker-2,worker-3,worker-4,127.0.0.0/8,192.168.0.0/16,10.96.0.0/12,10.244.0.0/16,orange-labs.fr,10.171.44.14,dbsp.dw,10.165.0.4,10.165.0.7,k8s.local,10.166.1.8,10.166.1.9,10.166.1.10,10.166.1.11,10.166.1.12,10.166.1.13,10.166.1.15,10.166.1.16,10.166.1.17"
NO_PROXY="localhost,127.0.0.1,master,worker-1,worker-2,worker-3,worker-4,127.0.0.0/8,192.168.0.0/16,10.96.0.0/12,10.244.0.0/16,orange-labs.fr,10.171.44.14,dbsp.dw,10.165.0.4,10.165.0.7,k8s.local,10.166.1.8,10.166.1.9,10.166.1.10,10.166.1.11,10.166.1.12,10.166.1.13,10.166.1.15,10.166.1.16,10.166.1.17"\n' >> /etc/environment \
&& printf 'export http_proxy="http://devwatt-proxy.si.fr.intraorange:8080"
export https_proxy="${http_proxy}"
export HTTPS_PROXY="${http_proxy}"
export HTTP_PROXY="${http_proxy}"
export no_proxy="localhost,127.0.0.1,master,worker-1,worker-2,worker-3,worker-4,127.0.0.0/8,192.168.0.0/16,10.96.0.0/12,10.244.0.0/16,orange-labs.fr,10.171.44.14,dbsp.dw,10.165.0.4,10.165.0.7,k8s.local,10.166.1.8,10.166.1.9,10.166.1.10,10.166.1.11,10.166.1.12,10.166.1.13,10.166.1.15,10.166.1.16,10.166.1.17"
export NO_PROXY="${no_proxy}"
export ANT_OPTS="-Dhttp.proxyHost=devwatt-proxy.si.fr.intraorange -Dhttp.proxyPort=8080 -Dhttps.proxyHost=devwatt-proxy.si.fr.intraorange -Dhttps.proxyPort=8080"\n' >> /etc/profile

RUN apt-get update \
&& apt-get -y install ccache g++ gcc libffi-dev liblzo2-dev libkrb5-dev krb5-admin-server krb5-kdc krb5-user libsasl2-dev libsasl2-modules libsasl2-modules-gssapi-mit libssl-dev make ninja-build ntp ntpdate python-dev python-setuptools postgresql ssh wget vim-common psmisc lsof openjdk-8-jdk openjdk-8-source openjdk-8-dbg apt-utils git ant sudo \
&& printf 'export CC="gcc"
export CFLAGS="-O2"
export CXX="g++"
export CXXFLAGS="-O2"
export JAVA_HOME="/opt/jdk"
export JAVA_OPTS="-XX:+UseG1GC"
export M2_HOME="/opt/maven"
export MAVEN_OPTS="${JAVA_OPTS} -Xms256m -Xmx512m"
export ANT_HOME="/opt/ant"
export PATH="${JAVA_HOME}/bin:${M2_HOME}/bin:${ANT_HOME}/bin:${PATH}"\n' >> /etc/profile \
&& tar xf /exchange/jdk-8u251-linux-x64.tar.gz -C /opt \
&& tar xf /exchange/apache-maven-3.6.3-bin.tar.gz -C /opt \
&& tar xf /exchange/apache-ant-1.10.7-bin.tar.bz2 -C /opt \
&& cd /opt \
&& ln -sf jdk1.8.0_251 jdk \
&& ln -sf apache-maven-3.6.3 maven \
&& ln -sf apache-ant-1.10.7 ant \
&& adduser --disabled-password --gecos '' impala \
&& echo 'impala ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
&& su - impala

RUN mkdir -p ${HOME}/.m2 \
&& cd ${HOME}/.m2 \
&& printf '<settings>
  <proxies>
   <proxy>
      <id>example-proxy-1</id>
      <active>true</active>
      <protocol>http</protocol>
      <host>devwatt-proxy.si.fr.intraorange</host>
      <port>8080</port>
    </proxy>
   <proxy>
      <id>example-proxy-2</id>
      <active>true</active>
      <protocol>https</protocol>
      <host>devwatt-proxy.si.fr.intraorange</host>
      <port>8080</port>
    </proxy>
  </proxies>
</settings>\n' > settings.xml \
&& printf 'export http_proxy="http://devwatt-proxy.si.fr.intraorange:8080"
export https_proxy="${http_proxy}"
export HTTPS_PROXY="${http_proxy}"
export HTTP_PROXY="${http_proxy}"
export no_proxy="localhost,127.0.0.1,master,worker-1,worker-2,worker-3,worker-4,127.0.0.0/8,192.168.0.0/16,10.96.0.0/12,10.244.0.0/16,orange-labs.fr,10.171.44.14,dbsp.dw,10.165.0.4,10.165.0.7,k8s.local,10.166.1.8,10.166.1.9,10.166.1.10,10.166.1.11,10.166.1.12,10.166.1.13,10.166.1.15,10.166.1.16,10.166.1.17"
export NO_PROXY="${no_proxy}"
export ANT_OPTS="-Dhttp.proxyHost=devwatt-proxy.si.fr.intraorange -Dhttp.proxyPort=8080 -Dhttps.proxyHost=devwatt-proxy.si.fr.intraorange -Dhttps.proxyPort=8080"\n' >> ${HOME}/.bashrc \
&& export IMPALA_HOME="${HOME}/src/apache-impala-3.4.0" \
&& printf 'export http_proxy="http://devwatt-proxy.si.fr.intraorange:8080"
export https_proxy="${http_proxy}"
export HTTPS_PROXY="${http_proxy}"
export HTTP_PROXY="${http_proxy}"
export ANT_OPTS="-Dhttp.proxyHost=devwatt-proxy.si.fr.intraorange -Dhttp.proxyPort=8080 -Dhttps.proxyHost=devwatt-proxy.si.fr.intraorange -Dhttps.proxyPort=8080"\n' > ${IMPALA_HOME}/bin/impala-config-local.sh \
&& sed -i 's/^pool/#pool/g' /etc/ntp.conf \
&& printf 'listen on 127.0.0.1
server 127.127.1.0
fudge 127.127.1.0 stratum 10\n' >> /etc/ntp.conf \
&& service ntp restart \
&& printf '127.0.0.1 us.pool.ntp.org\n' >> /etc/hosts \
&& export IMPALA_HOME="${HOME}/src/apache-impala-3.4.0" \
&& sed -i 's/^sudo\ ntpdate/#sudo\ ntpdate/g' ${IMPALA_HOME}/bin/bootstrap_system.sh

RUN mkdir -p ${HOME}/src \
&& tar xf /exchange/apache-impala-3.4.0.tar.gz -C ${HOME}/src \
&& export IMPALA_HOME="${HOME}/src/apache-impala-3.4.0" \
&& printf 'export CC="gcc"
export CFLAGS="-O2"
export CXX="g++"
export CXXFLAGS="-O2"
export JAVA_HOME="/opt/jdk"
export JAVA_OPTS="-XX:+UseG1GC"
export M2_HOME="/opt/maven"
export MAVEN_OPTS="${JAVA_OPTS} -Xms256m -Xmx512m"
export ANT_HOME="/opt/ant"
export PATH="${JAVA_HOME}/bin:${M2_HOME}/bin:${ANT_HOME}/bin:${PATH}"
export IMPALA_HOME="${HOME}/src/apache-impala-3.4.0"\n' >> ${HOME}/.bashrc \
&& printf 'export CC="gcc"
export CFLAGS="-O2"
export CXX="g++"
export CXXFLAGS="-O2"
export JAVA_HOME="/opt/jdk"
export JAVA_OPTS="-XX:+UseG1GC"
export M2_HOME="/opt/maven"
export MAVEN_OPTS="${JAVA_OPTS} -Xms256m -Xmx512m"
export ANT_HOME="/opt/ant"
export PATH="${JAVA_HOME}/bin:${M2_HOME}/bin:${ANT_HOME}/bin:${PATH}"
export NUM_CONCURRENT_TESTS=$(nproc)
export MAX_PYTEST_FAILURES=0
export USE_GOLD_LINKER=true
export IMPALA_HOME="${HOME}/src/apache-impala-3.4.0"\n' >> ${IMPALA_HOME}/bin/impala-config-local.sh \
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
&& export USE_GOLD_LINKER=true \
&& cd ${IMPALA_HOME} \
&& . ${IMPALA_HOME}/bin/bootstrap_system.sh <<< "yes" \
&& . ${IMPALA_HOME}/bin/impala-config.sh \
&& ${IMPALA_HOME}/buildall.sh -notests -release

cd ${HOME}/src \
&& tar cjf /exchange/apache-impala-3.4.0-bin.tar.bz2 \
apache-impala-3.4.0/be/build/release/service/* \
apache-impala-3.4.0/fe/target/dependency/* \
apache-impala-3.4.0/toolchain/kudu-4ed0dbbd1/release/lib/libkudu_client.so.0.1.0 \
apache-impala-3.4.0/fe/target/impala-frontend-0.1-SNAPSHOT.jar \
apache-impala-3.4.0/shell/build/impala-shell-3.4.0-RELEASE.tar.gz
