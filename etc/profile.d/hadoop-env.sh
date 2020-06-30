export JAVA_HOME="/opt/jdk";
export PATH="{JAVA_HOME}/bin:${PATH}"
export JAVA_OPTS="-XX:+UseG1GC";
export ZOOCFGDIR="/var/zookeeper/conf";
export ZOOBINDIR="/opt/zookeeper/bin";
export PATH="{ZOOBINDIR}:${PATH}";
export ZOO_LOG_DIR="/var/zookeeper/log";
export HADOOP_HOME="/opt/hadoop";
export PATH="${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin:${PATH}";
export HADOOP_CONF_DIR="/etc/hadoop";
export HBASE_HOME="/opt/hbase";
export PATH="{HBASE_HOME}/bin:${PATH}";
export HBASE_CONF_DIR="/etc/hbase";
export SPARK_HOME="/opt/spark";
export PATH="{SPARK_HOME}/bin:${PATH}";
export SPARK_CONF_DIR="/etc/spark";
export TEZ_HOME="/opt/tez";
export TEZ_CONF_DIR="/etc/tez";
export HIVE_HOME="/opt/hive";
export PATH="{HIVE_HOME}/bin:${PATH}";
export HIVE_CONF_DIR="/etc/hive";
export METASTORE_HOME="/opt/metastore";
export PATH="{METASTORE_HOME}/bin:${PATH}";
export METASTORE_CONF_DIR="/etc/metastore";
export IMPALA_HOME="/opt/impala";
export PATH="{IMPALA_HOME}/bin:${PATH}";
export IMPALA_CONF_DIR="/etc/impala";

export HADOOP_COMMON_LIB_NATIVE_DIR="${HADOOP_HOME}/lib/native";
if [[ -n "${LD_LIBRARY_PATH+x}" ]];
then
  export LD_LIBRARY_PATH+=":${HADOOP_COMMON_LIB_NATIVE_DIR}";
else
  export LD_LIBRARY_PATH="${HADOOP_COMMON_LIB_NATIVE_DIR}";
fi

alias start-hs='mapred --daemon start historyserver';
alias stop-hs='mapred --daemon stop historyserver';
