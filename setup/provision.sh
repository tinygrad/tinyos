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

# check maximum temps hit
cpu_max_temp=$(cut -d, -f2 < /home/tiny/stress_test_temps.log | sort -n | tail -n 1)
# declare an array for gpu temps
gpu_max_temps=()
for gpu_id in $(seq 0 5); do
  gpu_max_temps+=("$(cut -d, -f$((gpu_id + 3)) < /home/tiny/stress_test_temps.log | sort -n | tail -n 1)")
done

# split gpu temps into 3 and 3
gpu_max_temps1=$(echo "${gpu_max_temps[@]:0:3}" | tr ' ' ' : ')
gpu_max_temps2=$(echo "${gpu_max_temps[@]:3:3}" | tr ' ' ' : ')
echo "text,${cpu_max_temp},${gpu_max_temps1},${gpu_max_temps2}" | nc -U /run/tinybox-screen.sock

cpu_max_temp=$(echo "$cpu_max_temp" | cut -d. -f1)
if [ "$cpu_max_temp" -gt 90 ] || [ "${gpu_max_temps[0]}" -gt 100 ] || [ "${gpu_max_temps[1]}" -gt 100 ] || [ "${gpu_max_temps[2]}" -gt 100 ] || [ "${gpu_max_temps[3]}" -gt 100 ] || [ "${gpu_max_temps[4]}" -gt 100 ] || [ "${gpu_max_temps[5]}" -gt 100 ]; then
  echo "text,** ${cpu_max_temp} **,${gpu_max_temps1},${gpu_max_temps2}" | nc -U /run/tinybox-screen.sock
  exit 1
fi

sudo systemctl start tinychat
sleep 30
echo "status" | nc -U /run/tinybox-screen.sock

# check that tinychat is up and working
if ! mods "hi" | grep -q "Hello"; then
  echo "text,tinychat check failed" | nc -U /run/tinybox-screen.sock
  exit 1
fi

sleep 1
echo "text,Provisioning Complete" | nc -U /run/tinybox-screen.sock
sleep 1
