#!/usr/bin/env bash
set -xeo pipefail

source /etc/tinybox-release

echo "atext,Preparing.. ,Preparing ..,Preparing. ." | nc -U /run/tinybox-screen.sock

if [[ -z "$TINYGRAD_CORE" ]]; then
  systemctl enable tinybox-display
  systemctl enable tinybox-button
  systemctl enable tinybox-poweroff
  systemctl enable tinybox-reboot
fi
