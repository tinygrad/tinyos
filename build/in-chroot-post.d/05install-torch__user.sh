#!/usr/bin/env bash
set -xeo pipefail

source /etc/tinybox-release

pushd /home/tiny

# install pytorch
if [[ "$TINYBOX_COLOR" == "red" ]]; then
  pip install --user --break-system-packages torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.3
elif [[ "$TINYBOX_COLOR" == "green" ]]; then
  pip install --user --break-system-packages torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
else
  echo "Unknown tinybox color: $TINYBOX_COLOR"
  exit 1
fi

popd
