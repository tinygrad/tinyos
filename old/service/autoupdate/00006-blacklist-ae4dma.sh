#!/usr/bin/env bash
set -xe

echo "blacklist ae4dma" > /etc/modprobe.d/blacklist-ae4dma.conf
sudo update-initramfs -k all -u
