FROM ubuntu:18.04

RUN apt-get update \
&& apt-get -y install sudo git \
&& adduser --disabled-password --gecos '' impala \
&& echo 'impala ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
&& su - impala

RUN mkdir -p ${HOME}/src \
&& cd ${HOME}/src \
&& git clone https://github.com/apache/impala.git \
&& export IMPALA_HOME="${HOME}/src/impala" \
&& cd ${IMPALA_HOME} \
&& git checkout 3.4.0 \
&& printf 'export CC="gcc"
export CFLAGS="-O2"
export CXX="g++"
export CXXFLAGS="-O2"
export JAVA_OPTS="-XX:+UseG1GC"
export MAVEN_OPTS="${JAVA_OPTS} -Xms256m -Xmx512m"
export IMPALA_HOME="${HOME}/src/impala"\n' >> ${HOME}/.bashrc \
&& printf 'export CC="gcc"
export CFLAGS="-O2"
export CXX="g++"
export CXXFLAGS="-O2"
export JAVA_OPTS="-XX:+UseG1GC"
export MAVEN_OPTS="${JAVA_OPTS} -Xms256m -Xmx512m"
export NUM_CONCURRENT_TESTS=$(nproc)
export MAX_PYTEST_FAILURES=0
export USE_GOLD_LINKER=true
export IMPALA_HOME="${HOME}/src/impala"\n' >> ${IMPALA_HOME}/bin/impala-config-local.sh \
&& export CC="gcc" \
&& export CFLAGS="-O2" \
&& export CXX="g++" \
&& export CXXFLAGS="-O2" \
&& export JAVA_OPTS="-XX:+UseG1GC" \
&& export MAVEN_OPTS="${JAVA_OPTS} -Xms256m -Xmx512m" \
&& export NUM_CONCURRENT_TESTS=$(nproc) \
&& export MAX_PYTEST_FAILURES=0 \
&& export USE_GOLD_LINKER=true \
&& . ${IMPALA_HOME}/bin/bootstrap_system.sh <<< "yes" \
&& . ${IMPALA_HOME}/bin/impala-config.sh \
&& ${IMPALA_HOME}/buildall.sh -notests -release

export IMPALA_HOME="${HOME}/src/impala" \
cd ${IMPALA_HOME}/be/build/release/service \
&& cp ${IMPALA_HOME}/toolchain/kudu-*/release/lib/libkudu_client.so.0.1.0 . \
&& strip -s ./impalad ./libfesupport.so ./libkudu_client.so.0.1.0 \
&& ln -sf libkudu_client.so.0.1.0 libkudu_client.so.0 \
&& cp ${IMPALA_HOME}/fe/target/impala-frontend-0.1-SNAPSHOT.jar ${IMPALA_HOME}/fe/target/dependency/. \
&& cd ${IMPALA_HOME} \
&& tar cjf /exchange/apache-impala-3.4.0-bin.tar.bz2 \
./be/build/release/service/* \
./fe/target/dependency/* \
./shell/build/impala-shell-3.4.0-RELEASE.tar.gz
