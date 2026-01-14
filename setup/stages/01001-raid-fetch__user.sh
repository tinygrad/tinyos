#!/usr/bin/env bash
set -x

source /etc/tinybox-release
source /opt/tinybox/service/display/api.sh
source /opt/tinybox/setup/common.sh

if ! should_provision; then
  display_text "skipping provisioning"
  exit 0
fi

# populate raid
if ! bash /opt/tinybox/setup/provision/populateraid.sh; then
  display_text "$(hostname -i | xargs):19531,,failed to populate raid"
  exit 2
fi
