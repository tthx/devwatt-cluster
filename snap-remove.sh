#!/bin/bash
snap list

sudo snap remove gnome-3-28-1804 && \
sudo snap remove gnome-3-34-1804 && \
sudo snap remove gtk-common-themes && \
sudo snap remove snap-store && \
sudo snap remove core18 && \
sudo apt-get -y autopurge snapd*

sudo tee /etc/apt/preferences.d/nosnap <<EOF
Package: snapd
Pin: release *
Pin-Priority: -1
EOF