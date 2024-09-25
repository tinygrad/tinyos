#!/usr/bin/env bash
set -xeo pipefail

source /etc/tinybox-release

echo "atext,Preparing.. ,Preparing ..,Preparing. ." | nc -U /run/tinybox-screen.sock

# enable display related services
if [ -z "$TINYBOX_PRO" ]; then
  systemctl enable displayservice
  systemctl enable buttonservice
  systemctl enable poweroff
  systemctl enable reboot
fi

# enable second boot service
systemctl enable secondboot

# enable autoupdate service
systemctl enable autoupdate-tinybox

# enable tinychat
if [ -z "$TINYBOX_PRO" ]; then
  systemctl enable tinychat
fi

# set hostname
hostnamectl hostname tinybox

# enable ntp
timedatectl set-ntp true

# setup raid
if [ -z "$TINYBOX_PRO" ]; then
  bash /opt/tinybox/setup/raidsetup.sh
fi

# fix disk
bash /opt/tinybox/setup/fixdisk.sh

# finalize some things
update-initramfs -u

# show that we are rebooting
if [ -z "$TINYBOX_PRO" ]; then
  bash /opt/tinybox/service/reboot.sh
fi
