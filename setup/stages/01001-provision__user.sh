#!/usr/bin/env bash
set -x

source /etc/tinybox-release
source /opt/tinybox/service/display/api.sh
set -e

# if TINYBOX_CORE is set, exit
if [[ -n "$TINYBOX_CORE" ]]; then
  echo "not provisioning, TINYBOX_CORE is set"
  exit 0
fi

# ensure tinychat is up before we bring up the 100 gig interface
sudo systemctl start tinychat

# check if either enp65s0f0np0, ens33np0, or ens33f0np0 exists
ip_ad=$(ip ad)
if ! echo "$ip_ad" | grep -q "enp65s0f0np0" && ! echo "$ip_ad" | grep -qP "ens\w+np\d" && ! echo "$ip_ad" | grep -qP "ens\dnp\d" && ! echo "$ip_ad" | grep -qP "enp\d\ds\dnp\d"; then
  echo "not provisioning, no NICs found"
  exit 0
fi

display_text "found NIC"

# determine NIC
set +e
interfaces=$(ip ad | grep -oP 'ens\w+np\d' | sort | uniq)
ip=""
iface=""
for interface in $interfaces; do
  sudo ip ad add 10.0.0.2/24 dev "$interface"
  sudo ip link set "$interface" up
  if ping -c 1 10.0.0.1; then
    display_text "using $interface,10.0.0.2"
    ip="10.0.0."
    iface="$interface"
    break
  else
    sudo ip ad del 10.0.0.2/24 dev "$interface"
  fi
  sudo ip ad add 10.0.1.2/24 dev "$interface"
  sudo ip link set "$interface" up
  if ping -c 1 10.0.1.1; then
    display_text "using $interface,10.0.1.2"
    ip="10.0.1."
    iface="$interface"
    break
  else
    sudo ip ad del 10.0.1.2/24 dev "$interface"
  fi
done
if [ -z "$ip" ]; then
  interfaces=$(ip ad | grep -oP 'enp\d\ds\dnp\d' | sort | uniq)
  for interface in $interfaces; do
    sudo ip ad add 10.0.0.2/24 dev "$interface"
    sudo ip link set "$interface" up
    if ping -c 1 10.0.0.1; then
      display_text "using $interface,10.0.0.2"
      ip="10.0.0."
      iface="$interface"
      break
    else
      sudo ip ad del 10.0.0.2/24 dev "$interface"
    fi
    sudo ip ad add 10.0.1.2/24 dev "$interface"
    sudo ip link set "$interface" up
    if ping -c 1 10.0.1.1; then
      display_text "using $interface,10.0.1.2"
      ip="10.0.1."
      iface="$interface"
      break
    else
      sudo ip ad del 10.0.1.2/24 dev "$interface"
    fi
  done
  if [ -z "$ip" ]; then
    display_text "$(hostname -i | xargs):19531,,Failed to setup NIC"
    exit 1
  fi
fi
sudo ip link set "$iface" mtu 9000
set -e

# populate raid
if ! bash /opt/tinybox/setup/provision/populateraid.sh "$ip"; then
  display_text "$(hostname -i | xargs):19531,,Failed to populate RAID"
  exit 1
fi
sleep 1

# start stress testing
mkdir -p /home/tiny/stress_test

# run allreduce bandwidth test
pushd /home/tiny/tinygrad || exit
display "status"

# first run will detect gpu failure
if ! python3 test/external/external_benchmark_multitensor_allreduce.py; then
  display_text "$(hostname -i | xargs):19531,,allreduce test failed,check logs for,possible gpu failure"
  exit 1
fi

python3 test/external/external_benchmark_multitensor_allreduce.py # run twice for warmup
python3 test/external/external_benchmark_multitensor_allreduce.py | tee /home/tiny/stress_test/allreduce.log
popd || exit
# ensure that it is above 12 GB/s
allreduce_bw=$(grep -oP '  \d+.\d+ GB/s' < /home/tiny/stress_test/allreduce.log | head -n1 | grep -oP '\d+.\d+' | cut -d. -f1)
if [ "$allreduce_bw" -lt 12 ]; then
  display_text "$(hostname -i | xargs):19531,,Allreduce test failed,${allreduce_bw}GB/s"
  exit 1
fi

# on red additionally run rocm-bandwidth-test
if [[ "$TINYBOX_COLOR" == "red" ]]; then
  # run p2p bandwidth test
  display "status"
  /opt/rocm/bin/rocm-bandwidth-test | tee /home/tiny/stress_test/p2p.log
  /opt/rocm/bin/rocm-bandwidth-test | tee -a /home/tiny/stress_test/p2p.log
  /opt/rocm/bin/rocm-bandwidth-test | tee -a /home/tiny/stress_test/p2p.log
fi

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
    exit 1
  fi

  # check if we have a resnet checkpoint
  if [ -d "/home/tiny/tinygrad/ckpts" ]; then
    # we have a checkpoint so move it to the stress_test folder
    mv /home/tiny/tinygrad/ckpts /home/tiny/stress_test/
  else
    display_text "$(hostname -i | xargs):19531,,resnet train failed,retrying..."
    sleep 1

    if ! bash /opt/tinybox/setup/provision/trainresnet.sh; then
      exit 1
    fi

    # check again if we have a resnet checkpoint
    if [ -d "/home/tiny/tinygrad/ckpts" ]; then
      # we have a checkpoint so move it to the stress_test folder
      mv /home/tiny/tinygrad/ckpts /home/tiny/stress_test/
    else
      display_text "$(hostname -i | xargs):19531,,ResNet Train Failed,No Ckpt"
      exit 1
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
  exit 1
fi

# turn fans to auto
sudo fan-control auto

# log everything from provisioning
if ! sudo mount -o rdma,port=20049 "${ip}1":/opt/dmi /mnt; then
  display_text "$(hostname -i | xargs):19531,,Failed to mount NFS"
  exit 1
fi

json_dmi=$(sudo dmidecode | jc --dmidecode)
serial=$(echo "$json_dmi" | jq -r '.[] | select(.description | contains("Base Board Information")) | .values.serial_number' | tr -d '[:space:]')
# ensure there isn't already a folder with this serial
if [ -d "/mnt/${serial}" ]; then
  display_text "$(hostname -i | xargs):19531,,Serial already exists,${serial}"
  exit 1
fi
mkdir -p "/mnt/${serial}"

# log dmidecode
echo "$json_dmi" > "/mnt/${serial}/dmidecode.json"

# log lshw
sudo lshw -json > "/mnt/${serial}/lshw.json"

# log bmc info
sudo ipmitool bmc info | tee "/mnt/${serial}/bmc_info.log"

cp /var/log/cloud-init-output.log "/mnt/${serial}/cloud-init-output.log"
cp -r /home/tiny/stress_test "/mnt/${serial}/stress_test"

# log provisioning logs
sudo journalctl -o export --unit=provision > "/mnt/${serial}/provision.log"

sudo umount /mnt
sudo ip ad del "${ip}2/24" dev "$iface"

sleep 1
display_text "$(hostname -i | xargs):19531,,Provisioning Complete,${serial}"
sleep 1
