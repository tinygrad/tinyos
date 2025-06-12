#!/usr/bin/env bash
set -o pipefail

source /etc/tinybox-release

function determine_tinybox_version() {
  # remove existing TINYBOX_VERSION lines
  sed -i '/^TINYBOX_VERSION=/d' /etc/tinybox-release

  # tinybox cores are not versioned
  if [[ -n "$TINYBOX_CORE" ]]; then
    echo "TINYBOX_VERSION=1" | tee -a /etc/tinybox-release
    return
  fi

  system_info="$(lshw -json)"
  gpu_busids="$(echo "$system_info" | jq -r '.. | objects | select(.class == "display") | select(.vendor | . and contains("ASPEED") | not) | .businfo | .[4:]')"

  # see what kind of gpu we have, get the full pcie id from lspci
  gpu_pcie_ids=$(echo "$gpu_busids" | xargs -I {} lspci -s {} -n | grep -oP '[[:alnum:]][[:alnum:]][[:alnum:]][[:alnum:]]:[[:alnum:]][[:alnum:]][[:alnum:]][[:alnum:]]')

  # verify that all of them are the same
  gpu_pcie_id=$(echo "$gpu_pcie_ids" | sort -u)
  if [ "$(echo "$gpu_pcie_id" | wc -l)" -ne 1 ]; then
    display_text "not all gpus are the same"
    exit 2
  fi

  if [[ "$TINYBOX_COLOR" == "red" ]]; then
    case "$gpu_pcie_id" in
      1002:744c) # 7900 XTX
        echo "TINYBOX_VERSION=1" | tee -a /etc/tinybox-release
        ;;
      1002:7550) # 9070 XT
        echo "TINYBOX_VERSION=2" | tee -a /etc/tinybox-release
        ;;
      *)
        display_text "unknown gpu,$gpu_pcie_id,for $TINYBOX_COLOR"
        exit 2
        ;;
    esac
  elif [[ "$TINYBOX_COLOR" == "green" ]]; then
    case "$gpu_pcie_id" in
      10de:2684) # 4090
        echo "TINYBOX_VERSION=1" | tee -a /etc/tinybox-release
        ;;
      10de:2b85) # 5090
        echo "TINYBOX_VERSION=2" | tee -a /etc/tinybox-release
        ;;
      *)
        display_text "unknown gpu,$gpu_pcie_id,for $TINYBOX_COLOR"
        exit 2
        ;;
    esac
  fi
}

if ! determine_tinybox_version; then
  exit 2
fi
