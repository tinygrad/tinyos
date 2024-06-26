#!/usr/bin/env bash
set -x

# Check which gpus are installed
IS_NVIDIA_GPU=$(lspci | grep -i nvidia)

if [ -z "$IS_NVIDIA_GPU" ]; then
  echo "AMD GPU found."
else
  echo "NVIDIA GPU found."

  # enable persistence mode
  nvidia-smi -pm 1
fi

# disable this service
systemctl disable on-secondboot.service

# start provisioning
systemctl start provision.service
