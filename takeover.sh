#!/bin/sh
set -xe

sleep 2

# find first /dev/sd{a-z} that is not mounted
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

echo "text,Using Drive,$drive" | nc -U /run/tinybox-screen.sock
sleep 2

# download the os image
wget -b -o /tmp/log -O /tmp/tinyos.img "http://192.168.41.124:2543/tinyos.img"

# wait until the image is downloaded
while true; do
  sleep 1

  # extract the downloaded percentage from the log file
  percentage=$(grep -oP '\d+%' /tmp/log | tail -n1)
  # extract the estimated time left from the log file
  time_left=$(grep -oP '(\d+m)?\d+s' /tmp/log | tail -n1)

  echo "text,Downloading Image,$percentage - $time_left" | nc -U /run/tinybox-screen.sock

  if ! pgrep -f "wget -b -o /tmp/log -O /tmp/tinyos.img" > /dev/null; then
    break
  fi
done

# see if the image was downloaded successfully by seeing if there is a 100% in the log file
if ! grep -q "100%" /tmp/log; then
  echo "text,Download Failed" | nc -U /run/tinybox-screen.sock
  exit 1
fi

echo "text,Flashing Image" | nc -U /run/tinybox-screen.sock

# write the image to the drive
dd if=/tmp/tinyos.img of="$drive" bs=4M

# tell uefi to boot from the internal drive
bootnum="$(efibootmgr | grep -i "Sabrent SSD 1.00" | grep -oP '\d+' | head -n1)"
efibootmgr -n "$bootnum"

echo "text,Flashing Complete,Rebooting" | nc -U /run/tinybox-screen.sock
sleep 2
reboot
