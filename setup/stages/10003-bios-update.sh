#!/usr/bin/env bash
set -exo pipefail

source /etc/tinybox-release
source /opt/tinybox/service/display/api.sh

# only autoupdate v2 motherboards (red v2s, v1s and cores skip)
if [[ -n "$TINYBOX_CORE" ]]; then
  exit 0
fi
if [[ "$(dmidecode -s baseboard-product-name | tr -d '[:space:]')" != "GENOAD24QM32-2L2T/BCM" ]]; then
  exit 0
fi

display_wtext "checking bios firmware"

set +e
bash /opt/tinybox/tools/update_bios.sh
exit_code=$?
set -e

# the bios update is staged; a bmc issued graceful restart contains the
# shutdown transition the bmc needs to start the flash, and brings the host
# back up on the new bios. a host side reboot does not trigger the flash
if [[ "$exit_code" -eq 75 ]]; then
  display_text "bios update staged,restarting via bmc"
  source /root/.bmc_password
  reset_ok=0
  for bmc_addr in 169.254.0.17 "$(ipmitool lan print 2>/dev/null | awk -F: '/^IP Address[ ]+/{gsub(/ /, "", $2); print $2; exit}')"; do
    [[ -z "$bmc_addr" || "$bmc_addr" == "0.0.0.0" ]] && continue
    member="$(curl -skm 10 -u "admin:$BMC_PASSWORD" "https://$bmc_addr/redfish/v1/Systems" | jq -r '.Members[0]["@odata.id"] // empty')"
    rc=$(curl -skm 10 -o /dev/null -w "%{http_code}" -u "admin:$BMC_PASSWORD" \
      -H "Content-Type: application/json" -X POST \
      "https://$bmc_addr${member:-/redfish/v1/Systems/Self}/Actions/ComputerSystem.Reset" \
      -d '{"ResetType":"GracefulRestart"}' 2>/dev/null)
    if [[ "$rc" == "200" || "$rc" == "204" ]]; then
      reset_ok=1
      break
    fi
  done
  if [[ "$reset_ok" -ne 1 ]]; then
    display_text "bios staged, bmc resetfailed,flash pending"
    exit 2
  fi
  sync
  exit 75
fi

if [[ "$exit_code" -ne 0 ]]; then
  display_text "bios update failed,$(hostname -i | xargs):19531"
  exit 2
fi
