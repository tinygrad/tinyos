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

# the bios update is staged and the bmc flashes it once the host is off,
# then powers the host back on. shut down gracefully to trigger it
if [[ "$exit_code" -eq 75 ]]; then
  display_text "bios update staged,shutting down"
  sync
  systemctl poweroff
  exit 75
fi

if [[ "$exit_code" -ne 0 ]]; then
  display_text "bios update failed,$(hostname -i | xargs):19531"
  exit 2
fi
