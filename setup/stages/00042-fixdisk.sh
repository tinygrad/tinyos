#!/usr/bin/env bash
set -xeo pipefail

# find what disk we are on
part=$(mount | grep 'on / ' | cut -d' ' -f1)
# get the disk name by removing the partition number
if [[ "$part" == *"nvme"* ]]; then
  disk=$(echo "$part" | sed 's/p[0-9]*$//')
else
  disk=$(echo "$part" | sed 's/[0-9]*$//')
fi

# fix the backup gpt header using sgdisk
sgdisk -e "$disk"

# fix other problems with gdisk
echo -e "v\nw\ny\ny\ny\ny\ny\n" | gdisk "$disk"
