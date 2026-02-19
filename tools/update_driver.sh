#!/usr/bin/env bash
set -xeo pipefail

source /etc/tinybox-release
export DEBIAN_FRONTEND=noninteractive

if [[ -z "$TINYBOX_CORE" ]]; then
  if [[ "$TINYBOX_COLOR" == "red" ]]; then
    # bump version in /etc/apt/sources.list.d/rocm.list
    sudo sed -i 's/6.3.3/6.4.2/g' /etc/apt/sources.list.d/rocm.list
    sudo sed -i 's/6.4.1/6.4.2/g' /etc/apt/sources.list.d/rocm.list

    if grep -q "6.4.2" /etc/apt/sources.list.d/rocm.list; then
      sudo apt autoremove rocm rocm-core amdgpu-dkms -y
      sudo cat <<EOF | sudo tee /etc/apt/sources.list.d/rocm.list
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/7.0.1 noble main
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/graphics/7.0.1/ubuntu noble main
deb [arch=amd64,i386 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/amdgpu/30.10.1/ubuntu noble main
EOF
    fi

    sudo sed -i 's/7.0.1/7.0.2/g' /etc/apt/sources.list.d/rocm.list
    sudo sed -i 's/30.10.1/30.10.2/g' /etc/apt/sources.list.d/rocm.list

    sudo sed -i 's/7.0.2/7.1/g' /etc/apt/sources.list.d/rocm.list
    sudo sed -i 's/30.10.2/30.20/g' /etc/apt/sources.list.d/rocm.list

    sudo sed -i 's/7.1 /7.1.1 /g' /etc/apt/sources.list.d/rocm.list
    sudo sed -i 's/30.20 /30.20.1 /g' /etc/apt/sources.list.d/rocm.list

    sudo sed -i 's/7.1.1 /7.2 /g' /etc/apt/sources.list.d/rocm.list
    sudo sed -i 's/30.20.1 /30.30 /g' /etc/apt/sources.list.d/rocm.list

    sudo apt update -y
    sudo apt autoremove rocm rocm-core amdgpu-dkms -y
    sudo apt install rocm amdgpu-dkms amdgpu-dkms-firmware -y
  elif [[ "$TINYBOX_COLOR" == "green" ]]; then
    sudo apt autoremove nvidia-driver-570-open nvidia-dkms-570-open nvidia-kernel-common-570 cuda-drivers-570 cuda-toolkit-12-8 libnvidia-common-570 -y
    sudo bash /opt/tinybox/build/in-chroot-post.d/02install-drivers.sh
  fi
fi
