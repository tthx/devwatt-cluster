# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Set Hive and Hadoop environment variables here. These variables can be used
# to control the execution of Hive. It should be used by admins to configure
# the Hive installation (so that users do not have to set environment variables
# or set command line parameters to get correct behavior).
#
# The hive service being invoked (CLI etc.) is available via the environment
# variable SERVICE


# Hive Client memory usage can be an issue if a large number of clients
# are running at the same time. The flags below have been useful in 
# reducing memory usage:
#
# if [ "$SERVICE" = "cli" ]; then
#   if [ -z "$DEBUG" ]; then
#     export HADOOP_OPTS="$HADOOP_OPTS -XX:NewRatio=12 -Xms10m -XX:MaxHeapFreeRatio=40 -XX:MinHeapFreeRatio=15 -XX:+UseParNewGC -XX:-UseGCOverheadLimit"
#   else
#     export HADOOP_OPTS="$HADOOP_OPTS -XX:NewRatio=12 -Xms10m -XX:MaxHeapFreeRatio=40 -XX:MinHeapFreeRatio=15 -XX:-UseGCOverheadLimit"
#   fi
# fi

# The heap size of the jvm stared by hive shell script can be controlled via:
#
# export HADOOP_HEAPSIZE=1024
#
# Larger heap size may be required when running queries over large number of files or partitions. 
# By default hive shell scripts use a heap size of 256 (MB).  Larger heap size would also be 
# appropriate for hive server.


# Set HADOOP_HOME to point to a specific hadoop install directory
# HADOOP_HOME=${bin}/../../hadoop

# Hive Configuration Directory can be controlled by:
# export HIVE_CONF_DIR=

# Folder containing extra libraries required for hive compilation/execution can be controlled by:
# export HIVE_AUX_JARS_PATH=

export JAVA_HOME="/opt/jdk1.8.0_251"
export JAVA_OPTS="-XX:+UseG1GC"
export PATH="${JAVA_HOME}/bin:${PATH}"

if [[ -n "${HADOOP_CLASSPATH}" ]];
then
  export HADOOP_CLASSPATH+=":$(find ${TEZ_CONF_DIR}/ ${TEZ_HOME}/ \( -name '*.xml' -o -name '*.jar' ! -name 'slf4j-log4j12-*.jar' ! -name 'jersey-*.jar'  ! -name 'guava-*.jar' ! -name '*guice-*.jar' \)| xargs echo | tr ' ' ':')"
else
  export HADOOP_CLASSPATH="$(find ${TEZ_CONF_DIR}/ ${TEZ_HOME}/ \( -name '*.xml' -o -name '*.jar' ! -name 'slf4j-log4j12-*.jar' ! -name 'jersey-*.jar'  ! -name 'guava-*.jar' ! -name '*guice-*.jar' \)| xargs echo | tr ' ' ':')"
fi