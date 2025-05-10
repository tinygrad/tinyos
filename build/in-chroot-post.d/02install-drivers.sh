#!/usr/bin/env bash
set -xeo pipefail

source /etc/tinybox-release

if [[ -z "$TINYGRAD_CORE" ]]; then
  if [[ "$TINYBOX_COLOR" == "red" ]]; then
    wget -qO - https://repo.radeon.com/rocm/rocm.gpg.key | gpg --dearmor --output /etc/apt/keyrings/rocm.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/amdgpu/6.3.1/ubuntu noble main" | tee /etc/apt/sources.list.d/rocm.list
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/6.3.1 noble main" | tee --append /etc/apt/sources.list.d/rocm.list
    echo -e 'Package: *\nPin: release o=repo.radeon.com\nPin-Priority: 600' | tee /etc/apt/preferences.d/rocm-pin-600

    apt update -y
    apt install amdgpu-dkms rocm rocm-bandwidth-test -y
  elif [[ "$TINYBOX_COLOR" == "green" ]]; then
    pushd /tmp

    curl -o keyring.deb -L "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb"
    curl -o driver.deb -L "https://github.com/wozeparrot/open-gpu-kernel-modules/releases/download/570.133.20-p2p/nvidia-kernel-source-570-open-0ubuntu1_amd64.deb"

    dpkg -i keyring.deb
    dpkg -i driver.deb

    apt-mark hold nvidia-kernel-source-570-open

    apt update -y
    apt install cuda-toolkit-12-8 nvidia-driver-570-open cuda-drivers-570 -y
    apt-mark hold nvidia-driver-570-open nvidia-dkms-570-open nvidia-kernel-common-570 cuda-drivers-570 cuda-toolkit-12-8 libnvidia-common-570

    popd
  fi
fi
