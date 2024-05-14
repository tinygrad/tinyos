#!/usr/bin/env bash
set -x

function main {
  # find our local ip
  local local_ip
  local_ip="$(hostname -I | awk '{print $1}')"

  # find the bmc ip
  local bmc_ip
  bmc_ip="$(ipmitool lan print | grep "IP Address  " | awk '{print $4}')"

  echo "text,IP: $local_ip,BMC: $bmc_ip" | nc -U /run/tinybox-screen.sock
}

main "$@"
