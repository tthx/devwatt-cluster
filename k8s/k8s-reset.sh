#!/bin/bash
. "$(dirname "${BASH_SOURCE[0]}")"/k8s-env.sh
function k8s_reset {
  local i;
  local containers;
  local debug_level="0"; # 0 to 9
  for i in ${CTRL_PLANE} ${WORKERS};
  do
    ssh ${SSH_OPTS} ${SUDO_USER}@${i} " \
      set -eu;
      yes | sudo kubeadm reset --v=${debug_level};
      sudo iptables -F;
      sudo iptables -t nat -F;
      sudo iptables -t mangle -F;
      sudo iptables -X;
      #sudo ipvsadm -C;
      containers=\"\$(sudo docker container ls -aq)\";
      if [[ -n \"\${containers}\" ]];
      then
        sudo docker container stop \"\${containers}\";
      fi
      sudo docker system prune -a -f --volumes;
      sudo journalctl --vacuum-time=1d";
  done
  return ${?};
}

k8s_reset;
exit ${?};
