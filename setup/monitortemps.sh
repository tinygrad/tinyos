#!/usr/bin/env bash

LOGFILE="/home/tiny/stress_test_temps.log"
echo "date,cpu_temp,gpu_temps" > "$LOGFILE"

# Check which gpus are installed
IS_NVIDIA_GPU=$(lspci | grep -i nvidia)

while true; do
  cpu_temp=$(sensors -j | jq '.k10temp-pci-00c3.Tctl.temp1_input')

  gpu_temps=""
  if [ -z "$IS_NVIDIA_GPU" ]; then
    gpu_temps=$(sensors -j | jq 'with_entries(select(.key | contains("amdgpu"))) | .[].edge.temp1_input')
  else
    gpu_temps=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)
  fi

  # turn gpu temps into a comma separated list
  gpu_temps=$(echo "$gpu_temps" | tr '\n' ',' | sed 's/,$//')

  echo "$(date),${cpu_temp},${gpu_temps}" >> "$LOGFILE"
done
