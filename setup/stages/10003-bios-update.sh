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

# the bios was flashed and a host reboot is needed to apply it
if [[ "$exit_code" -eq 75 ]]; then
  display_text "bios updated, rebooting"
  bash /opt/tinybox/service/power/reboot.sh
  sync
  systemctl reboot
  exit 75
fi

if [[ "$exit_code" -ne 0 ]]; then
  display_text "bios update failed,$(hostname -i | xargs):19531"
  exit 2
fi
