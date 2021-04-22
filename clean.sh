#!/bin/bash
sudo umount /mnt/hdfs && \
sudo rm -rf /mnt/hdfs /var/hdfs /var/yarn /var/mapred && \
sudo apt-get -y autoremove --purge && \
sudo apt-get -y autoclean && \
sudo journalctl --vacuum-time=1d && \
sudo rm -rf /var/hdfs/log/* /var/yarn/log/* /var/mapred/log/* /var/hbase/log/* /var/zookeeper/log/* /var/attu7372/log/* /var/ubuntu/log/*
