#!/usr/bin/env bash
set -x

source /etc/tinybox-release
set -e

sleep 2

# check if either enp65s0f0np0, ens33np0, or ens33f0np0 exists
ip_ad=$(ip ad)
if ! echo "$ip_ad" | grep -q "enp65s0f0np0" && ! echo "$ip_ad" | grep -qP "ens\w+np\d" && ! echo "$ip_ad" | grep -qP "ens\dnp\d"; then
  echo "not provisioning, no NICs found"
  exit 0
fi

echo "text,Found NIC" | nc -U /run/tinybox-screen.sock

# determine NIC
set +e
interfaces=$(ip ad | grep -oP 'ens\w+np\d' | sort | uniq)
ip=""
iface=""
for interface in $interfaces; do
  sudo ip ad add 10.0.0.2/24 dev "$interface"
  sudo ip link set "$interface" up
  if ping -c 1 10.0.0.1; then
    echo "text,Using $interface,10.0.0.2" | nc -U /run/tinybox-screen.sock
    ip="10.0.0."
    iface="$interface"
    break
  else
    sudo ip ad del 10.0.0.2/24 dev "$interface"
  fi
  sudo ip ad add 10.0.1.2/24 dev "$interface"
  sudo ip link set "$interface" up
  if ping -c 1 10.0.1.1; then
    echo "text,Using $interface,10.0.1.2" | nc -U /run/tinybox-screen.sock
    ip="10.0.1."
    iface="$interface"
    break
  else
    sudo ip ad del 10.0.1.2/24 dev "$interface"
  fi
done
if [ -z "$ip" ]; then
  echo "text,Failed to setup NIC" | nc -U /run/tinybox-screen.sock
  exit 1
fi
sudo ip link set "$iface" mtu 9000
set -e

# populate raid
if ! bash /opt/tinybox/setup/populateraid.sh "$ip"; then
  echo "text,Failed to populate RAID" | nc -U /run/tinybox-screen.sock
  exit 1
fi
sleep 1

# start stress testing
mkdir -p /home/tiny/stress_test

# run allreduce bandwidth test
pushd /home/tiny/tinygrad || exit
python3 test/external/external_benchmark_multitensor_allreduce.py # run once for warmup
python3 test/external/external_benchmark_multitensor_allreduce.py # run twice for warmup
python3 test/external/external_benchmark_multitensor_allreduce.py | tee /home/tiny/stress_test/allreduce.log
popd || exit
# ensure that it is above 12 GB/s
allreduce_bw=$(grep -oP '  \d+.\d+ GB/s' < /home/tiny/stress_test/allreduce.log | head -n1 | grep -oP '\d+.\d+' | cut -d. -f1)
if [ "$allreduce_bw" -lt 12 ]; then
  echo "text,Allreduce bandwidth test failed" | nc -U /run/tinybox-screen.sock
  exit 1
fi

# on red additionally run rocm-bandwidth-test
if [[ "$TINYBOX_COLOR" == "red" ]]; then
  # run p2p bandwidth test
  /opt/rocm/bin/rocm-bandwidth-test # run once for warmup
  /opt/rocm/bin/rocm-bandwidth-test # run twice for warmup
  /opt/rocm/bin/rocm-bandwidth-test | tee /home/tiny/stress_test/p2p.log
  bi_bw=$(tail -n 20 /home/tiny/stress_test/p2p.log)

  while read -r line; do
    [[ -z "$line" || "$line" =~ ^D/D ]] && continue

    read -ra values <<< "$line"
    values=("${values[@]:1}")

    for i in "${!values[@]}"; do
      value="${values[i]}"

      [[ "$value" == "N/A" ]] && continue

      if [[ -z "$lowest_bandwidth" || "$value" < "$lowest_bandwidth" ]]; then
        lowest_bandwidth="$value"
      fi
    done
  done <<< "$bi_bw"

  # convert to int
  lowest_bandwidth=$(echo "$lowest_bandwidth" | cut -d. -f1)

  # check to ensure that bidirectional bandwidth is above 45
  if [ -z "$lowest_bandwidth" ] || [ "$lowest_bandwidth" -lt 45 ]; then
    echo "text,P2P bandwidth test failed" | nc -U /run/tinybox-screen.sock
    exit 1
  fi
