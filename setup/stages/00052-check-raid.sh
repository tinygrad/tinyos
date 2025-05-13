#!/usr/bin/env bash

# check that /raid is a mountpoint
if ! mountpoint -q /raid; then
  echo "/raid is not a mountpoint, exiting"
  exit 1
fi
