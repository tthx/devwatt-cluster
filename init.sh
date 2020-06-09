# yarn-ui compilation
sudo -i
npm install -g bower
npm install -g ember-cli

abdmob/x2js -> x2js
./hadoop-yarn-project/hadoop-yarn/hadoop-yarn-ui/src/main/webapp/bower.json ./hadoop-yarn-project/hadoop-yarn/hadoop-yarn-ui/src/main/webapp/ember-cli-build.js

sudo addgroup hadoop \
&& sudo useradd zookeeper --create-home --groups hadoop --shell /bin/bash \
&& echo 'zookeeper:azerty'|sudo chpasswd \
&& sudo useradd hive --create-home --groups hadoop --shell /bin/bash \
&& echo 'hive:azerty'|sudo chpasswd \
&& sudo useradd hbase --create-home --groups hadoop --shell /bin/bash \
&& echo 'hbase:azerty'|sudo chpasswd \
&& sudo useradd hdfs --create-home --groups hadoop --shell /bin/bash \
&& echo 'hdfs:azerty'|sudo chpasswd \
&& sudo useradd yarn --create-home --groups hadoop --shell /bin/bash \
&& echo 'yarn:azerty'|sudo chpasswd \
&& sudo useradd mapred --create-home --groups hadoop --shell /bin/bash \
&& echo 'mapred:azerty'|sudo chpasswd \
&& sudo useradd impala --create-home --groups hadoop --shell /bin/bash \
&& echo 'impala:azerty'|sudo chpasswd \
&& sudo useradd attu7372 --create-home --groups hadoop --shell /bin/bash \
&& echo 'attu7372:azerty'|sudo chpasswd \
&& sudo useradd spark --create-home --groups hadoop --shell /bin/bash \
&& echo 'spark:azerty'|sudo chpasswd \
&& echo 'ubuntu:azerty'|sudo chpasswd \
&& sudo adduser ubuntu hadoop

users="ubuntu attu7372 hdfs yarn mapred hive hbase zookeeper spark impala"
rm /tmp/authorized_keys-$(hostname)
touch /tmp/authorized_keys-$(hostname)
chmod 777 /tmp/authorized_keys-$(hostname)
for x in ${users};
do
  sudo -u ${x} ssh-keygen -t rsa -b 4096 -q -N '' -f /home/${x}/.ssh/id_rsa <<< y \
  && sudo -u ${x} cat /home/${x}/.ssh/id_rsa.pub >> /tmp/authorized_keys-$(hostname)
done
users="ubuntu attu7372 hdfs yarn mapred hive hbase zookeeper spark impala"
for x in ${users};
do
  sudo -u ${x} cp /tmp/authorized_keys /home/${x}/.ssh/. \
  && sudo -u ${x} chmod 600 /home/${x}/.ssh/authorized_keys
done
rm /tmp/authorized_keys-$(hostname)

sudo mkdir -p /var/hdfs/namesecondary /var/hdfs/data /data/hdfs /var/hdfs/edit-1 /var/hdfs/edit-2 /var/hdfs/log /var/hdfs/name-1 /var/hdfs/name-2 /var/hdfs/run /var/yarn/local /var/yarn/log /var/yarn/run /var/mapred/log /var/mapred/run /var/zookeeper/conf /var/zookeeper/log /var/zookeeper/data /var/hbase/log /var/hbase/run /var/spark/log /var/spark/run /var/hive/run /var/hive/log /var/hive/run /var/hive/tmp /var/metastore/run /var/metastore/log /etc/hadoop /etc/hbase /etc/hive /etc/metastore /etc/tez /etc/spark /etc/impala /var/impala/log /var/impala/run /var/impala/tmp \
&& sudo chown -R hdfs:hadoop /var/hdfs /data/hdfs \
&& sudo chown -R yarn:hadoop /var/yarn \
&& sudo chown -R mapred:hadoop /var/mapred \
&& sudo chown -R zookeeper:hadoop /var/zookeeper \
&& sudo chown -R hbase:hadoop /var/hbase \
&& sudo chown -R hive:hadoop /var/hive /var/metastore \
&& sudo chown -R impala:hadoop /var/impala \
&& sudo chown -R spark:hadoop /var/spark \
&& sudo chmod 775 /var/hive/tmp \
&& sudo mkdir -p /mnt/hdfs \
&& sudo chmod 755 /mnt/hdfs

