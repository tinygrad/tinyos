#!/usr/bin/env bash
set -exo pipefail

source /etc/tinybox-release
source /opt/tinybox/service/display/api.sh

if [[ -n "$TINYBOX_CORE" ]]; then
  exit 0
fi

# only autoupdate v2 motherboards for now, and skip red v2s
if [[ "$TINYBOX_VERSION" != 2* || "$TINYBOX_COLOR" == "red" ]]; then
  exit 0
fi

display_wtext "checking bmc firmware"

if ! bash /opt/tinybox/tools/update_bmc.sh; then
  display_text "bmc update failed,$(hostname -i | xargs):19531"
  exit 2
fi
