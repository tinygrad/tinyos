#!/usr/bin/env bash
set -x

source /etc/tinybox-release

if [[ -z "$TINYBOX_CORE" ]]; then
  # see if a raid array is already created, checking for anything under /dev/md/
  if [ -z "$(ls -A /dev/md/)" ]; then
    echo "No RAID array found, creating one..."
    mdadm --zero-superblock /dev/nvme0n1 /dev/nvme1n1 /dev/nvme2n1 /dev/nvme3n1
    mdadm --create /dev/md0 --level=0 --raid-devices=4 /dev/nvme0n1 /dev/nvme1n1 /dev/nvme2n1 /dev/nvme3n1 -f --run
    mkfs.ext4 /dev/md0
  else
    echo "RAID array found, skipping creation..."
  fi

  # get the UUID of the RAID array, which is the uuid of the first md device which might not be md0
  UUID=$(blkid -s UUID -o value /dev/md* | head -n 1)

  # check if we already have a /raid mountpoint in fstab
  if ! grep -q "/raid" /etc/fstab; then
    # if not, add it
    echo "UUID=$UUID /raid ext4 defaults,nofail 0 0" >> /etc/fstab
  else
    echo "/raid mountpoint already exists in fstab, skipping..."
  fi
fi
