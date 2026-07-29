#!/usr/bin/env bash
set -xeo pipefail

source /etc/tinybox-release

if [[ -z "$TINYBOX_CORE" ]]; then
  if [[ "$TINYBOX_COLOR" == "red" ]]; then
    sudo apt remove --purge -y amdgpu-dkms rocm rocm-bandwidth-test
  elif [[ "$TINYBOX_COLOR" == "green" ]]; then
    sudo apt-mark unhold nvidia-driver-570-open nvidia-dkms-570-open nvidia-kernel-common-570 nvidia-kernel-source-570-open cuda-drivers-570 cuda-toolkit-12-8 libnvidia-common-570
    sudo apt remove --purge -y cuda-toolkit-12-8 cuda-drivers-570 nvidia-driver-570-open nvidia-compute-utils-570 nvidia-persistenced libnvidia-cfg1-570 nvidia-kernel-source-570-open
  fi

  sudo apt autoremove -y
fi
