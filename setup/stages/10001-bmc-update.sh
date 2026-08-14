#!/usr/bin/env bash
set -exo pipefail

source /etc/tinybox-release
source /opt/tinybox/service/display/api.sh

# only autoupdate v2 motherboards (red v2s and v1s skip, cores with a v2 board update)
if [[ "$(dmidecode -s baseboard-product-name)" != "GENOAD24QM32-2L2T/BCM" ]]; then
  exit 0
fi

display_wtext "checking bmc firmware"

if ! bash /opt/tinybox/tools/update_bmc.sh; then
  display_text "bmc update failed,$(hostname -i | xargs):19531"
  exit 2
fi
