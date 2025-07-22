#!/usr/bin/env bash
set -xeo pipefail

source /etc/tinybox-release

if [[ -z "$TINYBOX_CORE" ]]; then
  if [[ "$TINYBOX_COLOR" == "red" ]]; then
    # bump version in /etc/apt/sources.list.d/rocm.list
    sudo sed -i 's/6.3.3/6.4.2/g' /etc/apt/sources.list.d/rocm.list
    sudo sed -i 's/6.4.1/6.4.2/g' /etc/apt/sources.list.d/rocm.list

    sudo apt update -y
    sudo apt upgrade -y
  elif [[ "$TINYBOX_COLOR" == "green" ]]; then
    echo "Unsupported Currently"
  fi
fi
