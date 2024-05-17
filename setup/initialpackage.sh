#!/usr/bin/env bash
set -x

echo "atext,Preparing.. ,Preparing ..,Preparing. ." | nc -U /run/tinybox-screen.sock

# clone tinygrad
su tiny -c "git clone https://github.com/tinygrad/tinygrad /home/tiny/tinygrad"

# install tinygrad and deps
pushd /home/tiny/tinygrad
su tiny -c "pip install -e ."
su tiny -c "pip install pillow"

# symlink datasets and weights
su tiny -c "ln -s /raid/datasets/imagenet extra/datasets/"
su tiny -c "ln - /raid/weights ./"

popd
