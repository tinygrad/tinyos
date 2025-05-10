#!/usr/bin/env bash
set -xeo pipefail

systemctl enable autoupdate-tinybox
systemctl enable tinybox-setup

if [[ -z "$TINYGRAD_CORE" ]]; then
  systemctl enable tinychat
fi
