#!/usr/bin/env bash

ip="$1"
echo "connecting to ${ip}1"

sleep 1

# TCP/IP performance tuning
sudo sysctl net.ipv4.tcp_timestamps=0
sudo sysctl net.ipv4.tcp_sack=1
sudo sysctl net.core.netdev_max_backlog=250000
sudo sysctl net.core.rmem_max=4194304
sudo sysctl net.core.wmem_max=4194304
sudo sysctl net.core.rmem_default=4194304
sudo sysctl net.core.wmem_default=4194304
sudo sysctl net.core.optmem_max=4194304
sudo sysctl net.ipv4.tcp_rmem="4096 87380 4194304"
sudo sysctl net.ipv4.tcp_wmem="4096 65536 4194304"
sudo sysctl net.ipv4.tcp_low_latency=1
sudo sysctl net.ipv4.tcp_congestion_control=bbr

# mount NFS
if ! sudo mount -o rdma,port=20049 "${ip}1":/raid /mnt; then
  echo "text,$(hostname -i | xargs):19531,,Failed to mount NFS" | nc -U /run/tinybox-screen.sock
  exit 1
fi

sudo chown -R tiny:tiny /raid
rclone copy -P --auto-confirm --links --check-first --checkers 32 --multi-thread-streams 8 --transfers 32 /mnt/ /raid/ | while read -r line; do
  echo "$line"
  case "$line" in
    *ETA*)
      # extract transfer speed
      speed=$(echo "$line" | grep -oP ', \d+\.\d+ [kMG]Bytes/s,' | grep -oP '\d+\.\d+ [kMG]Bytes/s')
      # extract percentage
      percentage=$(echo "$line" | grep -oP '\d+%,' | grep -oP '\d+')
      # extract ETA
      eta=$(echo "$line" | grep -oP 'ETA (\d+h\d+m\d+s)|(\d+m\d+s)|(\d+s)')
      echo "text,$(hostname -i | xargs):19531,,Populating RAID,${speed},${percentage}% - ${eta}" | nc -U /run/tinybox-screen.sock
      ;;
  esac
done
sudo chown -R tiny:tiny /raid

sudo umount /mnt

echo "sleep" | nc -U /run/tinybox-screen.sock
