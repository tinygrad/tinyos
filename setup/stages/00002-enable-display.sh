#!/usr/bin/env bash
set -xeo pipefail

source /etc/tinybox-release

if [[ -z "$TINYBOX_CORE" ]]; then
  systemctl enable tinybox-display
  systemctl enable tinybox-button
  systemctl enable tinybox-poweroff
  systemctl enable tinybox-reboot
fi
