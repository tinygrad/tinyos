#!/usr/bin/env bash

source /etc/tinybox-release

function has_raid() {
  # tinybox cores do not have raid
  if [[ -n "$TINYBOX_CORE" ]]; then
    return 1
  fi

  # tinybox red v2 does not have raid
  if [[ "$TINYBOX_COLOR" == "red" && "$TINYBOX_VERSION" == "2" ]]; then
    return 1
  fi

  return 0
}

function has_usbboot() {
  # tinybox cores do not boot from usb
  if [[ -n "$TINYBOX_CORE" ]]; then
    return 1
  fi

  # tinybox red v2 does not boot from usb
  if [[ "$TINYBOX_COLOR" == "red" && "$TINYBOX_VERSION" == "2" ]]; then
    return 1
  fi
}

function get_fast_nic() {
  iface=""
  for iface_path in /sys/class/net/*; do
    vendor_file="${iface_path}/device/vendor"
    prod_file="${iface_path}/device/device"
    if [ -r "$vendor_file" ] && [ -r "$prod_file" ]; then
      current_vendor_id=$(cat "$vendor_file" 2>/dev/null)
      current_product_id=$(cat "$prod_file" 2>/dev/null)
      if [ "$current_vendor_id" = "0x15b3" ]; then
        iface=$(basename "$iface_path")
      fi
    fi
  done

  echo "$iface"
}

function should_provision() {
  # if TINYBOX_CORE is set, exit
  if [[ -n "$TINYBOX_CORE" ]]; then
    return 1
  fi

  # determine NIC
  iface=$(get_fast_nic)
  if [ -z "$iface" ]; then
    return 1
  fi

  # see if we can reach a gateway server
  if ! ping -c 5 192.168.52.11; then
    return 1
  fi

  return 0
}
