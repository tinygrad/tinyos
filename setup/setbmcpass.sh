#!/usr/bin/env bash
set -x

# generate bmc password
system_info="$(lshw -json)"

# grab serial numbers
baseboard_serial=$(echo "$system_info" | jq -r '.. | objects | select(.id == "core") | .serial')
memory_serials=$(echo "$system_info" | jq -r '.. | objects | select(.id == "memory") | .children[] | .serial | select(. != "Unknown")')
nvme_serials=$(echo "$system_info" | jq -r '.. | objects | select(.id == "nvme") | .serial')
network_serials=$(echo "$system_info" | jq -r '.. | objects | select(.class == "network" and (.vendor | contains("Intel")?)) | .serial')

# join all the serials together with newlines
serials=$(echo -e "$baseboard_serial\n$memory_serials\n$nvme_serials\n$network_serials")

# hash the serials
hash=$(echo "$serials" | sha256sum | cut -d' ' -f1)

# take the first 12 characters of the hash
BMC_PASSWORD=$(echo "$hash" | head -c 12)

# write the bmc password if first arg is set
if [[ -n "$1" ]]; then
  # write bmc password to file
  echo "BMC_PASSWORD=$BMC_PASSWORD" > /root/.bmc_password
else
  # just print the password
  echo "$BMC_PASSWORD"
fi
