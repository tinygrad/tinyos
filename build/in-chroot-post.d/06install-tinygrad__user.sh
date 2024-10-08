#!/usr/bin/env bash
set -xeo pipefail

pushd /home/tiny

# clone tinygrad
git clone https://github.com/tinygrad/tinygrad tinygrad

pushd tinygrad

# checkout to specific version
git checkout 9faf20560118c3ff1be34367a7886a768874bb98

# install tinygrad and deps
pip install -e .[testing,linting,docs]
pip install pillow numpy tqdm

# symlink datasets and weights
ln -s /raid/datasets/imagenet extra/datasets/
ln -s /raid/weights ./

popd

popd
