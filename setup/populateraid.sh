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
rclone copy --config /opt/tinybox/setup/rclone.conf -P --copy-links --multi-thread-streams 64 --transfers 64 tinyd:/ /raid/ | while read -r line; do
  case "$line" in
    *ETA*)
      # extract transfer speed
      speed=$(echo "$line" | grep -oP '\d+\.\d+ [kMG]Bytes/s')
      # extract percentage
      percentage=$(echo "$line" | grep -oP '\d+%,' | grep -oP '\d+')
      # extract ETA
      eta=$(echo "$line" | grep -oP '(\d+h\d+m\d+s)|(\d+m\d+s)|(\d+s)')
      echo "text,Populating RAID,${speed},${percentage}% - ${eta}" | nc -U /run/tinybox-screen.sock
      ;;
  esac
done
sudo chown -R tiny:tiny /raid
ip ad del 10.0.0.2/24 dev enp65s0f0np0
echo "sleep" | nc -U /run/tinybox-screen.sock
