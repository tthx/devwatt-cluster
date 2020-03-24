# yarn-ui compilation
sudo -i
npm install -g bower
npm install -g ember-cli

abdmob/x2js -> x2js
./hadoop-yarn-project/hadoop-yarn/hadoop-yarn-ui/src/main/webapp/bower.json ./hadoop-yarn-project/hadoop-yarn/hadoop-yarn-ui/src/main/webapp/ember-cli-build.js

sudo addgroup hadoop
sudo adduser ubuntu hadoop
sudo useradd zookeeper --create-home --groups hadoop --shell /bin/bash
echo 'zookeeper:D@$#H0le99*'|sudo chpasswd
sudo useradd hive --create-home --groups hadoop --shell /bin/bash
echo 'hive:D@$#H0le99*'|sudo chpasswd
sudo useradd hbase --create-home --groups hadoop --shell /bin/bash
echo 'hbase:D@$#H0le99*'|sudo chpasswd
sudo useradd hdfs --create-home --groups hadoop --shell /bin/bash
echo 'hdfs:D@$#H0le99*'|sudo chpasswd
sudo useradd yarn --create-home --groups hadoop --shell /bin/bash
echo 'yarn:D@$#H0le99*'|sudo chpasswd
sudo useradd mapred --create-home --groups hadoop --shell /bin/bash
echo 'mapred:D@$#H0le99*'|sudo chpasswd
sudo useradd attu7372 --create-home --groups hadoop --shell /bin/bash
echo 'attu7372:D@$#H0le99*'|sudo chpasswd
sudo mkdir -p /mnt/hdfs
sudo chmod 755 /mnt/hdfs

cd /opt;sudo chown -R root:root ./hadoop* ./apache-hive* ./tez* ./hbase* ./spark*
cd /opt;sudo chmod -R g-w,o-w ./hadoop* ./apache-hive* ./tez* ./hbase* ./spark*

sudo mkdir -p /var/hdfs/namesecondary /var/hdfs/data /data/hdfs /var/hdfs/edit-1 /var/hdfs/edit-2 /var/hdfs/log /var/hdfs/name-1 /var/hdfs/name-2 /var/hdfs/run /var/yarn/local /var/yarn/log /var/yarn/run /var/mapred/log /var/mapred/run /var/zookeeper/conf /var/zookeeper/log /var/zookeeper/data /var/hbase/log /var/hbase/run /var/spark/log /var/spark/run /var/hive/run /var/hive/log /var/hive/run /var/hive/tmp /var/metastore/run /var/metastore/log /etc/hadoop /etc/hbase /etc/hive /etc/metastore /etc/tez /etc/spark
sudo chown -R hdfs:hadoop /var/hdfs /data/hdfs
sudo chown -R yarn:hadoop /var/yarn
sudo chown -R mapred:hadoop /var/mapred
sudo chown -R zookeeper:hadoop /var/zookeeper
sudo chown -R hbase:hadoop /var/hbase
sudo chown -R hive:hadoop /var/hive /var/metastore
sudo chmod 775 /var/hive/tmp
sudo chown -R root:root /etc/hadoop /etc/hbase /opt
sudo chmod -R g-w,o-w /etc/hadoop /etc/hbase /opt
sudo cp /etc/hadoop/container-executor.cfg /opt/hadoop/etc/hadoop/.; sudo chmod 644 /opt/hadoop/etc/hadoop/container-executor.cfg; sudo chown root:hadoop /opt/hadoop/bin/container-executor; sudo chmod 6050 /opt/hadoop/bin/container-executor
# For Hive 3.1.2
sudo cp /etc/hadoop/container-executor.cfg /opt/hadoop-3.1.2/etc/hadoop/.; sudo chmod 644 /opt/hadoop-3.1.2/etc/hadoop/container-executor.cfg; sudo chown root:hadoop /opt/hadoop-3.1.2/bin/container-executor; sudo chmod 6050 /opt/hadoop-3.1.2/bin/container-executor
#sudo ln -s /usr/share/java/postgresql-jdbc4.jar /opt/hive/lib/.; sudo ln -s /usr/share/java/postgresql-jdbc4.jar /opt/metastore/lib/.; sudo cp ~/src/devwatt-cluster/bin/utils.sh ~/src/devwatt-cluster/bin/metastore_ctl ${METASTORE_HOME}/bin/.; sudo cp ~/src/devwatt-cluster/bin/utils.sh ~/src/devwatt-cluster/bin/hiveserver2_ctl ${HIVE_HOME}/bin/.
sudo ln -s /usr/share/java/mysql-connector-java-8.0.19.jar /opt/hive/lib/.; sudo ln -s /usr/share/java/mysql-connector-java-8.0.19.jar /opt/metastore/lib/.; sudo cp ~/src/devwatt-cluster/bin/utils.sh ~/src/devwatt-cluster/bin/metastore_ctl ${METASTORE_HOME}/bin/.; sudo cp ~/src/devwatt-cluster/bin/utils.sh ~/src/devwatt-cluster/bin/hiveserver2_ctl ${HIVE_HOME}/bin/.

