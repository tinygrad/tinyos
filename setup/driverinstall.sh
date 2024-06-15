#!/usr/bin/env bash
set -x

ROCM_VERSION=6.1.2
NVIDIA_DRIVER_VERSION=550.90.07

echo "atext,Installing Drivers.. ,Installing Drivers ..,Installing Drivers. ." | nc -U /run/tinybox-screen.sock

# Check which gpus are installed
IS_NVIDIA_GPU=$(lspci | grep -i nvidia)

if [ -z "$IS_NVIDIA_GPU" ]; then
  echo "AMD GPU found."
  # Install AMD drivers
  mkdir -p -m=0755 /etc/apt/keyrings
  wget https://repo.radeon.com/rocm/rocm.gpg.key -O - | gpg --dearmor | tee /etc/apt/keyrings/rocm.gpg > /dev/null
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/amdgpu/$ROCM_VERSION/ubuntu jammy main" | tee /etc/apt/sources.list.d/amdgpu.list > /dev/null
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/$ROCM_VERSION jammy main" | tee --append /etc/apt/sources.list.d/rocm.list > /dev/null
  echo -e 'Package: *\nPin: release o=repo.radeon.com\nPin-Priority: 600' | tee /etc/apt/preferences.d/rocm-pin-600 > /dev/null
  apt update -y
  apt install amdgpu-dkms rocm rocm-bandwidth-test -y
  tee --append /etc/ld.so.conf.d/rocm.conf <<EOF
/opt/rocm/lib
/opt/rocm/lib64
EOF
  ldconfig

  # disable cwsr
  cat <<EOF > /etc/modprobe.d/amdgpu.conf
options amdgpu cwsr_enable=0 ppfeaturemask=0xffffffff
EOF

  # update initramfs
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

  # add /usr/local/cuda/bin to the path
  cat <<EOF > /etc/profile.d/cuda.sh
export PATH=\$PATH:/usr/local/cuda/bin
EOF

  # disable unattended-upgrades for nvidia driver
  cat <<EOF > /etc/apt/apt.conf.d/50unattended-upgrades
Unattended-Upgrade::Package-Blacklist {
  "nvidia-*";
  "libnvidia-*";
};
EOF

fi
