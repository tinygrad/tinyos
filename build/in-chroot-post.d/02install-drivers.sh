#!/usr/bin/env bash
set -xeo pipefail

source /etc/tinybox-release

if [[ "$TINYBOX_COLOR" == "red" ]]; then
  apt install amdgpu-dkms rocm rocm-bandwidth-test -y
elif [[ "$TINYBOX_COLOR" == "green" ]]; then
  pushd /tmp

  curl -o keyring.deb -L "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb"
  dpkg -i cuda-keyring_1.1-1_all.deb

  curl -o driver.deb -L "https://github.com/tinygrad/open-gpu-kernel-modules/releases/download/550.90.07-p2p/nvidia-kernel-source-550-open-0ubuntu1_amd64.deb"
  dpkg -i driver.deb

  apt update -y
  apt install cuda-toolkit-12-4 nvidia-driver-550-open cuda-drivers-550 -y

  # hold the nvidia driver
  apt-mark hold nvidia-driver-550-open nvidia-dkms-550-open nvidia-kernel-common-550 nvidia-kernel-source-550-open cuda-drivers-550 cuda-toolkit-12-4 libnvidia-common-550
  popd
else
  echo "Unknown tinybox color: $TINYBOX_COLOR"
  exit 1
fi
