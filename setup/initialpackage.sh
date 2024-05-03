#!/usr/bin/env bash

echo "atext,Preparing.. ,Preparing ..,Preparing. ." | nc -U /run/tinybox-screen.sock

# change to user tiny
su -c tiny git clone https://github.com/tinygrad/tinygrad /home/tiny/tinygrad
pushd /home/tiny/tinygrad
su -c tiny pip install -e .
popd
