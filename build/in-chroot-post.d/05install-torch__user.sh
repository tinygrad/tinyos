#!/usr/bin/env bash
set -xeo pipefail

source /etc/tinybox-release

pushd /home/tiny

# install pytorch
if [[ "$TINYBOX_COLOR" == "red" ]]; then
  pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.1
elif [[ "$TINYBOX_COLOR" == "green" ]]; then
  pip install torch torchvision torchaudio
elif [[ "$TINYBOX_COLOR" == "blue" ]]; then
  pip install torch==2.1.0.post3 torchvision==0.16.0.post3 torchaudio==2.1.0.post3 intel-extension-for-pytorch==2.1.40+xpu oneccl_bind_pt==2.1.400+xpu --extra-index-url https://pytorch-extension.intel.com/release-whl/stable/xpu/us/
else
  echo "Unknown tinybox color: $TINYBOX_COLOR"
  exit 1
fi

popd
