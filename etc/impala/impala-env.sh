# Log level
# GLOG_v=1 - The default level. Logs information about each connection and query that is initiated to an impalad instance, including runtime profiles.
# GLOG_v=2 - Everything from the previous level plus information for each RPC initiated. This level also records query execution progress information, including details on each file that is read.
# GLOG_v=3 - Everything from the previous level plus logging of every row that is read. This level is only applicable for the most serious troubleshooting and tuning scenarios, because it can produce exceptionally large and detailed log files, potentially leading to its own set of performance and capacity problems.
export GLOG_v=1

export IMPALA_LOG_DIR=/var/impala/log
export IMPALA_CATALOG_SERVICE_HOST=master
export IMPALA_CATALOG_SERVICE_PORT=26000
export IMPALA_STATE_STORE_HOST=master
export IMPALA_STATE_STORE_PORT=24000
export IMPALA_BACKEND_PORT=22000

IMPALA_COMMON_ARGS="--disable_kudu \
  --enable_minidumps=false \
  --log_dir=${IMPALA_LOG_DIR} \
  --catalog_service_host=${IMPALA_CATALOG_SERVICE_HOST} \
  --catalog_service_port=${IMPALA_CATALOG_SERVICE_PORT} \
  --state_store_host=${IMPALA_STATE_STORE_HOST} \
  --state_store_port=${IMPALA_STATE_STORE_PORT}"

export IMPALA_CATALOG_ARGS="${IMPALA_COMMON_ARGS}"

export IMPALA_STATE_STORE_ARGS="${IMPALA_COMMON_ARGS}"

export IMPALA_SERVER_ARGS="${IMPALA_COMMON_ARGS} \
  --be_port=${IMPALA_BACKEND_PORT}"

export IMPALA_COORDINATOR_ARGS="${IMPALA_SERVER_ARGS} \
  ‑‑is_executor=false"

export IMPALA_EXECUTOR_ARGS="${IMPALA_SERVER_ARGS} \
  ‑‑is_coordinator=false"

export ENABLE_CORE_DUMPS=false

export JAVA_HOME=/opt/jdk
export LIBHDFS_OPTS=-Djava.library.path=/opt/hadoop/lib/native
export POSTGRESQL_CONNECTOR_JAR=/usr/share/java/postgresql.jar
export IMPALA_BIN=/opt/impala/be/build/release/service
export IMPALA_HOME=/opt/impala
export IMPALA_SHELL_HOME="${IMPALA_HOME}/shell/build/impala-shell-3.4.0-RELEASE"
export HADOOP_HOME=/opt/hadoop
export HIVE_HOME=/opt/hive
export HBASE_HOME=/opt/hbase
export IMPALA_CONF_DIR=/etc/impala
export HADOOP_CONF_DIR=/etc/hadoop
export HIVE_CONF_DIR=/etc/hive
export HBASE_CONF_DIR=/etc/hbase

if [[ -n "${LD_LIBRARY_PATH+x}" ]];
then
  export LD_LIBRARY_PATH+=":/usr/lib/x86_64-linux-gnu/"
else
  export LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu/"
fi

. ${HADOOP_CONF_DIR}/hadoop-env.sh

for library in libjvm.so libjsig.so libjava.so; do
    library_file=`find ${JAVA_HOME}/ -name $library | head -1`
    if [ -n "$library_file" ] ; then
        library_dir=`dirname $library_file`
        export LD_LIBRARY_PATH=$library_dir:${LD_LIBRARY_PATH}
    fi
done
export LD_LIBRARY_PATH="${IMPALA_BIN}:${LD_LIBRARY_PATH}"

if [[ -n "${CLASSPATH+x}" ]];
then
  export CLASSPATH+="${IMPALA_CONF_DIR}:${HADOOP_CONF_DIR}:${HIVE_CONF_DIR}:${HBASE_CONF_DIR}:${POSTGRESQL_CONNECTOR_JAR}:$(find ${IMPALA_HOME}/fe/target/dependency/ -name '*.jar' | xargs echo | tr ' ' ':')"
else
  export CLASSPATH="${IMPALA_CONF_DIR}:${HADOOP_CONF_DIR}:${HIVE_CONF_DIR}:${HBASE_CONF_DIR}:${POSTGRESQL_CONNECTOR_JAR}:$(find ${IMPALA_HOME}/fe/target/dependency/ -name '*.jar' | xargs echo | tr ' ' ':')"
fi
