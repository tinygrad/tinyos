#!/usr/bin/env bash
set -x

source /etc/tinybox-release

# disable this service
systemctl disable secondboot.service

if [[ "$TINYBOX_COLOR" == "green" ]]; then
  # enable persistence mode
  nvidia-smi -pm 1
fi

if [ -z "$TINYBOX_PRO" ]; then
  # generate bmc password
  bash /opt/tinybox/setup/setbmcpass.sh "1"

  # start provisioning
  systemctl start provision.service

  # set the bmc password
  source /root/.bmc_password
  ipmitool user set password 2 "$BMC_PASSWORD"
fi
