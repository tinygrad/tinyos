#!/usr/bin/env bash
set -xeo pipefail

pushd /home/tiny

# clone tinygrad
git clone https://github.com/tinygrad/tinygrad tinygrad

pushd tinygrad

# install tinygrad and deps
pip install -e .
pip install pillow numpy tqdm

# symlink datasets and weights
ln -s /raid/datasets/imagenet extra/datasets/
ln -s /raid/weights ./

popd

popd
