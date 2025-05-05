#!/usr/bin/env bash
set -xeo pipefail

source /etc/tinybox-release

if [[ "$TINYBOX_COLOR" == "red" ]]; then
  wget -qO - https://repo.radeon.com/rocm/rocm.gpg.key | gpg --dearmor --output /etc/apt/keyrings/rocm.gpg
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/amdgpu/6.3.1/ubuntu jammy main" | tee /etc/apt/sources.list.d/rocm.list
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/6.3.1 jammy main" | tee --append /etc/apt/sources.list.d/rocm.list
  echo -e 'Package: *\nPin: release o=repo.radeon.com\nPin-Priority: 600' | tee /etc/apt/preferences.d/rocm-pin-600

  apt update -y
  apt install amdgpu-dkms rocm rocm-bandwidth-test -y
elif [[ "$TINYBOX_COLOR" == "green" ]]; then
  pushd /tmp

  if [[ "$TINYBOX_VERSION" == "1" ]]; then
    curl -o keyring.deb -L "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb"
    curl -o driver.deb -L "https://github.com/tinygrad/open-gpu-kernel-modules/releases/download/550.90.07-p2p/nvidia-kernel-source-550-open-0ubuntu1_amd64.deb"
  elif [[ "$TINYBOX_VERSION" == "2" ]]; then
    curl -o keyring.deb -L "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb"
    curl -o driver.deb -L "https://github.com/tinygrad/open-gpu-kernel-modules/releases/download/570.124.06-p2p/nvidia-kernel-source-570-open-0ubuntu1_amd64.deb"
  fi

  dpkg -i keyring.deb
  dpkg -i driver.deb

  apt update -y
  if [[ "$TINYBOX_VERSION" == "1" ]]; then
    apt install cuda-toolkit-12-4 nvidia-driver-550-open cuda-drivers-550 -y
    apt-mark hold nvidia-driver-550-open nvidia-dkms-550-open nvidia-kernel-common-550 nvidia-kernel-source-550-open cuda-drivers-550 cuda-toolkit-12-4 libnvidia-common-550
  elif [[ "$TINYBOX_VERSION" == "2" ]]; then
    apt install cuda-toolkit-12-8 nvidia-driver-570-open cuda-drivers-570 -y
    apt-mark hold nvidia-driver-570-open nvidia-dkms-570-open nvidia-kernel-common-570 nvidia-kernel-source-570-open cuda-drivers-570 cuda-toolkit-12-8 libnvidia-common-570
  fi

  popd
else
  echo "Unknown tinybox color: $TINYBOX_COLOR"
  exit 1
fi
