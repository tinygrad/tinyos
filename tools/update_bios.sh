#!/usr/bin/env bash
set -o pipefail

source /etc/tinybox-release

# map the baseboard to the bios version we ship
# min_bmc is the minimum bmc version the asrock update SOP requires before
# flashing the bios (the turin support update is one way, bmc must go first)
board="$(dmidecode -s baseboard-product-name | tr -d '[:space:]')"
case "$board" in
  ROMED16QM3)
    target="3.50"
    zip_name="ROMED16QM3(3.50)ROM.zip"
    min_bmc=""
    ;;
  GENOAD24QM32-2L2T/BCM)
    target="10.08"
    zip_name="GENOAD24QM32-2L2TBCM(10.08)ROM.zip"
    min_bmc="10.11.00"
    ;;
  *)
    echo "unsupported board '$board', skipping bios update"
    exit 0
    ;;
esac

# normalize firmware versions to major.minor without leading zeros for comparison,
# stripping vendor letters since dmidecode may report e.g. L3.42
function norm_ver() { echo "$1" | tr -cd '0-9.' | awk -F. '{printf "%d.%d", $1 + 0, $2 + 0}'; }
target_norm="$(norm_ver "$target")"

current="$(dmidecode -s bios-version | tr -d '[:space:]')"
if [[ -z "$current" ]]; then
  echo "could not read current bios version"
  exit 1
fi
current_norm="$(norm_ver "$current")"
echo "board=$board current=$current target=$target"

# the bios version only changes after a host reboot, so a flash leaves a marker
# behind. if we come back still not at the target, the flash did not apply
stamp=/etc/tinybox-bios-flash-pending

# already at or newer than the target
if [[ "$current_norm" == "$target_norm" ]] || [[ "$(printf '%s\n%s\n' "$target_norm" "$current_norm" | sort -V | head -n1)" == "$target_norm" ]]; then
  echo "bios already up to date"
  rm -f "$stamp"
  exit 0
fi

# we already flashed and rebooted, but the bios did not come back at the target
# version. do not flash in a loop, remove the marker to allow a manual retry
if [[ -f "$stamp" ]]; then
  echo "bios flash to $target did not apply (still at $current), refusing to reflash"
  rm -f "$stamp"
  exit 2
fi

# the bmc must be at the minimum version before the bios is flashed
if [[ -n "$min_bmc" ]]; then
  bmc_version="$(ipmitool bmc info 2>/dev/null | awk -F: '/Firmware Revision/{gsub(/ /, "", $2); print $2}')"
  bmc_norm="$(norm_ver "$bmc_version")"
  min_bmc_norm="$(norm_ver "$min_bmc")"
  if [[ -z "$bmc_norm" || "$(printf '%s\n%s\n' "$min_bmc_norm" "$bmc_norm" | sort -V | head -n1)" != "$min_bmc_norm" ]]; then
    echo "bmc at '$bmc_version', must be at least $min_bmc before flashing bios"
    exit 1
  fi
fi

# find a route to the bmc, retrying while it comes up. the bmc web service can
# take minutes to start after a bmc flash in an earlier stage
bmc_ip=""
for _ in $(seq 1 40); do
  # the bmc's usb host interface (cdc-ether/rndis gadget) gives a point to point link
  for iface_path in /sys/class/net/*; do
    iface="${iface_path##*/}"
    driver="$(ethtool -i "$iface" 2>/dev/null | awk '/^driver:/{print $2}')"
    if [[ "$driver" == "cdc_ether" || "$driver" == "rndis_host" ]]; then
      ip link set dev "$iface" up || true
      ip addr replace 169.254.0.18/16 dev "$iface"
      if curl -skm 5 -o /dev/null "https://169.254.0.17/redfish/v1"; then
        bmc_ip="169.254.0.17"
        echo "using usb host interface $iface"
        break
      fi
    fi
  done

  # fall back to the bmc lan ip
  if [[ -z "$bmc_ip" ]]; then
    lan_ip="$(ipmitool lan print 2>/dev/null | awk -F: '/^IP Address[ ]+/{gsub(/ /, "", $2); print $2; exit}')"
    if [[ -n "$lan_ip" && "$lan_ip" != "0.0.0.0" ]] && curl -skm 5 -o /dev/null "https://$lan_ip/redfish/v1"; then
      bmc_ip="$lan_ip"
      echo "using bmc lan ip $bmc_ip"
    fi
  fi

  if [[ -n "$bmc_ip" ]]; then
    break
  fi
  sleep 15
done

if [[ -z "$bmc_ip" ]]; then
  echo "bmc is not reachable from the host"
  exit 1
fi

# pick working credentials
password=""
candidates=()
if [[ -f /root/.bmc_password ]]; then
  source /root/.bmc_password
  candidates+=("$BMC_PASSWORD")
