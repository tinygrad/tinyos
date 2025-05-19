#!/usr/bin/env bash
set -o pipefail

source /etc/tinybox-release
source /opt/tinybox/service/display/api.sh

function check_gpu() {
  local system_info="$1"

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
    display_text "gpu count mismatch,$gpu_count != $EXPECTED_GPU_COUNT,$gpu_busids"
    exit 2
  fi

  # run program in background to load gpus
  su tiny -c "python3 /opt/tinybox/tinygrad/test/external/external_benchmark_multitensor_allreduce.py" > /dev/null 2>&1 &

  i=0
  for busid in $gpu_busids; do
    display_text "checking gpu $i,$busid"

    link_speed=$(lspci -vv -s "$busid" | grep "LnkSta:" | grep -oP 'Speed ((\d+GT/s)|(\d\.\dGT/s))' | grep -oP '\d+GT/s')
    if [ "$link_speed" != "$EXPECTED_GPU_LINK_SPEED" ]; then
      display_text "gpu $i,$busid,not at $EXPECTED_GPU_LINK_SPEED,at $link_speed"
      exit 2
    fi
    link_width=$(lspci -vv -s "$busid" | grep "LnkSta:" | grep -oP 'Width x\d+' | grep -oP 'x\d+')
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

  # wait for the program to finish
  while pgrep -u tiny python3 > /dev/null; do
    sleep 1
  done

  echo "$gpu_pcie_id"
}

function check_ram() {
  local system_info="$1"
  local gpu_pcie_id="$2"

  # switch on the GPU
  case "$gpu_pcie_id" in
    10de:2b85) # 5090
      EXPECTED_MEMORY_SIZE_GB=192
      ;;
    10de:2684) # 4090
      EXPECTED_MEMORY_SIZE_GB=128
      ;;
    1002:744c) # 7900 XTX
      EXPECTED_MEMORY_SIZE_GB=128
      ;;
    *)
      display_text "unknown gpu,$gpu_pcie_id"
      exit 2
      ;;
  esac

  memory_size=$(echo "$system_info" | jq -r '.. | objects | select(.id == "memory") | .size')
  memory_size_gb=$(echo "$memory_size" | awk '{print int($1/1024/1024/1024)}')
  display_text "found $memory_size_gb gb"

  if [ "$memory_size_gb" -ne "$EXPECTED_MEMORY_SIZE_GB" ]; then
    display_text "memory size mismatch,$memory_size_gb,$EXPECTED_MEMORY_SIZE_GB"
    exit 2
  fi
}

function check_cpu() {
  local system_info="$1"
  local gpu_pcie_id="$2"

  # switch on the GPU
  case "$gpu_pcie_id" in
    10de:2b85) # 5090
      EXPECTED_CORE_COUNT=32
      ;;
    10de:2684) # 4090
      EXPECTED_CORE_COUNT=32
      ;;
    1002:744c) # 7900 XTX
      EXPECTED_CORE_COUNT=32
      ;;
    *)
      display_text "unknown gpu,$gpu_pcie_id"
      exit 2
      ;;
  esac

  core_count=$(echo "$system_info" | jq -r '.. | objects | select(.class == "processor") | .configuration.enabledcores')
  display_text "found $core_count cores"

  if [ "$core_count" -ne "$EXPECTED_CORE_COUNT" ]; then
    display_text "core count mismatch,$core_count != $EXPECTED_CORE_COUNT"
    exit 2
  fi
}

function check_disk() {
  local system_info="$1"
  local gpu_pcie_id="$2"

  # switch on the GPU
  case "$gpu_pcie_id" in
    10de:2b85) # 5090
      EXPECTED_DRIVE_COUNT=4
      EXPECTED_DRIVE_LINK_SPEED="16GT/s"
      EXPECTED_DRIVE_LINK_WIDTH="x4"
      ;;
    10de:2684) # 4090
      EXPECTED_DRIVE_COUNT=4
      EXPECTED_DRIVE_LINK_SPEED="16GT/s"
      EXPECTED_DRIVE_LINK_WIDTH="x4"
      ;;
    1002:744c) # 7900 XTX
      EXPECTED_DRIVE_COUNT=4
      EXPECTED_DRIVE_LINK_SPEED="16GT/s"
      EXPECTED_DRIVE_LINK_WIDTH="x4"
      ;;
    *)
      display_text "unknown gpu,$gpu_pcie_id"
      exit 2
      ;;
  esac

  drive_busids=$(echo "$system_info" | jq -r '.. | objects | select(.class == "disk") | select(.description | . and contains("NVMe")) | select(.businfo | . and contains("nvme")) | .businfo')
  drive_count=$(echo "$drive_busids" | wc -l)
  display_text "found $drive_count drives"

  if [ "$drive_count" -ne "$EXPECTED_DRIVE_COUNT" ]; then
    display_text "drive count mismatch,$drive_count != $EXPECTED_DRIVE_COUNT"
    exit 2
  fi

  i=0
  for busid in $drive_busids; do
    # grab the pcie busid
    nvmeid="$(echo "$busid" | grep -oP '@\d' | grep -oP '\d')"
    busid="$(cat /sys/class/nvme/nvme"$nvmeid"/address)"
    display_text "checking drive $i,$busid"

    link_speed=$(lspci -vv -s "$busid" | grep "LnkCap:" | grep -oP 'Speed \d+GT/s' | grep -oP '\d+GT/s')
    if [ "$link_speed" != "$EXPECTED_DRIVE_LINK_SPEED" ]; then
      display_text "gpu $i,$busid,not at $EXPECTED_DRIVE_LINK_SPEED,at $link_speed"
      exit 2
    fi
    link_width=$(lspci -vv -s "$busid" | grep "LnkCap:" | grep -oP 'Width x\d+' | grep -oP 'x\d+')
    if [ "$link_width" != "$EXPECTED_DRIVE_LINK_WIDTH" ]; then
      display_text "gpu $i,$busid,not at $EXPECTED_DRIVE_LINK_WIDTH,at $link_width"
      exit 2
    fi

    i=$((i + 1))
  done
}

function check_boot() {
  local system_info="$1"
  local gpu_pcie_id="$2"

  speed=$(echo "$system_info" | jq -r '.. | objects | select(.class? == "storage" and (.businfo? | startswith("usb@")) and .configuration.speed?) | .configuration.speed')
  if [ "$speed" != "5000Mbit/s" ]; then
    display_text "usb drive not at 5Gb/s,at $speed"
    exit 2
  fi
}

if [[ -z $TINYBOX_CORE ]]; then
  system_info="$(lshw -json)"

  gpu_pcie_id=$(check_gpu "$system_info")
  if [ $? -ne 0 ]; then
    exit 2
  fi
  if ! check_ram "$system_info" "$gpu_pcie_id"; then
    exit 2
  fi
  if ! check_cpu "$system_info" "$gpu_pcie_id"; then
    exit 2
  fi
  if ! check_disk "$system_info" "$gpu_pcie_id"; then
    exit 2
  fi
  if ! check_boot "$system_info" "$gpu_pcie_id"; then
    exit 2
  fi

  display_text "system check passed"
fi
