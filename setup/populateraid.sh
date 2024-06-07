#!/usr/bin/env bash

sleep 1

ip ad add 10.0.0.2/24 dev enp65s0f0np0
ip link set enp65s0f0np0 up
rclone copy --config /opt/tinybox/setup/rclone.conf -P --copy-links --multi-thread-streams 32 --transfers 32 tinyd:/ /raid/ | while read -r line; do
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
ip ad del 10.0.0.2/24 dev enp65s0f0np0
