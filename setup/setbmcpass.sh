#!/usr/bin/env bash
set -x

# if the bmc_password file exists, read the password from it
if [ -f /root/.bmc_password ]; then
  . /root/.bmc_password
else
  # generate a random password for the bmc
  BMC_PASSWORD="$(tr -dc 'A-Za-z0-9' < /dev/random | head -c 12)"
  # write bmc password to file
  echo "BMC_PASSWORD=$BMC_PASSWORD" > /root/.bmc_password
fi

# set the bmc password
ipmitool user set password 2 "$BMC_PASSWORD"
