#!/usr/bin/env bash
set -xeo pipefail

source /etc/tinybox-release

if [[ -z "$TINYBOX_VERSION" ]]; then
  echo "TINYBOX_VERSION=1" | tee --append /etc/tinybox-release
fi
