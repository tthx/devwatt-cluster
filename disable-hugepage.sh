#!/bin/bash
sed -r 's/GRUB_CMDLINE_LINUX_DEFAULT="[a-zA-Z0-9_= ]*/& transparent_hugepage=never/' /etc/default/grub | sudo tee /etc/default/grub && \
sudo update-grub &&
echo 'vm.swappiness = 1' | sudo tee -a /etc/sysctl.conf