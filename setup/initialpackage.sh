#!/usr/bin/env bash

echo "atext,Preparing.. ,Preparing ..,Preparing. ." | nc -U /run/tinybox-screen.sock

git clone https://github.com/tinygrad/tinygrad /home/tiny/tinygrad
chown -R tiny:tiny /home/tiny/tinygrad
