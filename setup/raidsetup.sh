#!/usr/bin/env bash
set -x

echo "atext,Creating RAID.. ,Creating RAID ..,Creating RAID. ." | nc -U /run/tinybox-screen.sock

# see if a raid array is already created, checking for anything under /dev/md/
if [ -z "$(ls -A /dev/md/)" ]; then
  echo "No RAID array found, creating one..."
  mdadm --zero-superblock /dev/nvme0n1 /dev/nvme1n1 /dev/nvme2n1 /dev/nvme3n1
  mdadm --create /dev/md0 --level=0 --raid-devices=4 /dev/nvme0n1 /dev/nvme1n1 /dev/nvme2n1 /dev/nvme3n1 -f
  mkfs.ext4 /dev/md0
else
  echo "RAID array found, skipping creation..."
fi
