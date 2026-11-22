#!/usr/bin/env bash
set -exo pipefail

source /etc/tinybox-release

if [[ -z "$TINYBOX_CORE" ]]; then
  bash /opt/tinybox/setup/setbmcpass.sh "1"

  # set the bmc password
  source /root/.bmc_password
  set +e
  output=$(ipmitool user set password 2 "$BMC_PASSWORD" 2>&1)
  set -e
  # see if 0x19 is in output
  if [[ $output == *"success"* ]]; then
    exit 0
  elif [[ $output == *"0x19"* ]]; then
    # tried to set same password
    exit 0
  else
    echo "Failed to set BMC password, error: $output"
    exit 1
  fi
fi
