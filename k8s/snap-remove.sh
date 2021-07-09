#!/bin/bash
. "$(dirname "${BASH_SOURCE[0]}")"/k8s-env.sh
function snap_remove {
  local i;
  for i in ${CTRL_PLANE} ${WORKERS};
  do
    ssh ${SSH_OPTS} ${SUDO_USER}@${i} " \
      set -euo pipefail;
      snap list;
      sudo snap remove gnome-3-28-1804;
      sudo snap remove gnome-3-34-1804;
      sudo snap remove gtk-common-themes;
      sudo snap remove snap-store;
      sudo snap remove core18;
      sudo apt-get -y autopurge snapd*;
      echo \
\"Package: snapd
Pin: release *
Pin-Priority: -1\" | \
        sudo tee /etc/apt/preferences.d/nosnap > /dev/null";
  done
  return ${?};
}
