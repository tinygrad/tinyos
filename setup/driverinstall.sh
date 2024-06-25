#!/usr/bin/env bash
set -x

NVIDIA_DRIVER_VERSION=550.90.07

echo "atext,Installing Drivers.. ,Installing Drivers ..,Installing Drivers. ." | nc -U /run/tinybox-screen.sock

# Check which gpus are installed
IS_NVIDIA_GPU=$(lspci | grep -i nvidia)

if [ -z "$IS_NVIDIA_GPU" ]; then
  echo "AMD GPU found."
  # Install AMD drivers
  apt install amdgpu-dkms rocm rocm-bandwidth-test -y
  ldconfig
  update-initramfs -u
else
  echo "NVIDIA GPU found."
  # Install NVIDIA drivers

  wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
  dpkg -i cuda-keyring_1.1-1_all.deb
  apt update -y

  # grab the patched p2p driver source
  pushd /tmp
  curl -o driver.deb -L "https://github.com/tinygrad/open-gpu-kernel-modules/releases/download/$NVIDIA_DRIVER_VERSION-p2p/nvidia-kernel-source-550-open-0ubuntu1_amd64.deb"
  dpkg -i driver.deb
  popd

  # install cuda
  apt install cuda-toolkit-12-4 nvidia-driver-550-open cuda-drivers-550 -y

  # hold the nvidia driver
  apt-mark hold nvidia-driver-550-open cuda-drivers-550 cuda-toolkit-12-4
fi
