#!/bin/sh
sudo apt-get -y autopurge ntp ntpdate &&\
sudo systemctl stop systemd-timesyncd.service && \
sudo systemctl disable systemd-timesyncd.service && \
sudo systemctl stop openntpd.service && \
sudo systemctl disable openntpd.service && \
sudo systemctl disable systemd-timesyncd.service --now && \
sudo systemctl disable openntpd.service --now && \
sudo systemctl mask systemd-timesyncd.service && \
sudo systemctl mask openntpd.service && \
sudo apt-get update && \
sudo apt-get -y install chrony

# on master
sudo cp /etc/chrony/chrony.keys /tmp/toto && \
chronyc keygen 1 SHA256 256 >> /tmp/toto && \
sudo mv /tmp/toto /etc/chrony/chrony.keys && \
sudo chown root:root /etc/chrony/chrony.keys && \
sudo chmod 640 /etc/chrony/chrony.keys

sudo tee -a /etc/chrony/chrony.conf << EOF

allow 192.168.0.255/24
bindaddress 192.168.0.49
local
EOF

sudo systemctl restart chrony.service

# on slaves
sudo tee -a /etc/chrony/chrony.conf << EOF

server master prefer iburst key 1
EOF

sudo systemctl restart chrony.service