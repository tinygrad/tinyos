#!/usr/bin/env bash
set -x

echo "atext,Updating.. ,Updating ..,Updating. ." | nc -U /run/tinybox-screen.sock

apt update -y
apt upgrade -y
