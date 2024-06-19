#!/usr/bin/env bash

sleep 2

echo "atext,Waiting for NIC.. ,Waiting for NIC ..,Waiting for NIC. ." | nc -U /run/tinybox-screen.sock
while ! ip ad | grep -q enp65s0f0np0; do
  sleep 1
done

echo "text,Found NIC" | nc -U /run/tinybox-screen.sock

bash /opt/tinybox/setup/populateraid.sh
sleep 1

echo "text,RAID Populated,Starting ResNet Train" | nc -U /run/tinybox-screen.sock
sleep 1
echo "sleep" | nc -U /run/tinybox-screen.sock

sudo systemctl stop tinychat

if ! bash /opt/tinybox/setup/trainresnet.sh; then
  exit 1
fi

sudo systemctl start tinychat
sleep 30

# check that tinychat is up and working
if ! mods "hi" | grep -q "Hello"; then
  echo "text,tinychat check failed" | nc -U /run/tinybox-screen.sock
  exit 1
fi

sleep 1
echo "text,Provisioning Complete" | nc -U /run/tinybox-screen.sock
sleep 1
