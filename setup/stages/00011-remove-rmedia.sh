#!/usr/bin/env bash
set -xeu

# parse dmidecode
dmijson=$(dmidecode | jc --dmidecode | jq '.[] | select(.description | contains("Management Controller Host Interface")) | select(.values.host_interface_type == "Network")')

idVendor=$(jq -r '.values.idvendor' <<< "$dmijson" | cut -c 3-6)
idProduct=$(jq -r '.values.idproduct' <<< "$dmijson" | cut -c 3-6)

usbdev=$(rg -l "$idVendor" /sys/bus/usb/devices/*/idVendor | sed 's/\(.*\)\/idVendor/\1/' | xargs -I{} rg -l "$idProduct" {}/idProduct | sed 's/\(.*\)\/idProduct/\1/')
netdev=$(ls "$(find "$usbdev/" -name net)" | head -n1)
if [[ -z "$netdev" ]]; then
  echo "no network device found for $usbdev"
  exit 1
fi
echo "using $netdev"

host_ip=$(jq -r '.values.protocol_id_data | .[] | select(contains("IPv4 Address"))' <<< "$dmijson" | cut -c 15-)
echo "using $host_ip"

ip link set "$netdev" down
ip addr del "$host_ip/24" dev "$netdev" || true
ip addr add "$host_ip/24" dev "$netdev"
ip link set "$netdev" up

dev_ip=$(jq -r '.values.protocol_id_data | .[] | select(contains("IPv4 Redfish Service Address"))' <<< "$dmijson" | cut -c 31-)
echo "using $dev_ip"

set +e
curl -v -k -u admin:tinytiny "https://$dev_ip/redfish/v1/Managers/Self/VirtualMedia/CD1/Actions/VirtualMedia.EjectMedia" -H "Content-Type: application/json" -d '{}'
sleep 1
curl -v -k -u admin:tinytiny "https://$dev_ip/redfish/v1/Managers/Self/VirtualMedia/CD1/Actions/VirtualMedia.EjectMedia" -H "Content-Type: application/json" -d '{}'
set -e

ip link set "$netdev" down
ip addr del "$host_ip/24" dev "$netdev"
