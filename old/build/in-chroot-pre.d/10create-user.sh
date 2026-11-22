#!/usr/bin/env bash
set -xeo pipefail

# first disable ssh password authentication
mkdir -p /etc/ssh/sshd_config.d
echo "PasswordAuthentication no" >> /etc/ssh/sshd_config.d/password-authentication.conf

# set sudo no password for all users
echo "%sudo ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/sudo

useradd -m -s /bin/bash tiny

# add user to groups
usermod -aG sudo tiny
usermod -aG adm tiny
usermod -aG audio tiny
usermod -aG cdrom tiny
usermod -aG dialout tiny
usermod -aG floppy tiny
usermod -aG netdev tiny
usermod -aG plugdev tiny
usermod -aG video tiny
usermod -aG render tiny

# set password
echo "tiny:tiny" | chpasswd

# add to .profile
echo "bash /opt/tinybox/setup/firstsetup.sh" >> /home/tiny/.profile
