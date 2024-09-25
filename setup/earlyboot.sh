#!/usr/bin/env bash

source /etc/tinybox-release

if [ -z "$TINYBOX_PRO" ]; then
  systemctl enable displayservice
  systemctl enable buttonservice
  systemctl start displayservice
  systemctl start buttonservice
fi
