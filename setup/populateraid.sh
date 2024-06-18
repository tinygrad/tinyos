#!/usr/bin/env bash

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

sudo ip ad add 10.0.0.2/24 dev enp65s0f0np0
sudo ip link set enp65s0f0np0 up
sudo ip link set enp65s0f0np0 mtu 9000

/opt/tinybox/setup/parallel-rsync/prsync -aWz --zc=zstd --inplace rsync://10.0.0.1:2555/raid/ /raid/ &
sleep 1

# grab the total size of all the files
total_size=$(find /tmp -name "total.size" -exec cat {} \;)
while [ -z "$total_size" ]; do
  sleep 1
  total_size=$(find /tmp -name "total.size" -exec cat {} \;)
done

# total_size is including what is already on the disk
total_size=$((total_size + $(df -B1 /raid | tail -n 1 | awk '{print $3}')))

# watch the progress of all the rsyncs
last_transferred_size=0
while true; do
  sleep 1

  # calculate the total size of all the files transferred
  transferred_size=$(df -B1 /raid | tail -n 1 | awk '{print $3}')
  # calculate the percentage of files transferred
  percentage=$(echo "scale=2; $transferred_size / $total_size * 100" | bc | cut -d. -f1)
  # calculate the speed of the transfer in MB/s
  speed=$(echo "scale=2; ($transferred_size - $last_transferred_size) / 1024 / 1024" | bc)
  # calculate the ETA
  if [ "$speed" == "0" ]; then
    eta="Unknown"
  else
    eta=$(echo "scale=2; ($total_size - $transferred_size) / ($transferred_size - $last_transferred_size)" | bc | awk '{printf "%d:%02d:%02d", $1/3600, $1%3600/60, $1%60}')
  fi
  last_transferred_size=$transferred_size

  echo "text,Populating RAID,${speed}MB/s,${percentage}% - ${eta}" | nc -U /run/tinybox-screen.sock

  if ! pgrep -f prsync; then
    break
  fi
done

sudo chown -R tiny:tiny /raid


sudo ip ad del 10.0.0.2/24 dev enp65s0f0np0
echo "sleep" | nc -U /run/tinybox-screen.sock
