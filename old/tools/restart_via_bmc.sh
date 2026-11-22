#!/usr/bin/env bash
set -o pipefail

# ask the bmc to gracefully restart the host. use this after staging a bios
# update (tools/update_bios.sh) since a host side reboot does not trigger it
candidates=()
if [[ -f /root/.bmc_password ]]; then
  source /root/.bmc_password
  candidates+=("$BMC_PASSWORD")
fi
candidates+=("admin")

# bring up the bmc usb host interface if present
for iface_path in /sys/class/net/*; do
  iface="${iface_path##*/}"
  driver="$(ethtool -i "$iface" 2>/dev/null | awk '/^driver:/{print $2}')"
  if [[ "$driver" == "cdc_ether" || "$driver" == "rndis_host" ]]; then
    ip link set dev "$iface" up || true
    ip addr replace 169.254.0.18/16 dev "$iface" || true
  fi
done

# find a reachable bmc address with working credentials
bmc_addr=""
password=""
addrs=("169.254.0.17")
lan_ip="$(ipmitool lan print 2>/dev/null | awk -F: '/^IP Address[ ]+/{gsub(/ /, "", $2); print $2; exit}')"
if [[ -n "$lan_ip" && "$lan_ip" != "0.0.0.0" ]]; then
  addrs+=("$lan_ip")
fi
for addr in "${addrs[@]}"; do
  for candidate in "${candidates[@]}"; do
    code=$(curl -skm 5 -o /dev/null -w "%{http_code}" -u "admin:$candidate" "https://$addr/redfish/v1/Systems")
    if [[ "$code" == "200" ]]; then
      bmc_addr="$addr"
      password="$candidate"
      break 2
    fi
  done
done
if [[ -z "$bmc_addr" ]]; then
  echo "bmc is not reachable with working credentials"
  exit 1
fi

member="$(curl -skm 10 -u "admin:$password" "https://$bmc_addr/redfish/v1/Systems" | jq -r '.Members[0]["@odata.id"] // empty')"
sync
# some builds do not implement GracefulRestart, fall back to ForceRestart.
# ForceRestart is not os graceful, but it is bmc issued so the staged bios
# flash runs during the transition and the host comes back up on its own
for reset_type in GracefulRestart ForceRestart; do
  rc=$(curl -skm 10 -o /dev/null -w "%{http_code}" -u "admin:$password" \
    -H "Content-Type: application/json" -X POST \
    "https://$bmc_addr${member:-/redfish/v1/Systems/Self}/Actions/ComputerSystem.Reset" \
    -d "{\"ResetType\":\"$reset_type\"}")
  if [[ "$rc" == "200" || "$rc" == "204" ]]; then
    echo "$reset_type requested, bmc will restart the host and bring it back"
    exit 0
  fi
done
echo "reset request failed with http $rc"
exit 1
