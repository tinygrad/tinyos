#!/usr/bin/env bash

source /etc/tinybox-release
source /opt/tinybox/setup/common.sh

# check that /raid is a mountpoint
if has_raid; then
  if ! mountpoint -q /raid; then
    echo "/raid is not a mountpoint, exiting"
    exit 1
  fi
fi
