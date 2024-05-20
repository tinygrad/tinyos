#!/usr/bin/env bash
set -x

# first disable ssh password authentication
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
systemctl restart sshd

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
usermod -aG lxd tiny
usermod -aG netdev tiny
usermod -aG plugdev tiny
usermod -aG video tiny
usermod -aG render tiny

# set password
echo "tiny:tiny" | chpasswd

# enable running the first setup script
chown tiny:tiny /opt/tinybox/setup/firstsetup.sh
# add to .profile
echo "bash /opt/tinybox/setup/firstsetup.sh" >> /home/tiny/.profile

# if the bmc_password file exists, read the password from it
if [ -f /root/.bmc_password ]; then
  . /root/.bmc_password
else
  # generate a random password for the bmc
  BMC_PASSWORD="$(tr -cd '1234567890!@#$%^&*()-_=+[]{},.<>/?|qwertyuiopasdfghjkl;zxcvbnm' < /dev/random | head -c 12)"
  # write bmc password to file
  echo "BMC_PASSWORD=$BMC_PASSWORD" > /root/.bmc_password
fi

# set the bmc password
ipmitool user set password 2 "$BMC_PASSWORD"
