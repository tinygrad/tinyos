#!/usr/bin/env bash
set -xeo pipefail

source /etc/tinybox-release

pushd /home/tiny

if [[ -z "$TINYBOX_CORE" ]]; then
  # clone tinygrad
  git clone https://github.com/tinygrad/tinygrad tinygrad

  pushd tinygrad

  # install tinygrad and deps
  pip install --user --break-system-packages -e .[testing,linting,docs]
  pip install --user --break-system-packages pillow numpy tqdm

  # symlink datasets and weights
  ln -s /raid/datasets/imagenet extra/datasets/
  ln -s /raid/weights ./

  # setup pci
  sudo bash tinygrad/extra/amdpci/setup_python_cap.sh

  popd

  popd
fi
