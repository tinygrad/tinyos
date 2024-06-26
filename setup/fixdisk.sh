#!/usr/bin/env bash
set -xeo pipefail

# find what disk we are on
part=$(mount | grep 'on / ' | cut -d' ' -f1 | sed 's/p[0-9]*$//')
disk=$(echo "$part" | sed 's/[0-9]*$//')

# fix the backup gpt header using sgdisk
sgdisk -e "$disk"

# fix other problems with gdisk
echo -e "v\nw\ny\ny\ny\ny\ny\n" | gdisk "$disk"
