#!/usr/bin/env bash
set -xeo pipefail

source /etc/tinybox-release

systemctl enable autoupdate-tinybox
systemctl enable tinybox-setup

if [[ "$TINYBOX_COLOR" == "red" ]]; then
  systemctl enable tinybox-red-powerlimit
fi
