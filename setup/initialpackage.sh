#!/usr/bin/env bash
set -x

echo "atext,Preparing.. ,Preparing ..,Preparing. ." | nc -U /run/tinybox-screen.sock

# Check which gpus are installed
IS_NVIDIA_GPU=$(lspci | grep -i nvidia)

# install pytorch
if [ -z "$IS_NVIDIA_GPU" ]; then
  su tiny -c "pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.0"
else
  su tiny -c "pip install torch torchvision torchaudio"
fi

# rebuild the venv
pushd /opt/tinybox || exit
if [ -n "$IS_NVIDIA_GPU" ]; then
  /opt/tinybox/build/venv/bin/python3 -m pip install nvidia-ml-py
fi
popd || exit

# write the correct environment variables for tinychat to function correctly
if [ -z "$IS_NVIDIA_GPU" ]; then
  tee --append /etc/tinychat.env <<EOF
AMD=1
EOF
else
  tee --append /etc/tinychat.env <<EOF
NV=1
EOF
fi
