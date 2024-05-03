#!/usr/bin/env bash

echo "atext,Updating.. ,Updating ..,Updating. ." | nc -U /run/tinybox-screen.sock

apt update -y
apt upgrade -y
