#!/bin/bash
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
sudo mkdir -p /var/hdfs/namesecondary /var/hdfs/data /var/hdfs/edit-1 /var/hdfs/edit-2 /var/hdfs/log /var/hdfs/name-1 /var/hdfs/name-2 /var/hdfs/run /var/yarn/local /var/yarn/log /var/yarn/run /var/mapred/log /var/mapred/run /var/zookeeper/conf /var/zookeeper/log /var/zookeeper/data /var/hbase/log /var/hbase/run /etc/hbase /var/spark/log /var/spark/run /etc/hive /var/hive/run /var/hive/log /var/hive/run /var/hive/tmp /etc/metastore /var/metastore/run /var/metastore/log /etc/tez
sudo chown -R hdfs:hadoop /var/hdfs /data/hdfs
sudo chown -R yarn:hadoop /var/yarn
sudo chown -R mapred:hadoop /var/mapred
sudo chown -R zookeeper:hadoop /var/zookeeper
sudo chown -R hbase:hadoop /var/hbase
sudo chown -R hive:hadoop /var/hive /var/metastore
sudo chmod 775 /var/hive/tmp
sudo chown -R root:root /etc/hadoop /etc/hbase /opt
sudo chmod -R g-w,o-w /etc/hadoop /etc/hbase /opt
sudo cp /etc/hadoop/container-executor.cfg /opt/hadoop/etc/hadoop/.
sudo chmod 644 /opt/hadoop/etc/hadoop/container-executor.cfg
sudo chown root:hadoop /opt/hadoop/bin/container-executor
sudo chmod 6050 /opt/hadoop/bin/container-executor
# For Hive 3.1.2
sudo cp /etc/hadoop/container-executor.cfg /opt/hadoop-3.2.0/etc/hadoop/.
sudo chmod 644 /opt/hadoop-3.2.0/etc/hadoop/container-executor.cfg
sudo chown root:hadoop /opt/hadoop-3.2.0/bin/container-executor
sudo chmod 6050 /opt/hadoop-3.2.0/bin/container-executor
sudo ln -s /usr/share/java/postgresql-jdbc4.jar /opt/hive/lib/.
sudo ln -s /usr/share/java/postgresql-jdbc4.jar /opt/metastore/lib/.

hdfs dfs -mkdir -p /home/ubuntu /home/yarn/log /home/mapred /home/hive/warehouse /home/hive/scratch /home/attu7372 /home/hbase/coprocessor /tmp
hdfs dfs -chown -R ubuntu /home/ubuntu
hdfs dfs -chown -R yarn /home/yarn
hdfs dfs -chown -R mapred /home/mapred
hdfs dfs -chown -R hive /home/hive
hdfs dfs -chown -R attu7372 /home/attu7372
hdfs dfs -chown -R hbase /home/hbase
hdfs dfs -chmod 1777 /home/yarn/log /home/hive/warehouse /home/hive/scratch /tmp
hdfs dfs -put /opt/hadoop/share/hadoop/yarn/timelineservice/hadoop-yarn-server-timelineservice-hbase-coprocessor-3.2.1.jar /home/hbase/coprocessor/hadoop-yarn-server-timelineservice.jar

hdfs dfs -mkdir -p /home/yarn/tez
hdfs dfs -put ~ubuntu/src/tez-0.9.2.tar.gz /home/yarn/tez/.
hdfs dfs -chown -R yarn /home/yarn/tez
hdfs dfs -chmod -R g+r,o+r /home/yarn/tez

hdfs dfs -mkdir -p /home/yarn/spark
hdfs dfs -put /opt/spark/jars/* /home/yarn/yarn/.
hdfs dfs -chown -R yarn /home/yarn/yarn
hdfs dfs -chmod -R g+r,o+r /home/yarn/yarn
