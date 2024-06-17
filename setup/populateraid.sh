#!/usr/bin/env bash

sleep 1

# TCP/IP performance tuning
sysctl net.ipv4.tcp_timestamps=0
sysctl net.ipv4.tcp_sack=1
sysctl net.core.netdev_max_backlog=250000
sysctl net.core.rmem_max=4194304
sysctl net.core.wmem_max=4194304
sysctl net.core.rmem_default=4194304
sysctl net.core.wmem_default=4194304
sysctl net.core.optmem_max=4194304
sysctl net.ipv4.tcp_rmem="4096 87380 4194304"
sysctl net.ipv4.tcp_wmem="4096 65536 4194304"
sysctl net.ipv4.tcp_low_latency=1
sysctl net.ipv4.tcp_congestion_control=bbr

ip ad add 10.0.0.2/24 dev enp65s0f0np0
ip link set enp65s0f0np0 up
ip link set enp65s0f0np0 mtu 9000

/opt/tinybox/setup/parallel-rsync/prsync -a --inplace rsync://10.0.0.1:2555/raid/ /raid/ &

# grab the total size of all the files
total_size=$(find /tmp -f -name "total.size" -exec cat {} \;)

# watch the progress of all the rsyncs
SECONDS=0
while true; do
  # calculate the total size of all the files transferred
  transferred_size=$(df -B1 /raid | tail -n 1 | awk '{print $3}')
  # calculate the percentage of files transferred
  percentage=$(echo "scale=2; $transferred_size / $total_size * 100" | bc | cut -d. -f1)
  # calculate the speed of the transfer
  speed=$(echo "scale=2; $transferred_size / $SECONDS / 1024 / 1024" | bc | cut -d. -f1)
  # calculate the ETA
  eta=$(echo "scale=2; ($total_size - $transferred_size) / $speed" | bc | awk '{printf "%d:%02d:%02d", $1/3600, $1%3600/60, $1%60}')

  echo "text,Populating RAID,${speed},${percentage}% - ${eta}" | nc -U /run/tinybox-screen.sock

  if ! pgrep -f prsync; then
    break
  fi
done

chown -R tiny:tiny /raid


ip ad del 10.0.0.2/24 dev enp65s0f0np0
echo "sleep" | nc -U /run/tinybox-screen.sock
