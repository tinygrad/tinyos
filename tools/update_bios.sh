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

# find the bmc's usb host interface (cdc-ether/rndis gadget) and bring up the point to point link
bmc_ip=""
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
  else
    echo "bmc is not reachable from the host"
    exit 1
  fi
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

# figure out which update mechanism this bmc supports
usvc="$(curl -skm 10 -u "admin:$password" "https://$bmc_ip/redfish/v1/UpdateService")"
push_uri="$(echo "$usvc" | jq -r '.MultipartHttpPushUri // empty')"
simple_uri="$(echo "$usvc" | jq -r '.Actions["#UpdateService.SimpleUpdate"].target // empty')"

# find the bios firmware inventory member to target, if the bmc exposes one
bios_target="$(curl -skm 10 -u "admin:$password" "https://$bmc_ip/redfish/v1/UpdateService/FirmwareInventory" \
  | jq -r '.Members[]?["@odata.id"] // empty' | grep -i bios | head -n1)"
echo "bios target: ${bios_target:-none}"

# the new bios only runs after a host reboot, report that to the caller
function flash_done() {
  echo "bios flashed to $target, reboot the host to apply"
  exit 75
}

task=""
if [[ -n "$push_uri" ]]; then
  # push the image over redfish
  # the bmc web server rejects Expect: 100-continue, which curl sends on large multipart posts
  echo "using redfish multipart push"
  targets_json="[]"
  if [[ -n "$bios_target" ]]; then
    targets_json="[\"$bios_target\"]"
  fi
  # OnReset stages the image and applies it the next time the host powers off,
  # so the flash never interrupts a running machine
  resp="$(curl -sk -H "Expect:" -u "admin:$password" \
    -F "UpdateParameters={\"Targets\":$targets_json,\"@Redfish.OperationApplyTime\":\"OnReset\"};type=application/json" \
    -F 'OemParameters={"ImageType":"BIOS"};type=application/json' \
    -F "UpdateFile=@${ima};type=application/octet-stream" \
    "https://$bmc_ip$push_uri")"
  echo "$resp"
  task="$(echo "$resp" | grep -o '/redfish/v1/TaskService/Tasks/[A-Za-z0-9_-]*' | head -n1)"
  if [[ -z "$task" ]]; then
    echo "bmc did not accept the bios update"
    exit 2
  fi
  touch "$stamp"
elif [[ -n "$simple_uri" ]]; then
  # serve the image over http on the host and have the bmc pull it
  echo "using redfish simpleupdate"
  if [[ "$bmc_ip" == "169.254.0.17" ]]; then
    host_ip="169.254.0.18"
  else
    host_ip="$(ip route get "$bmc_ip" | grep -oP 'src \K\S+' | head -n1)"
  fi
  port=8471
  python3 -m http.server "$port" --bind "$host_ip" --directory "$(dirname "$ima")" >/dev/null 2>&1 &
  http_pid="$!"
  sleep 1
  resp="$(curl -sk -H "Content-Type: application/json" -u "admin:$password" \
    -X POST "https://$bmc_ip$simple_uri" \
    -d "{\"ImageURI\":\"http://$host_ip:$port/$(basename "$ima")\",\"TransferProtocol\":\"HTTP\",\"@Redfish.OperationApplyTime\":\"OnReset\"}")"
  echo "$resp"
  task="$(echo "$resp" | grep -o '/redfish/v1/TaskService/Tasks/[A-Za-z0-9_-]*' | head -n1)"
  if [[ -z "$task" ]]; then
    echo "bmc did not accept the bios update"
    exit 2
  fi
  touch "$stamp"
else
  # do not fall back to the proprietary ami web api: its bios flash action
  # cannot be confirmed to stage the update for the next power off, and it may
  # power the host off to flash. only deferred apply is safe here
  echo "bmc supports no redfish update mechanism for bios, not flashing"
  exit 1
fi

# wait for the flash to finish
if [[ -n "$task" ]]; then
  for _ in $(seq 1 120); do
    state="$(curl -skm 10 -u "admin:$password" "https://$bmc_ip$task" 2>/dev/null | jq -r '.TaskState // empty')"
    if [[ "$state" == "Completed" ]]; then
      break
    elif [[ -n "$state" && "$state" != "Running" && "$state" != "New" && "$state" != "Starting" && "$state" != "Pending" ]]; then
      echo "bios flash task failed with state $state"
      rm -f "$stamp"
      exit 2
    fi
    sleep 10
  done
fi

flash_done
