#!/usr/bin/env bash
set -xeo pipefail

source /etc/tinybox-release

if [[ -z "$TINYBOX_CORE" ]]; then
  if [[ "$TINYBOX_COLOR" == "red" ]]; then
    rm -f /etc/apt/keyrings/rocm.gpg
    wget -qO - https://repo.amd.com/rocm/packages-multi-arch/gpg/rocm.gpg | gpg --dearmor --output /etc/apt/keyrings/amdrocm.gpg
    wget -qO - https://repo.radeon.com/rocm/rocm.gpg.key | gpg --dearmor --output /etc/apt/keyrings/rocm.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/amdrocm.gpg] https://repo.amd.com/rocm/packages-multi-arch/ubuntu2404 stable main" | sudo tee /etc/apt/sources.list.d/rocm.list
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/amdgpu/31.40.1/ubuntu noble main" | sudo tee --append /etc/apt/sources.list.d/rocm.list

    apt update -y
    apt install amdgpu-dkms amdrocm-core-sdk7.14 rocm-bandwidth-test -y
  elif [[ "$TINYBOX_COLOR" == "green" ]]; then
    pushd /tmp

    curl -o keyring.deb -L "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb"
    curl -o driver.deb -L "https://github.com/wozeparrot/open-gpu-kernel-modules/releases/download/580.178.04-p2p/nvidia-kernel-source-580-open-0ubuntu1_amd64.deb"

    dpkg -i keyring.deb
    dpkg -i driver.deb

    apt-mark hold nvidia-kernel-source-580-open

    apt update -y
    apt install nvidia-driver-580-open -y
    apt install cuda-toolkit-12-8 cuda-drivers-580 -y
    apt-mark hold nvidia-driver-580-open nvidia-dkms-580-open nvidia-kernel-common-580 cuda-drivers-580 cuda-toolkit-12-8 libnvidia-common-580

    popd
  fi
fi
