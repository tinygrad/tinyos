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

# first log dmidecode
if ! sudo mount -o rdma,port=20049,vers=4.2 10.0.0.1:/opt/dmi /mnt; then
  echo "text,Failed to mount NFS" | nc -U /run/tinybox-screen.sock
  exit 1
fi

json_dmi=$(sudo dmidecode | jc --dmidecode)
cpu_serial=$(echo "$json_dmi" | jq -r '.[] | select(.description | contains("Base Board Information")) | .values.serial_number' | tr -d '[:space:]')
# ensure there isn't already a file with the same serial
if [ -f "/mnt/${cpu_serial}.json" ]; then
  echo "text,Serial already exists" | nc -U /run/tinybox-screen.sock
  exit 1
fi
echo "$json_dmi" > "/mnt/${cpu_serial}.json"
cp /var/log/cloud-init-output.log "/mnt/${cpu_serial}_cloud-init-output.log"

sudo umount /mnt

# mount NFS
if ! sudo mount -o rdma,port=20049,vers=4.2 10.0.0.1:/raid /mnt; then
  echo "text,Failed to mount NFS" | nc -U /run/tinybox-screen.sock
  exit 1
fi

sudo chown -R tiny:tiny /raid
rclone copy -P --auto-confirm --links --check-first --checkers 32 --multi-thread-streams 8 --transfers 32 /mnt/ /raid/ | while read -r line; do
  echo "$line"
  case "$line" in
    *ETA*)
      # extract transfer speed
      speed=$(echo "$line" | grep -oP 'ETA[ ]+\d+\.\d+ [kMG]Bytes/s' | grep -oP '\d+\.\d+ [kMG]Bytes/s')
      # extract percentage
      percentage=$(echo "$line" | grep -oP '\d+%,' | grep -oP '\d+')
      # extract ETA
      eta=$(echo "$line" | grep -oP '(\d+h\d+m\d+s)|(\d+m\d+s)|(\d+s)')
      echo "text,Populating RAID,${speed},${percentage}% - ${eta}" | nc -U /run/tinybox-screen.sock
      ;;
  esac
done
sudo chown -R tiny:tiny /raid

sudo umount /mnt

sudo ip ad del 10.0.0.2/24 dev enp65s0f0np0
echo "sleep" | nc -U /run/tinybox-screen.sock
