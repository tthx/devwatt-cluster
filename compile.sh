#!/bin/bash
x="${1:-"hadoop"}";
shift 1;
action="${@:-"clean package"}";
hadoop_version="3.2.1";
case "${x}" in
  "testdfsio")
    unset CXXFLAGS;
    export JAVA_HOME="/opt/jdk1.8.0_221";
    export JAVA_OPTS="-XX:+UseG1GC";
    export MAVEN_OPTS="${JAVA_OPTS} -Xms256m -Xmx512m";
    export PATH="${JAVA_HOME}/bin:${PATH}";
    export HADOOP_COMMON_LIB_NATIVE_DIR="${HADOOP_HOME}/lib/native";
    if [[ -n "${LD_LIBRARY_PATH}" ]];
    then
      export LD_LIBRARY_PATH+=":${HADOOP_COMMON_LIB_NATIVE_DIR}";
    else
      export LD_LIBRARY_PATH="${HADOOP_COMMON_LIB_NATIVE_DIR}";
    fi
    mvn ${action} -DskipTests
    ;;
  "hadoop")
    unset CXXFLAGS;
    export JAVA_HOME="/opt/jdk1.8.0_221";
    export JAVA_OPTS="-XX:+UseG1GC";
    export MAVEN_OPTS="${JAVA_OPTS} -Xms256m -Xmx512m";
    export PATH="${JAVA_HOME}/bin:${PATH}";
    mvn ${action} -Pdist,native -DskipTests -Dtar -Dmaven.javadoc.skip=true -Pyarn-ui -Drequire.openssl -Drequire.zstd -Drequire.snappy -Drequire.isal -Disal.prefix=/opt/isa-l -Disal.lib=/opt/isa-l/lib -Dbundle.isal -Dhbase.profile=2.0;
    ;;
  "hbase")
    unset CXXFLAGS;
    export JAVA_HOME="/opt/jdk1.8.0_221";
    export JAVA_OPTS="-XX:+UseG1GC";
    export MAVEN_OPTS="${JAVA_OPTS} -Xms256m -Xmx512m";
    export PATH="${JAVA_HOME}/bin:${PATH}";
    mvn ${action} assembly:single -DskipTests -Dhadoop.profile=3.0 -Dhadoop-three.version=${hadoop_version};
    ;;
  "spark")
    unset CXXFLAGS;
    export JAVA_HOME="/opt/jdk1.8.0_221";
    export JAVA_OPTS="-XX:+UseG1GC";
    export MAVEN_OPTS="${JAVA_OPTS} -Xms2g -Xmx2g";
    export PATH="${JAVA_HOME}/bin:${PATH}";
    ./dev/make-distribution.sh --name spark-2.4.4-bin-without-hadoop-scala-2.12 --tgz --r --pip -T 1C -Dmaven.javadoc.skip=true -DskipTests -Pscala-2.12 -Dscala.version=2.12.10 -Psparkr -Phadoop-2.7 -Dhadoop.version=${hadoop_version} -Phive -Phive-thriftserver -Pmesos -Pyarn -Pkubernetes
    ;;
esac
