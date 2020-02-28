#!/bin/bash
x="${1:-"hadoop"}";
shift 1;
action="${*:-"clean package"}";
unset CXXFLAGS;
export JAVA_HOME="/opt/jdk1.8.0_241";
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
    mvn ${action} -Pdist,native  -Pyarn-ui -DskipTests -Dtar -Dmaven.javadoc.skip=true -Drequire.openssl -Drequire.zstd -Drequire.snappy -Drequire.isal -Disal.prefix=/opt/isa-l -Disal.lib=/opt/isa-l/lib -Dbundle.isal -Dhbase.profile=2.0; # -Pyarn-ui
    ;;
  hbase)
    hadoop_version="3.2.1";
    mvn ${action} assembly:single -Dmaven.javadoc.skip=true -DskipTests -Dhadoop.profile=3.0 -Dhadoop-three.version=${hadoop_version};
    ;;
  tez)
    hadoop_version="3.1.2";
    mvn clean package -Dhadoop.version=${hadoop_version} -Phadoop28 -P\!hadoop27  -DskipTests -Dmaven.javadoc.skip=true;
    ;;
  hive)
    export MAVEN_OPTS="${JAVA_OPTS} -Xms2g -Xmx2g";
    hadoop_version="3.1.2";
    mvn ${action} -DskipTests -Pdist -Dmaven.javadoc.skip=true -Dhadoop.version=${hadoop_version};
    ;;
  spark)
    export MAVEN_OPTS="${JAVA_OPTS} -Xms2g -Xmx2g";
    export SPARK_DIST_CLASSPATH="$(hadoop classpath)";
    scala_major_version="2.12";
    scala_minor_version="10";
    hadoop_version="3.2.1";
    spark_version="2.4.5";
    hdfs dfs -mkdir -p /home/${USER}/src/spark-${spark_version}/examples/src/main/resources;
    hdfs dfs -put examples/src/main/resources/* /home/${USER}/src/spark-${spark_version}/examples/src/main/resources/.;
    ./dev/change-scala-version.sh "${scala_major_version}";
    ./dev/make-distribution.sh --name without-hadoop-scala-2.12 --tgz --pip --r -T 1C -Psparkr -Dmaven.javadoc.skip=true -DskipTests -Pscala-2.12 -Dscala.version="${scala_major_version}"."${scala_minor_version}" -Phadoop-3.1 -Dhadoop.version=${hadoop_version} -Pyarn -Phive -Phive-thriftserver -Pmesos -Pkubernetes -Phadoop-provided; #-Phive-provided -Porc-provided -Pparquet-provided;
    ;;
esac