hdfs:
rm -rf /var/hdfs/namesecondary/* /var/hdfs/data/* /data/hdfs/* /mnt/hdfs/* /var/hdfs/edit-1/* /var/hdfs/edit-2/* /var/hdfs/log/* /var/hdfs/name-1/* /var/hdfs/name-2/* /var/yarn/local/*

${ZOOBINDIR}/zkCli.sh
deleteall /hbase /hive

hdfs namenode -format tthx

hdfs dfs -mkdir -p /home/ubuntu /home/yarn/log /home/mapred/mr-history/tmp /home/mapred/mr-history/done /home/hive/warehouse /home/attu7372 /home/hbase/coprocessor /tmp/hive
hdfs dfs -chown -R ubuntu /home/ubuntu
hdfs dfs -chown -R yarn /home/yarn
hdfs dfs -chown -R mapred /home/mapred
hdfs dfs -chmod -R 1777 /home/mapred/mr-history
hdfs dfs -chmod 1770 /home/mapred/mr-history/done
hdfs dfs -chown -R hive /home/hive /tmp/hive
hdfs dfs -chown -R attu7372 /home/attu7372
hdfs dfs -chown -R hbase /home/hbase
hdfs dfs -chmod -R 1777 /home/yarn/log /home/hive/warehouse /tmp

hdfs dfs -mkdir -p /home/hbase/coprocessor/
hdfs dfs -rm -f /home/hbase/coprocessor/hadoop-yarn-server-timelineservice.jar
hdfs dfs -put ${HADOOP_HOME}/share/hadoop/yarn/timelineservice/hadoop-yarn-server-timelineservice-hbase-coprocessor-*.jar /home/hbase/coprocessor/hadoop-yarn-server-timelineservice.jar
hdfs dfs -chown hbase /home/hbase/coprocessor/hadoop-yarn-server-timelineservice.jar
hdfs dfs -chmod -R g+r,o+r /home/hbase/coprocessor/

yarn:
hadoop org.apache.hadoop.yarn.server.timelineservice.storage.TimelineSchemaCreator -create

hdfs dfs -mkdir -p /home/yarn/tez
hdfs dfs -rm -f /home/yarn/tez/tez-*.tar.gz
hdfs dfs -put /tmp/tez-0.9.2.tar.gz /home/yarn/tez/.
hdfs dfs -chown -R yarn /home/yarn/tez
hdfs dfs -chmod -R g+r,o+r /home/yarn/tez

hdfs dfs -mkdir -p /home/yarn/spark
hdfs dfs -rm -f /home/yarn/spark/*
hdfs dfs -put ${SPARK_HOME}/jars/* /home/yarn/spark/.
hdfs dfs -chown -R yarn /home/yarn/spark
hdfs dfs -chmod -R g+r,o+r /home/yarn/spark

hdfs dfs -mkdir -p /home/hive/lib /home/hive/install
hdfs dfs -rm -f /home/hive/lib/hive-exec-*.jar
hdfs dfs -put ${HIVE_HOME}/lib/hive-exec-*.jar /home/hive/lib
hdfs dfs -chown -R hive /home/hive/lib /home/hive/install
hdfs dfs -chmod -R 1777 /home/hive/lib /home/hive/install
