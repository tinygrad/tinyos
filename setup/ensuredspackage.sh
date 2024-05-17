#!/usr/bin/env bash
set -x

# Check which gpus are installed
IS_NVIDIA_GPU=$(lspci | grep -i nvidia)

if [ -n "$IS_NVIDIA_GPU" ]; then
  /opt/tinybox/build/venv/bin/python3 -m pip install nvidia-ml-py
fi
