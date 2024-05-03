#!/usr/bin/env bash

echo "atext,Creating RAID.. ,Creating RAID ..,Creating RAID. ." | nc -U /run/tinybox-screen.sock

umount /raid
mdadm --stop /dev/md127 /dev/md0
mdadm --zero-superblock /dev/nvme0n1 /dev/nvme1n1 /dev/nvme2n1 /dev/nvme3n1
mdadm --create /dev/md127 --level=0 --raid-devices=4 /dev/nvme0n1 /dev/nvme1n1 /dev/nvme2n1 /dev/nvme3n1 -f
mkfs.ext4 /dev/md127 -f
