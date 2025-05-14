#!/usr/bin/env bash
set -x

source /etc/tinybox-release
source /opt/tinybox/service/display/api.sh

if [[ -z $TINYBOX_CORE ]]; then
  system_info="$(lshw -json)"

  gpu_busids="$(echo "$system_info" | jq -r '.. | objects | select(.class == "display") | select(.vendor | . and contains("ASPEED") | not) | .businfo | .[4:]')"
  gpu_count=$(echo "$gpu_busids" | wc -l)
  display_text "found $gpu_count gpus"

  # see what kind of gpu we have, get the full pcie id from lspci
  gpu_pcie_ids=$(echo "$gpu_busids" | xargs -I {} lspci -s {} -n | grep -oP '[[:alnum:]][[:alnum:]][[:alnum:]][[:alnum:]]:[[:alnum:]][[:alnum:]][[:alnum:]][[:alnum:]]')

  # verify that all of them are the same
  gpu_pcie_id=$(echo "$gpu_pcie_ids" | sort -u)
  if [ "$(echo "$gpu_pcie_id" | wc -l)" -ne 1 ]; then
    display_text "not all gpus are the same"
    exit 2
  fi

  # switch on the GPU
  case "$gpu_pcie_id" in
    10de:2b85) # 5090
      EXPECTED_GPU_COUNT=4
      EXPECTED_GPU_LINK_SPEED="32GT/s"
      EXPECTED_GPU_LINK_WIDTH="x16"
      ;;
    10de:2684) # 4090
      EXPECTED_GPU_COUNT=6
      EXPECTED_GPU_LINK_SPEED="16GT/s"
      EXPECTED_GPU_LINK_WIDTH="x16"
      ;;
    1002:744c) # 7900 XTX
      EXPECTED_GPU_COUNT=6
      EXPECTED_GPU_LINK_SPEED="16GT/s"
      EXPECTED_GPU_LINK_WIDTH="x16"
      ;;
    *)
      display_text "unknown gpu,$gpu_pcie_id"
      exit 2
      ;;
  esac

  if [ "$gpu_count" -ne $EXPECTED_GPU_COUNT ]; then
    display_text "gpu count mismatch,$gpu_count,$EXPECTED_GPU_COUNT"
    exit 2
  fi

  i=0
  for busid in $gpu_busids; do
    display_text "checking gpu $i,$busid"

    link_speed=$(lspci -vv -s "$busid" | grep "LnkCap:" | grep -oP 'Speed \d+GT/s' | grep -oP '\d+GT/s')
    if [ "$link_speed" != "$EXPECTED_GPU_LINK_SPEED" ]; then
      display_text "gpu $i,$busid,not at $EXPECTED_GPU_LINK_SPEED,at $link_speed"
      exit 2
    fi
    link_width=$(lspci -vv -s "$busid" | grep "LnkCap:" | grep -oP 'Width x\d+' | grep -oP 'x\d+')
    if [ "$link_width" != "$EXPECTED_GPU_LINK_WIDTH" ]; then
      display_text "gpu $i,$busid,not at $EXPECTED_GPU_LINK_WIDTH,at $link_width"
      exit 2
    fi

    # ensure resizable bar is enabled
    if ! lspci -vv -s "$busid" | grep -q "Resizable BAR"; then
      display_text "gpu $i,$busid,rebar not enabled"
      exit 2
    fi

    i=$((i + 1))
  done

  display_text "system check passed"
fi
