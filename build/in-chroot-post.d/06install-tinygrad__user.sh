#!/usr/bin/env bash
set -xeo pipefail

pushd /home/tiny

if [[ -z "$TINYGRAD_CORE" ]]; then
  # clone tinygrad
  git clone https://github.com/tinygrad/tinygrad tinygrad

  pushd tinygrad

  # install tinygrad and deps
  pip install --user --break-system-packages -e .[testing,linting,docs]
  pip install --user --break-system-packages pillow numpy tqdm

  # symlink datasets and weights
  ln -s /raid/datasets/imagenet extra/datasets/
  ln -s /raid/weights ./

  popd

  popd
fi