fi
candidates+=("admin")
for candidate in "${candidates[@]}"; do
  code=$(curl -skm 5 -o /dev/null -w "%{http_code}" -u "admin:$candidate" "https://$bmc_ip/redfish/v1/Managers")
  if [[ "$code" == "200" ]]; then
    password="$candidate"
    break
  else
    echo "credential candidate failed with http $code"
  fi
done
if [[ -z "$password" ]]; then
  echo "no working bmc credentials, response was:"
  curl -skm 5 -i -u "admin:admin" "https://$bmc_ip/redfish/v1/Managers" | head -c 1000
  echo
  exit 1
fi

# download and extract the firmware
# download.asrock.com is hotlink protected, so send a referer, and fall back to the china mirror
workdir="$(mktemp -d)"
http_pid=""
trap 'rm -rf "$workdir"; if [[ -n "$http_pid" ]]; then kill "$http_pid" 2>/dev/null; fi' EXIT
downloaded=0
for url in \
  "https://download.asrock.com/BIOS/Server/$zip_name" \
  "ftp://asrockchina.com.cn/BIOS/Server/$zip_name"; do
  echo "downloading $url"
  if curl -sfL --retry 3 -e "https://www.asrockrack.com/" -o "$workdir/bios.zip" "$url"; then
    downloaded=1
    break
  fi
done
if [[ "$downloaded" -ne 1 ]]; then
  echo "failed to download bios firmware"
  exit 1
fi
python3 -m zipfile -e "$workdir/bios.zip" "$workdir/fw"
ima="$(find "$workdir/fw" -type f \( -iname '*.rom' -o -iname '*.bin' -o -iname '*.ima' \) | head -n1)"
if [[ -z "$ima" ]]; then
  # asrock bios images sometimes have no extension, take the largest file
  ima="$(find "$workdir/fw" -type f -exec ls -S {} + | head -n1)"
fi
if [[ -z "$ima" ]]; then
  echo "no firmware image found in $zip_name"
  exit 2
fi
echo "flashing $ima"

# use the bmc web api, same as the web gui. the gui flow is:
# upload -> configuration {"action":2} (preserve bios configuration)
# -> upgrade {"action":1} (flash after manually shutdown server)
# the bmc then waits for the host to power off, flashes, and powers it back on

# figure out the api prefix, some builds serve the endpoints under /api/asrr
api_prefix="api"
code=$(curl -skm 10 -o /dev/null -w "%{http_code}" -u "admin:$password" "https://$bmc_ip/api/maintenance/BIOS/status")
if [[ "$code" == "404" ]]; then
  api_prefix="api/asrr"
fi

# log in and capture the session cookies and csrf token
login="$(curl -sk -D - -H "Content-Type: application/json" -X POST "https://$bmc_ip/api/session" \
  -d "{\"username\":\"admin\",\"password\":\"$password\"}")"
cookie="$(echo "$login" | grep -io '^Set-Cookie: *[^;]*' | cut -d' ' -f2- | paste -sd'; ' -)"
csrf="$(echo "$login" | grep -io '^X-CSRFTOKEN: *\S*' | cut -d' ' -f2- | tr -d '\r')"
if [[ -z "$cookie" || "$login" != *'"ok"*0'* ]]; then
  echo "could not log in to the bmc web api:"
  echo "$login" | tail -n 20 | head -c 1000
  echo
  exit 1
fi

# upload the image (the bmc web server rejects Expect: 100-continue)
resp="$(curl -sk -H "Expect:" -H "X-CSRFTOKEN: $csrf" -H "Cookie: $cookie" -F "fwimage=@${ima}" \
  "https://$bmc_ip/$api_prefix/maintenance/BIOS/firmware")"
echo "$resp"
if ! echo "$resp" | grep -qE '"(cc|ok)"[ :]*0'; then
  echo "bmc did not accept the bios image upload"
  exit 2
fi

# preserve the bios configuration, then stage the update to flash after the
# host shuts down instead of letting an immediate flash cut power mid boot
resp="$(curl -sk -X POST -H "X-CSRFTOKEN: $csrf" -H "Cookie: $cookie" \
  -H "Content-Type: text/plain;charset=UTF-8" -d '{"action":2}' \
  "https://$bmc_ip/$api_prefix/maintenance/BIOS/configuration")"
echo "$resp"
resp="$(curl -sk -X POST -H "X-CSRFTOKEN: $csrf" -H "Cookie: $cookie" \
  -H "Content-Type: text/plain;charset=UTF-8" -d '{"action":1}' \
  "https://$bmc_ip/$api_prefix/maintenance/BIOS/upgrade")"
echo "$resp"

# update is staged now. the caller reboots the host, the bmc observes the
# shutdown transition, flashes, and the host comes back up on the new bios.
# completion is verified by the bios version check on next boot
touch "$stamp"
echo "bios update staged, host reboot needed for the flash"
exit 75