fi

# run pytorch test
pushd /home/tiny/tinygrad || exit
python3 extra/gemm/torch_gemm.py | tee /home/tiny/stress_test/pytorch.log
popd || exit

echo "text,Starting ResNet Train" | nc -U /run/tinybox-screen.sock
sleep 1
echo "status" | nc -U /run/tinybox-screen.sock

sudo systemctl stop tinychat

if [ ! -d "/home/tiny/stress_test/ckpts" ] || [ -f "/tmp/force_resnet_train" ]; then
  if ! bash /opt/tinybox/setup/trainresnet.sh; then
    exit 1
  fi

  # check if we have a resnet checkpoint
  if [ -d "/home/tiny/tinygrad/ckpts" ]; then
    # we have a checkpoint so move it to the stress_test folder
    mv /home/tiny/tinygrad/ckpts /home/tiny/stress_test/
  else
    echo "text,No ResNet Ckpt,Retrying..." | nc -U /run/tinybox-screen.sock
    sleep 1

    if ! bash /opt/tinybox/setup/trainresnet.sh; then
      exit 1
    fi

    # check again if we have a resnet checkpoint
    if [ -d "/home/tiny/tinygrad/ckpts" ]; then
      # we have a checkpoint so move it to the stress_test folder
      mv /home/tiny/tinygrad/ckpts /home/tiny/stress_test/
    else
      echo "text,No ResNet Ckpt" | nc -U /run/tinybox-screen.sock
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
echo "text,${cpu_max_temp},${gpu_max_temps1},${gpu_max_temps2}" | nc -U /run/tinybox-screen.sock

# check if any of the temps are above the threshold
if [ "$cpu_max_temp" -gt 90 ] || [ "${gpu_max_temps[0]}" -gt 95 ] || [ "${gpu_max_temps[1]}" -gt 95 ] || [ "${gpu_max_temps[2]}" -gt 95 ] || [ "${gpu_max_temps[3]}" -gt 95 ] || [ "${gpu_max_temps[4]}" -gt 95 ] || [ "${gpu_max_temps[5]}" -gt 95 ]; then
  echo "text,** ${cpu_max_temp} **,${gpu_max_temps1},${gpu_max_temps2}" | nc -U /run/tinybox-screen.sock
  exit 1
fi

# check that tinychat is up and working
sudo systemctl start tinychat
sleep 10
curl http://127.0.0.1/ctrl/start
echo "status" | nc -U /run/tinybox-screen.sock
sleep 30

mods "hi" | tee /home/tiny/stress_test/tinychat.log
if ! grep -q "Hello" /home/tiny/stress_test/tinychat.log; then
  echo "text,tinychat check failed,retrying..." | nc -U /run/tinybox-screen.sock
  journalctl --unit=tinychat

  mods "hi" | tee /home/tiny/stress_test/tinychat.log
  if ! grep -q "Hello" /home/tiny/stress_test/tinychat.log; then
    echo "text,tinychat check failed" | nc -U /run/tinybox-screen.sock
    exit 1
  fi
fi

# log everything from provisioning
if ! sudo mount -o rdma,port=20049,vers=4.2 "${ip}1":/opt/dmi /mnt; then
  echo "text,Failed to mount NFS" | nc -U /run/tinybox-screen.sock
  exit 1
fi

json_dmi=$(sudo dmidecode | jc --dmidecode)
serial=$(echo "$json_dmi" | jq -r '.[] | select(.description | contains("Base Board Information")) | .values.serial_number' | tr -d '[:space:]')
# ensure there isn't already a folder with this serial
if [ -d "/mnt/${serial}" ]; then
  echo "text,Serial already exists" | nc -U /run/tinybox-screen.sock
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
echo "text,Provisioning Complete" | nc -U /run/tinybox-screen.sock
sleep 1
