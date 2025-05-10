#!/usr/bin/env bash
set -x

source /etc/tinybox-release

if [[ "$TINYBOX_COLOR" == "green" ]]; then
  # enable persistence mode
  nvidia-smi -pm 1
fi
