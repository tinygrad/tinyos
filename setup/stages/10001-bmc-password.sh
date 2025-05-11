#!/usr/bin/env bash
set -x

source /etc/tinybox-release

if [[ -z "$TINYBOX_CORE" ]]; then
  bash /opt/tinybox/setup/setbmcpass.sh "1"

  # set the bmc password
  source /root/.bmc_password
  ipmitool user set password 2 "$BMC_PASSWORD"
fi
