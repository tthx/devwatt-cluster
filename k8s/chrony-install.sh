#!/bin/bash
. "$(dirname "${BASH_SOURCE[0]}")"/k8s-env.sh
function chrony_install {
  local nodes_subnet="192.168.0.255";
  local chrony_keyid="1";
  local err=0;
  local i;
  for i in ${CTRL_PLANE} ${WORKERS};
  do
    ssh ${SSH_OPTS} ${SUDO_USER}@${i} " \
      set -euo pipefail;
      sudo apt-get -y autopurge ntp ntpdate;
      sudo systemctl stop systemd-timesyncd.service;
      sudo systemctl disable systemd-timesyncd.service;
      sudo systemctl stop openntpd.service;
      sudo systemctl disable openntpd.service;
      sudo systemctl disable systemd-timesyncd.service --now;
      sudo systemctl disable openntpd.service --now;
      sudo systemctl mask systemd-timesyncd.service;
      sudo systemctl mask openntpd.service;
      sudo apt-get update;
      sudo apt-get -y install chrony";
    if [[ ${?} -eq 0 ]];
    then
      if [[ "${i}" == "${CTRL_PLANE}" ]];
      then
        ssh ${SSH_OPTS} ${SUDO_USER}@${i} " \
          set -euo pipefail;
          chronyc keygen ${chrony_keyid} SHA256 256 | 
            sudo tee -a /etc/chrony/chrony.keys > /dev/null;
          echo \"
allow ${nodes_subnet}/24
bindaddress ${CTRL_PLANE_IP}
local\" | \
            sudo tee -a /etc/chrony/chrony.conf > /dev/null";
      else
        ssh ${SSH_OPTS} ${SUDO_USER}@${i} \
          "set -euo pipefail;
          echo \"
server master prefer iburst key ${chrony_keyid}\" | \
            sudo tee -a /etc/chrony/chrony.conf > /dev/null"
      fi
    fi
    if [[ ${?} -eq 0 ]];
    then
      ssh ${SSH_OPTS} ${SUDO_USER}@${i} \
        "sudo systemctl restart chrony.service";
      err=${?};
    else
      echo "ERROR: ${FUNCNAME[0]}: Unable to set chrony on node ${i}";
      err=1;
    fi
  done
  return ${err};
}
