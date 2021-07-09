#!/bin/bash
. "$(dirname "${BASH_SOURCE[0]}")"/k8s-env.sh
function disable_hugepage {
  local i;
  for i in ${CTRL_PLANE} ${WORKERS};
  do
    ssh ${SSH_OPTS} ${SUDO_USER}@${i} " \
      set -euo pipefail;
      sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=\"[a-zA-Z0-9_= ]*/& transparent_hugepage=never/' /etc/default/grub;
      sudo update-grub;
      echo \"vm.swappiness = 1\" | sudo tee -a /etc/sysctl.conf > /dev/null" || \
        { echo "ERROR: ${FUNCNAME[0]}: Unable to disable hugepage on node ${i}"; return 1; }
  done
  return 0;
}
