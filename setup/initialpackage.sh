#!/usr/bin/env bash
set -x

echo "atext,Preparing.. ,Preparing ..,Preparing. ." | nc -U /run/tinybox-screen.sock

# change to user tiny
su tiny -c "git clone https://github.com/tinygrad/tinygrad /home/tiny/tinygrad"
pushd /home/tiny/tinygrad
su tiny -c "pip install -e ."
su tiny -c "pip install pillow"
popd
