#!/usr/bin/env bash

# Check which gpus are installed
IS_NVIDIA_GPU=$(lspci | grep -i nvidia)

if [ -z "$IS_NVIDIA_GPU" ]; then
  echo "AMD GPU found."
  # Install AMD drivers
  mkdir -p -m=0755 /etc/apt/keyrings
  wget https://repo.radeon.com/rocm/rocm.gpg.key -O - | gpg --dearmor | tee /etc/apt/keyrings/rocm.gpg
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/amdgpu/6.1/ubuntu jammy main" | tee /etc/apt/sources.list.d/amdgpu.list
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/6.1 jammy main" | tee --append /etc/apt/sources.list.d/rocm.list
  echo -e 'Package: *\nPin: release o=repo.radeon.com\nPin-Priority: 600' | tee /etc/apt/preferences.d/rocm-pin-600
  apt update -y
  apt install amdgpu-dkms rocm -y
else
  echo "NVIDIA GPU found."
  # Install NVIDIA drivers
fi
