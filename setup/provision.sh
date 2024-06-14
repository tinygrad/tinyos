#!/usr/bin/env bash

sleep 2

echo "atext,Waiting for NIC.. ,Waiting for NIC ..,Waiting for NIC. ." | nc -U /run/tinybox-screen.sock
# wait for enp65s0f0np0
while ! ip ad | grep -q enp65s0f0np0; do
  sleep 1
done

bash /opt/tinybox/setup/populateraid.sh
sleep 1

echo "text,RAID Populated,Starting ResNet Train" | nc -U /run/tinybox-screen.sock
sleep 1

if [ -z "$IS_NVIDIA_GPU" ]; then
  su tiny -c "bash /opt/tinybox/setup/trainresnet.sh"
fi
