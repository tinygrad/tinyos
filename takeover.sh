#!/bin/sh
set -xe

# find first /dev/sd{a-z} that is not mounted in posix shell
drive=""
for i in a b c d e f g h i j k l m n o p q r s t u v w x y z; do
  if ! mount | grep -q "/dev/sd$i"; then
    drive="/dev/sd$i"
    echo "Found drive: $drive"
    break
  fi
done

if [ -z "$drive" ]; then
  echo "No available drives found."
  exit 1
fi

# download the os image
wget "http://192.168.41.124:2543/tinyos.img"

# write the image to the drive
dd if="tinyos.img" of="$drive" bs=4M status=progress
