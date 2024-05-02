#!/usr/bin/env bash

umount /raid
mdadm --stop /dev/md0
mdadm --zero-superblock /dev/nvme0n1 /dev/nvme1n1 /dev/nvme2n1 /dev/nvme3n1
mdadm --create /dev/md0 --level=0 --raid-devices=4 /dev/nvme0n1 /dev/nvme1n1 /dev/nvme2n1 /dev/nvme3n1 -f
mkfs.xfs /dev/md0 -f
