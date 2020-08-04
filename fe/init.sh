# LVM
sudo lvcreate -l 100%FREE -n log_vg datavg
sudo mkfs -t ext4 /dev/datavg/log_vg

# NTP
sudo timedatectl set-timezone Europe/Paris
sudo timedatectl set-ntp true

# purge
sudo rm -rf /log/hdfs /log/mapred /log/yarn /log/hive /log/metastore /log/impala /log/spark /log/zookeeper /log/hbase \
&& sudo rm -rf /etc/hadoop /etc/hive /etc/metastore /etc/impala /etc/spark /etc/zookeeper /etc/hbase  /etc/tez /etc/profile.d/hadoop-env.sh /etc/profile.d/spark-env.sh \
&& sudo rm -rf /data/hdfs /mnt/hdfs \
&& sudo rm -rf /opt/*hadoop* /opt/*hive* /opt/*metastore* /opt/*impala* /opt/*spark* /opt/*zookeeper* /opt/*hbase*  /opt/*tez* /opt/isa-l /opt/protobuf*

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
&& echo 'diod:azerty'|sudo chpasswd \
&& sudo adduser diod hadoop

users="diod attu7372 hdfs yarn mapred hive hbase zookeeper spark impala"
rm /tmp/authorized_keys-$(hostname)
touch /tmp/authorized_keys-$(hostname)
chmod 777 /tmp/authorized_keys-$(hostname)
for x in ${users};
do
  sudo -u ${x} ssh-keygen -t rsa -b 4096 -q -N '' -f /home/${x}/.ssh/id_rsa <<< y \
  && sudo -u ${x} cat /home/${x}/.ssh/id_rsa.pub >> /tmp/authorized_keys-$(hostname)
done
users="diod attu7372 hdfs yarn mapred hive hbase zookeeper spark impala"
for x in ${users};
do
  sudo -u ${x} cp /tmp/authorized_keys /home/${x}/.ssh/. \
  && sudo -u ${x} chmod 600 /home/${x}/.ssh/authorized_keys
done
rm /tmp/authorized_keys-$(hostname)

users="diod attu7372 hdfs yarn mapred hive hbase zookeeper spark impala"
for x in ${users};
do
  sudo -u ${x} rm -f /home/${x}/.ssh/known_hosts
done

git config --global http.proxy http://devwatt-proxy.si.fr.intraorange:8080 \
&& mkdir -p /home/ubuntu/src \
&& cd /home/ubuntu/src \
&& git clone https://github.com/tthx/devwatt-cluster.git

cd /opt \
&& sudo rm -rf ./apache-hive* ./hbase* ./apache-impala* ./impala-shell* ./hadoop* ./tez* \
&& cd /tmp \
&& sudo tar xf jdk-8u251-linux-x64.tar.gz -C /opt \
&& sudo tar xf apache-zookeeper-3.6.1-bin.tar.gz -C /opt \
&& sudo tar xf apache-hive-3.1.3-bin.tar.gz -C /opt \
&& sudo tar xf apache-hive-metastore-3.1.3-bin.tar.gz -C /opt \
&& sudo tar xf apache-hive-2.1.2-SNAPSHOT-bin.tar.gz -C /opt \
&& sudo tar xf hbase-2.2.6-SNAPSHOT-bin.tar.gz -C /opt \
&& sudo mkdir -p /opt/apache-impala-3.4.0-bin \
&& sudo tar xf apache-impala-3.4.0-bin.tar.bz2 -C /opt/apache-impala-3.4.0-bin \
&& sudo tar xf hadoop-3.1.2.tar.gz -C /opt \
&& sudo mkdir -p /opt/tez-0.9.2 \
&& sudo tar xf tez-0.9.2.tar.gz -C /opt/tez-0.9.2 \
&& sudo cp tez-aux-services-0.9.2.jar /opt/tez-0.9.2/. \
&& sudo tar xf /opt/apache-impala-3.4.0-bin/shell/build/impala-shell-3.4.0-RELEASE.tar.gz -C /opt \
&& cd /opt \
&& sudo rm -f hive metastore hbase hbase impala impala-hive impala-shell hadoop tez \
&& sudo ln -sf jdk1.8.0_261 jdk \
&& sudo ln -sf apache-zookeeper-3.6.1-bin zookeeper \
&& sudo ln -sf apache-hive-3.1.3-bin hive \
&& sudo ln -sf apache-hive-metastore-3.1.3-bin metastore \
&& sudo ln -sf apache-hive-2.1.2-SNAPSHOT-bin impala-hive \
&& sudo ln -sf hbase-2.2.6-SNAPSHOT hbase \
&& sudo ln -sf apache-impala-3.4.0-bin impala \
&& sudo ln -sf impala-shell-3.4.0-RELEASE impala-shell \
&& sudo ln -sf hadoop-3.1.2 hadoop \
&& sudo ln -sf tez-0.9.2 tez \
&& cd /opt \
&& sudo chown -R root:root ./hadoop-* ./hbase-* ./apache-hive* ./apache-impala* ./impala-shell-* ./tez-* \
&& sudo chmod -R g-w,o-w ./hadoop-* ./hbase-* ./apache-hive* ./apache-impala* ./impala-shell-* ./tez-* \
&& sudo cp /etc/hadoop/container-executor.cfg /opt/hadoop/etc/hadoop/. \
&& sudo chmod 644 /opt/hadoop/etc/hadoop/container-executor.cfg \
&& sudo chown root:hadoop /opt/hadoop/bin/container-executor \
&& sudo chmod 6050 /opt/hadoop/bin/container-executor \
&& sudo ln -sf /usr/share/java/postgresql-jdbc4.jar /opt/hive/lib/. \
&& sudo ln -sf /usr/share/java/postgresql-jdbc4.jar /opt/metastore/lib/. \
&& sudo ln -sf /usr/share/java/postgresql-jdbc4.jar /opt/impala-hive/lib/.

sudo ln -sf /usr/share/java/mysql-connector-java-8.0.19.jar /opt/hive/lib/. \
&& sudo ln -sf /usr/share/java/mysql-connector-java-8.0.19.jar /opt/metastore/lib/. \
&& sudo ln -sf /usr/share/java/mysql-connector-java-8.0.19.jar /opt/impala-hive/lib/.

cd ~/src/devwatt-cluster/fe \
&& git pull \
&& sudo cp -r etc/* /etc/. \
&& sudo chown -R root:root ./hadoop ./hbase ./hive ./impala ./metastore ./spark ./tez \
&& sudo chmod -R g-w,o-w ./hadoop ./hbase ./hive ./impala ./metastore ./spark ./tez \
&& cd ~/src/devwatt-cluster/bin \
&& sudo cp utils.sh metastore-standalone_ctl /opt/metastore/bin/. \
&& sudo cp utils.sh metastore_ctl hiveserver2_ctl /opt/hive/bin/. \
&& sudo cp utils.sh impala-metastore_ctl impala-hiveserver2_ctl /opt/impala-hive/bin/. \
&& sudo mkdir -p /opt/impala/bin \
&& cd ~/src/devwatt-cluster/bin \
&& sudo cp utils.sh catalogd_ctl impala-shell statestored_ctl impalad_ctl /opt/impala/bin/.

# Zookeeper
sudo cp -R ~/src/devwatt-cluster/fe/var /log/. \
&& sudo chown -R zookeeper:hadoop /log/zookeeper
sudo -u zookeeper /opt/zookeeper/bin/zkCli.sh
deleteall /hbase /hive

sudo mkdir -p /log/hdfs/namesecondary /log/hdfs/data /data/hdfs /log/hdfs/edit-1 /log/hdfs/edit-2 /log/hdfs/log /log/hdfs/name-1 /log/hdfs/name-2 /log/hdfs/run /log/yarn/local /log/yarn/log /log/yarn/run /log/mapred/log /log/mapred/run /log/zookeeper/conf /log/zookeeper/log /log/zookeeper/data /log/hbase/log /log/hbase/run /log/spark/log /log/spark/run /log/hive/run /log/hive/log /log/hive/run /log/hive/tmp /log/metastore/run /log/metastore/log /etc/hadoop /etc/hbase /etc/hive /etc/metastore /etc/tez /etc/spark /etc/impala /log/impala/log /log/impala/run /log/impala/tmp /log/ubuntu/log /log/attu7372/log \
&& sudo chown -R hdfs:hadoop /log/hdfs /data/hdfs \
&& sudo chown -R yarn:hadoop /log/yarn \
&& sudo chown -R mapred:hadoop /log/mapred \
&& sudo chown -R zookeeper:hadoop /log/zookeeper \
&& sudo chown -R hbase:hadoop /log/hbase \
&& sudo chown -R hive:hadoop /log/hive /log/metastore \
&& sudo chown -R impala:hadoop /log/impala \
&& sudo chown -R spark:hadoop /log/spark \
&& sudo chown -R ubuntu:hadoop /log/ubuntu \
&& sudo chown -R attu7372:hadoop /log/attu7372 \
&& sudo chmod 775 /log/hive/tmp \
&& sudo mkdir -p /mnt/hdfs \
&& sudo chmod 755 /mnt/hdfs

# HDFS
sudo rm -rf /log/hdfs/namesecondary/* /log/hdfs/data /data/hdfs /mnt/hdfs/* /log/hdfs/edit-1/* /log/hdfs/edit-2/* /log/hdfs/log/* /log/hdfs/name-1/* /log/hdfs/name-2/* /log/yarn/local/* \
&& sudo mkdir -p /data/hdfs /log/hdfs/data \
&& sudo chown -R hdfs:hadoop /data/hdfs /log/hdfs/data

sudo -u hdfs /opt/hadoop/bin/hdfs namenode -format tthx

sudo -u hdfs /opt/hadoop/bin/hdfs dfs -mkdir -p /tmp/hive /home/ubuntu /home/yarn/log /home/mapred/mr-history/tmp /home/mapred/mr-history/done /home/hive/warehouse /home/attu7372 /home/hbase/coprocessor /tmp/hive /home/impala/warehouse \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -chown hdfs /home \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -chown -R ubuntu /home/ubuntu \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -chown -R yarn /home/yarn \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -chown -R mapred /home/mapred \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -chmod -R 1777 /home/mapred/mr-history \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -chmod 1777 /home/mapred/mr-history/done \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -chown -R hive /home/hive /tmp/hive \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -chown -R attu7372 /home/attu7372 \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -chown -R hbase /home/hbase \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -chown -R impala /home/impala \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -chmod -R 1777 /home/yarn/log /home/hive/warehouse /home/impala/warehouse /tmp \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -mkdir -p /home/hbase/coprocessor/ \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -rm -f /home/hbase/coprocessor/hadoop-yarn-server-timelineservice.jar \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -put /opt/hadoop/share/hadoop/yarn/timelineservice/hadoop-yarn-server-timelineservice-hbase-coprocessor-*.jar /home/hbase/coprocessor/hadoop-yarn-server-timelineservice.jar \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -chown hbase /home/hbase/coprocessor/hadoop-yarn-server-timelineservice.jar \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -chmod -R g+r,o+r /home/hbase/coprocessor/ \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -mkdir -p /home/yarn/tez \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -rm -f /home/yarn/tez/tez-*.tar.gz \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -put /tmp/tez-*.tar.gz /home/yarn/tez/. \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -chown -R yarn /home/yarn/tez \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -chmod -R g+r,o+r /home/yarn/tez \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -mkdir -p /home/hive/lib /home/hive/install \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -rm -f /home/hive/lib/hive-exec-*.jar \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -put /opt/hive/lib/hive-exec-*.jar /home/hive/lib \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -chown -R hive /home/hive/lib /home/hive/install \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -chmod -R 1777 /home/hive/lib /home/hive/install \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -mkdir -p /home/impala-hive/lib /home/impala/install \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -rm -f /home/impala/lib/hive-exec-*.jar \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -put /opt/impala-hive/lib/hive-exec-*.jar /home/impala/lib \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -chown -R impala /home/impala/lib /home/impala/install \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -chmod -R 1777 /home/impala/lib /home/impala/install

# YARN Timeline service
sudo -u yarn /opt/hadoop/bin/hadoop org.apache.hadoop.yarn.server.timelineservice.storage.TimelineSchemaCreator -create

sudo -u hdfs /opt/hadoop/bin/hdfs dfs -mkdir -p /home/yarn/spark \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -rm -f /home/yarn/spark/* \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -put /opt/spark/jars/* /home/yarn/spark/. \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -chown -R yarn /home/yarn/spark \
&& sudo -u hdfs /opt/hadoop/bin/hdfs dfs -chmod -R g+r,o+r /home/yarn/spark
