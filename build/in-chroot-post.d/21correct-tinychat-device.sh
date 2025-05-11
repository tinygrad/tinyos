#!/usr/bin/env bash
set -xeo pipefail

source /etc/tinybox-release

if [[ -z "$TINYBOX_CORE" ]]; then
  if [[ "$TINYBOX_COLOR" == "red" ]]; then
    tee --append /etc/tinychat.env <<EOF
AMD=1
EOF
  elif [[ "$TINYBOX_COLOR" == "green" ]]; then
    tee --append /etc/tinychat.env <<EOF
NV=1
EOF
  fi
fi
