#!/usr/bin/env bash
set -o pipefail

source /etc/tinybox-release

# tinybox cores have no motherboard BMC to update
if [[ -n "$TINYBOX_CORE" ]]; then
  echo "tinybox core, skipping bmc update"
  exit 0
fi

# map the baseboard to the CVE-2024-54085 patched BMC firmware
board="$(dmidecode -s baseboard-product-name | tr -d '[:space:]')"
case "$board" in
  ROMED16QM3)
    target="04.02.00"
    zip_name="ROMED16QM3(04.02.00)BMC.zip"
    ;;
  GENOAD24QM32-2L2T/BCM)
    target="10.11.00"
    zip_name="GENOAD24QM32-2L2TBCM(10.11.00)BMC.zip"
    ;;
  *)
    echo "unsupported board '$board', skipping bmc update"
    exit 0
    ;;
esac

# normalize firmware versions to major.minor without leading zeros for comparison
function norm_ver() { echo "$1" | awk -F. '{printf "%d.%d", $1 + 0, $2 + 0}'; }
target_norm="$(norm_ver "$target")"

current="$(ipmitool bmc info 2>/dev/null | awk -F: '/Firmware Revision/{gsub(/ /, "", $2); print $2}')"
if [[ -z "$current" ]]; then
  echo "could not read current bmc version"
  exit 1
fi
current_norm="$(norm_ver "$current")"
echo "board=$board current=$current target=$target"

# already at or newer than the target
if [[ "$current_norm" == "$target_norm" ]] || [[ "$(printf '%s\n%s\n' "$target_norm" "$current_norm" | sort -V | head -n1)" == "$target_norm" ]]; then
  echo "bmc already up to date"
  exit 0
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
  if curl -sfL --retry 3 -e "https://www.asrockrack.com/" -o "$workdir/bmc.zip" "$url"; then
    downloaded=1
    break
  fi
done
if [[ "$downloaded" -ne 1 ]]; then
  echo "failed to download bmc firmware"
  exit 1
fi
python3 -m zipfile -e "$workdir/bmc.zip" "$workdir/fw"
ima="$(find "$workdir/fw" -iname '*.ima' -o -iname '*.bin' | head -n1)"
if [[ -z "$ima" ]]; then
  echo "no firmware image found in $zip_name"
  exit 2
fi
echo "flashing $ima"

# figure out which update mechanism this bmc supports
usvc="$(curl -skm 10 -u "admin:$password" "https://$bmc_ip/redfish/v1/UpdateService")"
push_uri="$(echo "$usvc" | jq -r '.MultipartHttpPushUri // empty')"
simple_uri="$(echo "$usvc" | jq -r '.Actions["#UpdateService.SimpleUpdate"].target // empty')"

task=""
if [[ -n "$push_uri" ]]; then
  # push the image over redfish
  # the bmc web server rejects Expect: 100-continue, which curl sends on large multipart posts
  echo "using redfish multipart push"
  resp="$(curl -sk -H "Expect:" -u "admin:$password" \
    -F 'UpdateParameters={"Targets":[],"@Redfish.OperationApplyTime":"Immediate"};type=application/json' \
    -F "UpdateFile=@${ima};type=application/octet-stream" \
    "https://$bmc_ip$push_uri")"
  echo "$resp"
  task="$(echo "$resp" | grep -o '/redfish/v1/TaskService/Tasks/[A-Za-z0-9_-]*' | head -n1)"
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
    -d "{\"ImageURI\":\"http://$host_ip:$port/$(basename "$ima")\",\"TransferProtocol\":\"HTTP\"}")"
  echo "$resp"
  task="$(echo "$resp" | grep -o '/redfish/v1/TaskService/Tasks/[A-Za-z0-9_-]*' | head -n1)"
else
  # fall back to the proprietary ami web api that the bmc web ui uses
  echo "using ami web api"
  login="$(curl -sk -D - -H "Content-Type: application/json" -X POST "https://$bmc_ip/api/session" \
    -d "{\"username\":\"admin\",\"password\":\"$password\"}")"
  cookie="$(echo "$login" | grep -io '^Set-Cookie: *[^;]*' | cut -d' ' -f2- | head -n1)"
  csrf="$(echo "$login" | grep -io '^X-CSRFTOKEN: *\S*' | cut -d' ' -f2- | tr -d '\r')"
  if [[ -z "$cookie" ]]; then
    echo "could not log in to the bmc web api; update service reported:"
    echo "$usvc" | head -c 1000
    exit 1
  fi
  resp="$(curl -sk -X PUT -H "X-CSRFTOKEN: $csrf" -H "Cookie: $cookie" -F "fwimage=@${ima}" \
    "https://$bmc_ip/api/maintenance/firmware")"
  echo "$resp"
  for _ in $(seq 1 120); do
    prog="$(curl -skm 10 -H "X-CSRFTOKEN: $csrf" -H "Cookie: $cookie" \
      "https://$bmc_ip/api/maintenance/firmware/flash-progress" 2>/dev/null)"
    pstate="$(echo "$prog" | jq -r '.state // empty' 2>/dev/null)"
    pprog="$(echo "$prog" | jq -r '.progress // empty' 2>/dev/null)"
    if [[ "$pstate" == "2" || "$pprog" == *"100%"* ]]; then
      break
    fi
    sleep 10
  done
  # reboot the bmc to apply the new firmware
  curl -sk -X POST -H "X-CSRFTOKEN: $csrf" -H "Cookie: $cookie" "https://$bmc_ip/api/maintenance/reset"
fi

# wait for the flash to finish
if [[ -n "$task" ]]; then
  for _ in $(seq 1 120); do
    state="$(curl -skm 10 -u "admin:$password" "https://$bmc_ip$task" 2>/dev/null | jq -r '.TaskState // empty')"
    if [[ "$state" == "Completed" ]]; then
      break
    elif [[ -n "$state" && "$state" != "Running" && "$state" != "New" && "$state" != "Starting" && "$state" != "Pending" ]]; then
      echo "bmc flash task failed with state $state"
      exit 2
    fi
    sleep 10
  done
fi

# the bmc reboots after the flash, wait for it to come back (can take several minutes)
for _ in $(seq 1 90); do
  new_version="$(ipmitool bmc info 2>/dev/null | awk -F: '/Firmware Revision/{gsub(/ /, "", $2); print $2}')"
  if [[ -n "$new_version" ]]; then
    break
  fi
  sleep 10
done

if [[ "$(norm_ver "$new_version")" == "$target_norm" ]]; then
  echo "bmc updated to $new_version"
  exit 0
else
  echo "bmc came back at '$new_version', expected '$target'"
  exit 2
fi
