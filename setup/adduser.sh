#!/usr/bin/env bash
set -x

# first disable ssh password authentication
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
systemctl restart sshd

adduser tiny --gecos ""

# add user to groups
usermod -aG sudo tiny
usermod -aG adm tiny
usermod -aG audio tiny
usermod -aG cdrom tiny
usermod -aG dialout tiny
usermod -aG floppy tiny
usermod -aG lxd tiny
usermod -aG netdev tiny
usermod -aG plugdev tiny
usermod -aG video tiny
usermod -aG render tiny

# set password
echo "tiny:tiny" | chpasswd
