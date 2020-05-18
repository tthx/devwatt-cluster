export JAVA_HOME="/opt/jdk";
export JAVA_OPTS="-XX:+UseG1GC";
export ZOOCFGDIR="/var/zookeeper/conf";
export ZOOBINDIR="/opt/zookeeper/bin";
export ZOO_LOG_DIR="/var/zookeeper/log";
export HADOOP_HOME="/opt/hadoop";
export HADOOP_CONF_DIR="/etc/hadoop";
export HBASE_HOME="/opt/hbase";
export HBASE_CONF_DIR="/etc/hbase";
export SPARK_HOME="/opt/spark";
export SPARK_CONF_DIR="/etc/spark";
export TEZ_HOME="/opt/tez";
export TEZ_CONF_DIR="/etc/tez";
export HIVE_HOME="/opt/hive";
export HIVE_CONF_DIR="/etc/hive";
export METASTORE_HOME="/opt/metastore";
export METASTORE_CONF_DIR="/etc/metastore";
export IMPALA_HOME="/opt/impala";
export IMPALA_CONF_DIR="/etc/impala";
export PATH="${IMPALA_HOME}/bin:${METASTORE_HOME}/bin:${HIVE_HOME}/bin:${SPARK_HOME}/bin:${HBASE_HOME}/bin:${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin:${ZOOBINDIR}:${JAVA_HOME}/bin:${PATH}";

export HADOOP_COMMON_LIB_NATIVE_DIR="${HADOOP_HOME}/lib/native";
if [[ -n "${LD_LIBRARY_PATH}" ]];
then
  export LD_LIBRARY_PATH+=":${HADOOP_COMMON_LIB_NATIVE_DIR}";
else
  export LD_LIBRARY_PATH="${HADOOP_COMMON_LIB_NATIVE_DIR}";
fi

alias start-hs='mapred --daemon start historyserver';
alias stop-hs='mapred --daemon stop historyserver';