cd /opt \
&& sudo rm -rf ./apache-hive* ./hbase* ./apache-impala* ./impala-shell* ./hadoop* ./tez* \
&& cd /tmp \
&& hive_version="3.1.3" \
&& impala_hive_version="2.1.2-SNAPSHOT" \
&& hbase_version="2.2.6-SNAPSHOT" \
&& impala_version="3.4.0" \
&& hadoop_version="3.1.2" \
&& tez_version="0.9.2" \
&& sudo tar xf apache-hive-${hive_version}-bin.tar.gz -C /opt \
&& sudo tar xf apache-hive-metastore-${hive_version}-bin.tar.gz -C /opt \
&& sudo tar xf apache-hive-${impala_hive_version}-bin.tar.gz -C /opt \
&& sudo tar xf hbase-${hbase_version}-bin.tar.gz -C /opt \
&& sudo mkdir -p /opt/apache-impala-${impala_version}-bin \
&& sudo tar xf apache-impala-${impala_version}-bin.tar.bz2 -C /opt/apache-impala-${impala_version}-bin \
&& sudo tar xf hadoop-${hadoop_version}.tar.gz -C /opt \
&& sudo mkdir -p /opt/tez-${tez_version} \
&& sudo tar xf tez-${tez_version}.tar.gz -C /opt/tez-${tez_version} \
&& sudo cp tez-aux-services-${tez_version}.jar /opt/tez-${tez_version}/. \
&& sudo tar xf /opt/apache-impala-${impala_version}-bin/shell/build/impala-shell-${impala_version}-RELEASE.tar.gz -C /opt \
&& cd /opt \
&& sudo rm -f hive metastore hbase hbase impala impala-hive impala-shell hadoop tez \
&& sudo ln -sf apache-hive-${hive_version}-bin hive \
&& sudo ln -sf apache-hive-metastore-${hive_version}-bin metastore \
&& sudo ln -sf apache-hive-${impala_hive_version}-bin impala-hive \
&& sudo ln -sf hbase-${hbase_version} hbase \
&& sudo ln -sf apache-impala-${impala_version}-bin impala \
&& sudo ln -sf impala-shell-${impala_version}-RELEASE impala-shell \
&& sudo ln -sf hadoop-${hadoop_version} hadoop \
&& sudo ln -sf tez-${tez_version} tez \
&& cd /opt \
&& sudo chown -R root:root ./hadoop-* ./hbase-* ./apache-hive* ./apache-impala* ./impala-shell-* ./spark-* ./tez-* \
&& sudo chmod -R g-w,o-w ./hadoop-* ./hbase-* ./apache-hive* ./apache-impala* ./impala-shell-* ./spark-* ./tez-*

sudo cp /etc/hadoop/container-executor.cfg /opt/hadoop/etc/hadoop/. \
&& sudo chmod 644 /opt/hadoop/etc/hadoop/container-executor.cfg \
&& sudo chown root:hadoop /opt/hadoop/bin/container-executor \
&& sudo chmod 6050 /opt/hadoop/bin/container-executor

sudo ln -sf /usr/share/java/postgresql-jdbc4.jar /opt/hive/lib/. \
&& sudo ln -sf /usr/share/java/postgresql-jdbc4.jar /opt/metastore/lib/. \
&& sudo ln -sf /usr/share/java/postgresql-jdbc4.jar /opt/impala-hive/lib/.

sudo ln -sf /usr/share/java/mysql-connector-java-8.0.19.jar /opt/hive/lib/. \
&& sudo ln -sf /usr/share/java/mysql-connector-java-8.0.19.jar /opt/metastore/lib/. \
&& sudo ln -sf /usr/share/java/mysql-connector-java-8.0.19.jar /opt/impala-hive/lib/.

