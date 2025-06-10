#!/usr/bin/env bash

source /etc/tinybox-release

function has_raid() {
  # tinybox cores do not have raid
  if [[ -z "$TINYBOX_CORE" ]]; then
    return 1
  fi

  # tinybox red v2 does not have raid
  if [[ "$TINYBOX_COLOR" == "red" && "$TINYBOX_VERSION" == "2" ]]; then
    return 1
  fi

  return 0
}
