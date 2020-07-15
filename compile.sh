#!/bin/bash
x="${1:-"hadoop"}";
shift 1;
action="${*:-"clean package"}";
hadoop_version="3.1.2";
hbase_version="2.2.5";
javax_el_version="3.0.1-b11";
export CC="gcc";
export CFLAGS="-O2";
export CXX="g++";
export CXXFLAGS="-O2";
export JAVA_HOME="/opt/jdk";
export PATH="${JAVA_HOME}/bin:${PATH}";
export JAVA_OPTS="-XX:+UseG1GC -XX:+ResizeTLAB -XX:+UseNUMA  -XX:-ResizePLAB";
export MAVEN_OPTS="${JAVA_OPTS} -Xms1g -Xmx2g";
export HADOOP_COMMON_LIB_NATIVE_DIR="${HADOOP_HOME}/lib/native";
if [[ -n "${LD_LIBRARY_PATH+x}" ]];
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
    mvn ${action} -Pdist,native -DskipTests -Dtar -Dmaven.javadoc.skip=true -Drequire.openssl -Drequire.zstd -Drequire.snappy -Drequire.isal -Disal.prefix=/opt/isa-l -Disal.lib=/opt/isa-l/lib -Dbundle.isal -Dhbase.profile=2.0 -Dhbase.two.version=${hbase_version}; #-Pyarn-ui;
    if [[ ${?} -eq 0 ]];
    then
      cp ./hadoop-dist/target/hadoop-*.tar.gz ~/src/.;
    fi
    ;;
  hbase)
    mvn ${action} assembly:single -Dmaven.javadoc.skip=true -DskipTests -Dhadoop.profile=3.0 -Dhadoop-three.version=${hadoop_version};
    if [[ ${?} -eq 0 ]];
    then
      cp ./hbase-assembly/target/hbase-*-bin.tar.gz ~/src/.;
    fi
    ;;
  tez)
    mvn clean package -Dhadoop.version=${hadoop_version} -Phadoop28 -P\!hadoop27  -DskipTests -Dmaven.javadoc.skip=true;
    if [[ ${?} -eq 0 ]];
    then
      cp ./tez-dist/target/tez-*.tar.gz ./tez-plugins/tez-aux-services/target/tez-aux-services-*.jar ~/src/.;
      rm ~/src/tez-aux-services-*-tests.jar
    fi
    ;;
  hive)
    export MAVEN_OPTS="${JAVA_OPTS} -Xms2g -Xmx2g";
    mvn ${action} -DskipTests -Pdist -Pprotobuf -Dmaven.javadoc.skip=true -Dhadoop.version=${hadoop_version};
    if [[ ${?} -eq 0 ]];
    then
      cp ./standalone-metastore/target/apache-hive*-metastore-*-bin.tar.gz ~/src/.;
      cp ./packaging/target/apache-hive-*-bin.tar.gz ~/src/.;
    fi
    ;;
  spark)
    export MAVEN_OPTS="${JAVA_OPTS} -Xms2g -Xmx2g";
    export SPARK_DIST_CLASSPATH="$(hadoop classpath)";
    unset SPARK_HOME SPARK_CONF_DIR SPARK_DIST_CLASSPATH
    scala_major_version="2.12";
    scala_minor_version="10";
    spark_version="2.4.5";
    hdfs dfs -rm -r -f /home/${USER}/src/spark-${spark_version};
    hdfs dfs -mkdir -p /home/${USER}/src/spark-${spark_version}/examples/src/main/resources;
    hdfs dfs -put examples/src/main/resources/* /home/${USER}/src/spark-${spark_version}/examples/src/main/resources/.;
    ./dev/change-scala-version.sh "${scala_major_version}";
    ./dev/make-distribution.sh --name without-hadoop-scala-${scala_major_version} --tgz --pip --r -T 1C -Psparkr -Dmaven.javadoc.skip=true -DskipTests -Pscala-${scala_major_version} -Dscala.version="${scala_major_version}"."${scala_minor_version}" -Phadoop-3.1 -Dhadoop.version=${hadoop_version} -Pyarn -Phive -Phive-thriftserver -Pmesos -Pkubernetes -Phadoop-provided; #-Phive-provided -Porc-provided -Pparquet-provided;
    ;;
esac