cd ~/src/devwatt-cluster \
&& git pull \
&& sudo cp -r etc/* /etc/. \
&& cd /etc \
&& sudo chown -R root:root ./hadoop ./hbase ./hive ./impala ./metastore ./spark ./tez \
&& sudo chmod -R g-w,o-w ./hadoop ./hbase ./hive ./impala ./metastore ./spark ./tez \
&& cd ~/src/devwatt-cluster/bin \
&& sudo cp utils.sh metastore-standalone_ctl /opt/metastore/bin/. \
&& sudo cp utils.sh metastore_ctl hiveserver2_ctl /opt/hive/bin/. \
&& sudo cp utils.sh impala-metastore_ctl impala-hiveserver2_ctl /opt/impala-hive/bin/. \
&& sudo mkdir -p /opt/impala/bin \
&& cd ~/src/devwatt-cluster/bin \
&& sudo cp utils.sh catalogd_ctl impala-shell statestored_ctl impalad_ctl /opt/impala/bin/.

# HDFS
sudo rm -rf /var/hdfs/namesecondary/* /var/hdfs/data/* /data/hdfs/* /mnt/hdfs/* /var/hdfs/edit-1/* /var/hdfs/edit-2/* /var/hdfs/log/* /var/hdfs/name-1/* /var/hdfs/name-2/* /var/yarn/local/*

# Zookeeper
sudo cp -R ~/src/devwatt-cluster/var /var/.
sudo chown -R zookeeper:hadoop /var/zookeeper
sudo -u zookeeper /opt/zookeeper/bin/zkCli.sh
deleteall /hbase /hive

sudo -u hdfs /opt/hadoop/bin/hdfs namenode -format tthx

hdfs dfs -mkdir -p /home/ubuntu /home/yarn/log /home/mapred/mr-history/tmp /home/mapred/mr-history/done /home/hive/warehouse /home/attu7372 /home/hbase/coprocessor /tmp/hive /home/impala
hdfs dfs -chown -R ubuntu /home/ubuntu
hdfs dfs -chown -R yarn /home/yarn
hdfs dfs -chown -R mapred /home/mapred
hdfs dfs -chmod -R 1777 /home/mapred/mr-history
hdfs dfs -chmod 1770 /home/mapred/mr-history/done
hdfs dfs -chown -R hive /home/hive /tmp/hive
hdfs dfs -chown -R attu7372 /home/attu7372
hdfs dfs -chown -R hbase /home/hbase
hdfs dfs -chown -R impala /home/impala
hdfs dfs -chmod -R 1777 /home/yarn/log /home/hive/warehouse /tmp

# YARN Timeline service
hadoop org.apache.hadoop.yarn.server.timelineservice.storage.TimelineSchemaCreator -create

hdfs dfs -mkdir -p /home/hbase/coprocessor/ \
&& hdfs dfs -rm -f /home/hbase/coprocessor/hadoop-yarn-server-timelineservice.jar \
&& hdfs dfs -put /opt/hadoop/share/hadoop/yarn/timelineservice/hadoop-yarn-server-timelineservice-hbase-coprocessor-*.jar /home/hbase/coprocessor/hadoop-yarn-server-timelineservice.jar \
&& hdfs dfs -chown hbase /home/hbase/coprocessor/hadoop-yarn-server-timelineservice.jar \
&& hdfs dfs -chmod -R g+r,o+r /home/hbase/coprocessor/

hdfs dfs -mkdir -p /home/yarn/tez \
&& hdfs dfs -rm -f /home/yarn/tez/tez-*.tar.gz \
&& hdfs dfs -put /tmp/tez-*.tar.gz /home/yarn/tez/. \
&& hdfs dfs -chown -R yarn /home/yarn/tez \
&& hdfs dfs -chmod -R g+r,o+r /home/yarn/tez

hdfs dfs -mkdir -p /home/yarn/spark \
&& hdfs dfs -rm -f /home/yarn/spark/* \
&& hdfs dfs -put /opt/spark/jars/* /home/yarn/spark/. \
&& hdfs dfs -chown -R yarn /home/yarn/spark \
&& hdfs dfs -chmod -R g+r,o+r /home/yarn/spark

hdfs dfs -mkdir -p /home/hive/lib /home/hive/install \
&& hdfs dfs -rm -f /home/hive/lib/hive-exec-*.jar \
&& hdfs dfs -put /opt/hive/lib/hive-exec-*.jar /home/hive/lib \
&& hdfs dfs -chown -R hive /home/hive/lib /home/hive/install \
&& hdfs dfs -chmod -R 1777 /home/hive/lib /home/hive/install

hdfs dfs -mkdir -p /home/impala-hive/lib /home/impala/install \
&& hdfs dfs -rm -f /home/impala/lib/hive-exec-*.jar \
&& hdfs dfs -put /opt/impala-hive/lib/hive-exec-*.jar /home/impala/lib \
&& hdfs dfs -chown -R impala /home/impala/lib /home/impala/install \
&& hdfs dfs -chmod -R 1777 /home/impala/lib /home/impala/install
