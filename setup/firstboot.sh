#!/usr/bin/env bash
set -xeo pipefail

source /etc/tinybox-release

echo "atext,Preparing.. ,Preparing ..,Preparing. ." | nc -U /run/tinybox-screen.sock

# enable display related services
systemctl enable displayservice
systemctl enable buttonservice
systemctl enable poweroff
systemctl enable reboot

# remove rmedia
bash /opt/tinybox/setup/remove_rmedia.sh

# enable second boot service
systemctl enable secondboot

# enable autoupdate service
systemctl enable autoupdate-tinybox

# enable tinychat
systemctl enable tinychat

# set hostname
hostnamectl hostname tinybox

# enable ntp
timedatectl set-ntp true

# setup raid
bash /opt/tinybox/setup/raidsetup.sh

# fix disk
bash /opt/tinybox/setup/fixdisk.sh

# finalize some things
update-initramfs -u

# show that we are rebooting
bash /opt/tinybox/service/reboot.sh
