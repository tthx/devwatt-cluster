export IMPALA_LOG_DIR=/var/impala/log

IMPALA_COMMON_ARGS="--disable_kudu \
  --enable_minidumps=false \
  -log_dir=${IMPALA_LOG_DIR}"

export IMPALA_CATALOG_SERVICE_HOST=master
export IMPALA_CATALOG_ARGS="${IMPALA_COMMON_ARGS}"

export IMPALA_STATE_STORE_HOST=master
export IMPALA_STATE_STORE_PORT=24000
export IMPALA_STATE_STORE_ARGS="${IMPALA_COMMON_ARGS} \
  -state_store_port=${IMPALA_STATE_STORE_PORT}"

export IMPALA_BACKEND_PORT=22000
export IMPALA_SERVER_ARGS="${IMPALA_COMMON_ARGS} \
  -catalog_service_host=${IMPALA_CATALOG_SERVICE_HOST} \
  -state_store_port=${IMPALA_STATE_STORE_PORT} \
  -use_statestore \
  -state_store_host=${IMPALA_STATE_STORE_HOST} \
  -be_port=${IMPALA_BACKEND_PORT}"

export ENABLE_CORE_DUMPS=false

export JAVA_HOME=/opt/jdk1.8.0_251
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
