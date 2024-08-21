#!/usr/bin/env bash

source /etc/tinybox-release

LOGFILE="/home/tiny/stress_test/temps.log"
echo "date,cpu_temp,gpu_temps" > "$LOGFILE"

while true; do
  cpu_temp=$(sensors -j | jq '."k10temp-pci-00c3".Tctl.temp1_input')

  gpu_temps=""
  if [[ "$TINYBOX_COLOR" == "green" ]]; then
    gpu_temps=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)
  elif [[ "$TINYBOX_COLOR" == "red" ]]; then
    gpu_temps=$(sensors -j | jq 'with_entries(select(.key | contains("amdgpu"))) | .[].edge.temp1_input')
  else
    echo "Unknown tinybox color: $TINYBOX_COLOR"
    exit 1
  fi

  # turn gpu temps into a comma separated list
  gpu_temps=$(echo "$gpu_temps" | tr '\n' ',' | sed 's/,$//')

  echo "$(date),${cpu_temp},${gpu_temps}" >> "$LOGFILE"
  sleep 10
  echo "status" | nc -U /run/tinybox-screen.sock
done
