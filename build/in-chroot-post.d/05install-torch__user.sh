#!/usr/bin/env bash
set -xeo pipefail

source /etc/tinybox-release

pushd /home/tiny

# install pytorch
if [[ "$TINYBOX_COLOR" == "red" ]]; then
  pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.1
elif [[ "$TINYBOX_COLOR" == "green" ]]; then
  pip install torch torchvision torchaudio
else
  echo "Unknown tinybox color: $TINYBOX_COLOR"
  exit 1
fi

popd
