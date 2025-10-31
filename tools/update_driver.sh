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

    sudo apt update -y
    sudo apt autoremove rocm -y
    sudo apt install rocm amdgpu-dkms -y
  elif [[ "$TINYBOX_COLOR" == "green" ]]; then
    echo "Unsupported Currently"
  fi
fi
