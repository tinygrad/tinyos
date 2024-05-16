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

echo "text,Using Drive,$drive" | nc -U /run/tinybox-screen.sock
sleep 4

# download the os image
wget -b -o log -O tinyos.img "http://192.168.41.124:2543/tinyos.img"

# wait until the image is downloaded
while true; do
  sleep 1

  # extract the downloaded percentage from the log file
  percentage=$(grep -oP '\d+%' log | tail -n1)
  # extract the estimated time left from the log file
  time_left=$(grep -oP '\d+m\d+s' log | tail -n1)

  echo "text,Downloading Image,$percentage - $time_left" | nc -U /run/tinybox-screen.sock

  if ! pgrep -f "wget -b -o log -O tinyos.img" > /dev/null; then
    break
  fi
done

echo "text,Flashing Image" | nc -U /run/tinybox-screen.sock

# write the image to the drive
# dd if="tinyos.img" of="$drive" bs=4M status=progress
