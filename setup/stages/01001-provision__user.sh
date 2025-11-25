#!/usr/bin/env bash
set -x

source /etc/tinybox-release
source /opt/tinybox/service/display/api.sh

# if TINYBOX_CORE is set, exit
if [[ -n "$TINYBOX_CORE" ]]; then
  echo "not provisioning, TINYBOX_CORE is set"
  exit 0
fi

# determine NIC
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
if [ -z "$iface" ]; then
  display_text "not provisioning, no NIC found"
  echo "not provisioning,no NIC found"
  exit 0
fi

# see if we can reach a gateway server
if ! ping -c 5 192.168.52.11; then
  display_text "not provisioning,no provisioning IP found"
  exit 0
fi

# populate raid
if ! bash /opt/tinybox/setup/provision/populateraid.sh "$iface"; then
  display_text "$(hostname -i | xargs):19531,,Failed to populate RAID"
  exit 2
fi
sleep 1

# start stress testing
mkdir -p /home/tiny/stress_test

# switch to amd driver
sudo systemctl stop tinybox-display

sudo modprobe amdgpu

# restart display
sleep 10
sudo systemctl start tinybox-display

wait_for_display 10
display "status"

# run pytorch test
pushd /home/tiny/tinygrad || exit
display "status"
python3 extra/gemm/torch_gemm.py | tee /home/tiny/stress_test/pytorch.log
popd || exit

display_wtext "starting resnet train"
sleep 1
display "status"

if [ ! -d "/home/tiny/stress_test/ckpts" ] || [ -f "/tmp/force_resnet_train" ]; then
  if ! bash /opt/tinybox/setup/provision/trainresnet.sh; then
    exit 2
  fi

  # check if we have a resnet checkpoint
  if [ -d "/home/tiny/tinygrad/ckpts" ]; then
    # we have a checkpoint so move it to the stress_test folder
    mv /home/tiny/tinygrad/ckpts /home/tiny/stress_test/
  else
    display_text "$(hostname -i | xargs):19531,,resnet train failed,retrying..."
    sleep 1

    if ! bash /opt/tinybox/setup/provision/trainresnet.sh; then
      exit 2
    fi

    # check again if we have a resnet checkpoint
    if [ -d "/home/tiny/tinygrad/ckpts" ]; then
      # we have a checkpoint so move it to the stress_test folder
      mv /home/tiny/tinygrad/ckpts /home/tiny/stress_test/
    else
      display_text "$(hostname -i | xargs):19531,,ResNet Train Failed,No Ckpt"
      exit 2
    fi
  fi
fi
rm -f /tmp/force_resnet_train

# check maximum temps hit
cpu_max_temp=$(cut -d, -f2 < /home/tiny/stress_test/temps.log | sort -n | tail -n 1 | awk '{print int($1)}')
# declare an array for gpu temps
gpu_max_temps=()
for gpu_id in $(seq 0 5); do
  gpu_max_temps+=("$(cut -d, -f$((gpu_id + 3)) < /home/tiny/stress_test/temps.log | sort -n | tail -n 1)")
done

# split gpu temps into 3 and 3
gpu_max_temps1=$(echo "${gpu_max_temps[@]:0:3}" | tr ' ' ' : ')
gpu_max_temps2=$(echo "${gpu_max_temps[@]:3:3}" | tr ' ' ' : ')
display_text "** ${cpu_max_temp} **,${gpu_max_temps1},${gpu_max_temps2}"

# check if any of the temps are above the threshold
if [ "$cpu_max_temp" -gt 90 ] || [ "${gpu_max_temps[0]}" -gt 95 ] || [ "${gpu_max_temps[1]}" -gt 95 ] || [ "${gpu_max_temps[2]}" -gt 95 ] || [ "${gpu_max_temps[3]}" -gt 95 ] || [ "${gpu_max_temps[4]}" -gt 95 ] || [ "${gpu_max_temps[5]}" -gt 95 ]; then
  display_text "$(hostname -i | xargs):19531,temps too high,** ${cpu_max_temp} **,${gpu_max_temps1},${gpu_max_temps2}"
  exit 2
fi

# turn fans to auto
sudo fan-control auto

# # log everything from provisioning
# if ! sudo mount -o rdma,port=20049 "${ip}1":/opt/dmi /mnt; then
#   display_text "$(hostname -i | xargs):19531,,Failed to mount NFS"
#   exit 2
# fi
#
json_dmi=$(sudo dmidecode | jc --dmidecode)
serial=$(echo "$json_dmi" | jq -r '.[] | select(.description | contains("Base Board Information")) | .values.serial_number' | tr -d '[:space:]')
# # ensure there isn't already a folder with this serial
# if [ -d "/mnt/${serial}" ]; then
#   display_text "$(hostname -i | xargs):19531,,Serial already exists,${serial}"
#   exit 2
# fi
# mkdir -p "/mnt/${serial}"
#
# # log dmidecode
# echo "$json_dmi" > "/mnt/${serial}/dmidecode.json"
#
# # log lshw
# sudo lshw -json > "/mnt/${serial}/lshw.json"
#
# # log bmc info
# sudo ipmitool bmc info | tee "/mnt/${serial}/bmc_info.log"
#
# cp /var/log/cloud-init-output.log "/mnt/${serial}/cloud-init-output.log"
# cp -r /home/tiny/stress_test "/mnt/${serial}/stress_test"
#
# # log provisioning logs
# sudo journalctl -o export --unit=provision > "/mnt/${serial}/provision.log"
#
# sudo umount /mnt
# sudo ip ad del "${ip}2/24" dev "$iface"

sleep 1
display_text "$(hostname -i | xargs):19531,,Provisioning Complete,${serial}"
sleep 1
