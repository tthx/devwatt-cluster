#!/bin/bash
x="${1:-"hadoop"}";
shift 1;
action="${*:-"clean package"}";
hadoop_version="3.2.1";
unset CXXFLAGS;
export JAVA_HOME="/opt/jdk1.8.0_231";
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
case "${x}" in
  testdfsio)
    mvn ${action} -DskipTests
    ;;
  hadoop)
    mvn ${action} -Pdist,native -DskipTests -Dtar -Dmaven.javadoc.skip=true -Pyarn-ui -Drequire.openssl -Drequire.zstd -Drequire.snappy -Drequire.isal -Disal.prefix=/opt/isa-l -Disal.lib=/opt/isa-l/lib -Dbundle.isal -Dhbase.profile=2.0;
    ;;
  hbase)
    mvn ${action} assembly:single -Dmaven.javadoc.skip=true -DskipTests -Dhadoop.profile=3.0 -Dhadoop-three.version=${hadoop_version};
    ;;
  hive)
    export MAVEN_OPTS="${JAVA_OPTS} -Xms2g -Xmx2g";
    mvn ${action} -DskipTests -Pdist -Dmaven.javadoc.skip=true -Dhadoop.version=${hadoop_version};
    ;;
  spark)
    export MAVEN_OPTS="${JAVA_OPTS} -Xms2g -Xmx2g";
    export SPARK_DIST_CLASSPATH="$(hadoop classpath)";
    hdfs dfs -mkdir -p /home/ubuntu/src/spark-2.4.4/examples/src/main/resources;
    hdfs dfs -put examples/src/main/resources/* /home/ubuntu/src/spark-2.4.4/examples/src/main/resources/.;
    ./dev/change-scala-version.sh 2.12;
    ./dev/make-distribution.sh --name without-hadoop-scala-2.12 --tgz --pip --r -T 1C -Psparkr -Dmaven.javadoc.skip=true -DskipTests -Pscala-2.12 -Dscala.version=2.12.10 -Phadoop-3.1 -Dhadoop.version=${hadoop_version} -Pyarn -Phive -Phive-thriftserver -Pmesos -Pkubernetes -Phadoop-provided; #-Phive-provided -Porc-provided -Pparquet-provided;
    ;;
esac
