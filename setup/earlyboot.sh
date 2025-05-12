#!/usr/bin/env bash

source /etc/tinybox-release

if [[ -z "$TINYBOX_CORE" ]]; then
  systemctl enable tinybox-display
  systemctl enable tinybox-button
  systemctl start tinybox-display
  systemctl start tinybox-button
fi

systemctl enable tinybox-setup
