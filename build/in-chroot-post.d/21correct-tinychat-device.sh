#!/usr/bin/env bash
set -xeo pipefail

source /etc/tinybox-release

if [[ "$TINYBOX_COLOR" == "red" ]]; then
  tee --append /etc/tinychat.env <<EOF
AMD=1
EOF
elif [[ "$TINYBOX_COLOR" == "green" ]]; then
  tee --append /etc/tinychat.env <<EOF
NV=1
EOF
elif [[ "$TINYBOX_COLOR" == "blue" ]]; then
  tee --append /etc/tinychat.env <<EOF
GPU=1
INTEL=1
EOF
else
  echo "Unknown tinybox color: $TINYBOX_COLOR"
  exit 1
fi
