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
  if ! bash /opt/tinybox/tools/restart_via_bmc.sh; then
    display_text "bios staged,bmc reset failed,flash pending"
    exit 2
  fi
  sync
  exit 75
fi

if [[ "$exit_code" -ne 0 ]]; then
  display_text "bios update failed,$(hostname -i | xargs):19531"
  exit 2
fi
