#!/usr/bin/env bash
set -xeo pipefail

source /etc/tinybox-release

if [[ -z "$TINYGRAD_CORE" ]]; then
  pushd /home/tiny

  # install pytorch
  if [[ "$TINYBOX_COLOR" == "red" ]]; then
    pip install --user --break-system-packages torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.3
  elif [[ "$TINYBOX_COLOR" == "green" ]]; then
    pip install --user --break-system-packages torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
  fi

  popd
fi
