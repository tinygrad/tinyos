#!/usr/bin/env bash
set -x

# Check which gpus are installed
IS_NVIDIA_GPU=$(lspci | grep -i nvidia)

sleep 2

if ! ip ad | grep -q enp65s0f0np0 || ! ip ad | grep -q ens33np0 || ! ip ad | grep -q ens33f0np0; then
  echo "not provisioning, no NICs found"
  exit 0
fi

echo "text,Found NIC" | nc -U /run/tinybox-screen.sock

# determine NIC
interfaces=$(ip ad | grep -oP 'ens33\w+' | sort | uniq)
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

# populate raid
if ! bash /opt/tinybox/setup/populateraid.sh "$ip"; then
  echo "text,Failed to populate RAID" | nc -U /run/tinybox-screen.sock
  exit 1
fi
sleep 1

# start stress testing
mkdir -p /home/tiny/stress_test

# run p2p bandwidth test
if [ -z "$IS_NVIDIA_GPU" ]; then
  /opt/rocm/bin/rocm-bandwidth-test | tee /home/tiny/stress_test/p2p.log
else
  # run allreduce bandwidth test
  pushd /home/tiny/tinygrad || exit
  python3 test/external/external_benchmark_multitensor_allreduce.py | tee /home/tiny/stress_test/allreduce.log
  popd || exit
  # ensure that it is above 12 GB/s
  allreduce_bw=$(grep -oP '  \d+.\d+ GB/s' < /home/tiny/allreduce.log | head -n1 | grep -oP '\d+.\d+' | cut -d. -f1)
  if [ "$allreduce_bw" -lt 12 ]; then
    echo "text,Allreduce bandwidth test failed" | nc -U /run/tinybox-screen.sock
    exit 1
  fi
fi

# run pytorch test
pushd /home/tiny/tinygrad || exit
python3 extra/gemm/torch_gemm.py | tee /home/tiny/stress_test/pytorch.log
popd || exit

echo "text,Starting ResNet Train" | nc -U /run/tinybox-screen.sock
sleep 1
echo "sleep" | nc -U /run/tinybox-screen.sock

sudo systemctl stop tinychat

if ! bash /opt/tinybox/setup/trainresnet.sh; then
  exit 1
fi

# check maximum temps hit
cpu_max_temp=$(cut -d, -f2 < /home/tiny/stress_test/temps.log | sort -n | tail -n 1)
# declare an array for gpu temps
gpu_max_temps=()
for gpu_id in $(seq 0 5); do
  gpu_max_temps+=("$(cut -d, -f$((gpu_id + 3)) < /home/tiny/stress_test/temps.log | sort -n | tail -n 1)")
done

# split gpu temps into 3 and 3
gpu_max_temps1=$(echo "${gpu_max_temps[@]:0:3}" | tr ' ' ' : ')
gpu_max_temps2=$(echo "${gpu_max_temps[@]:3:3}" | tr ' ' ' : ')
echo "text,${cpu_max_temp},${gpu_max_temps1},${gpu_max_temps2}" | nc -U /run/tinybox-screen.sock

cpu_max_temp=$(echo "$cpu_max_temp" | cut -d. -f1)
if [ "$cpu_max_temp" -gt 90 ] || [ "${gpu_max_temps[0]}" -gt 100 ] || [ "${gpu_max_temps[1]}" -gt 100 ] || [ "${gpu_max_temps[2]}" -gt 100 ] || [ "${gpu_max_temps[3]}" -gt 100 ] || [ "${gpu_max_temps[4]}" -gt 100 ] || [ "${gpu_max_temps[5]}" -gt 100 ]; then
  echo "text,** ${cpu_max_temp} **,${gpu_max_temps1},${gpu_max_temps2}" | nc -U /run/tinybox-screen.sock
  exit 1
fi

sudo systemctl start tinychat
sleep 10
curl http://127.0.0.1/ctrl/start
echo "status" | nc -U /run/tinybox-screen.sock
sleep 30

# check that tinychat is up and working
mods "hi" | tee /home/tiny/stress_test/tinychat.log
if ! grep -q "Hello" /home/tiny/stress_test/tinychat.log; then
  echo "text,tinychat check failed" | nc -U /run/tinybox-screen.sock
  exit 1
fi

# log everything from provisioning
if ! sudo mount -o rdma,port=20049,vers=4.2 10.0.0.1:/opt/dmi /mnt; then
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

# log bmc info
sudo ipmitool bmc info | tee "/mnt/${serial}/bmc_info.log"

cp /var/log/cloud-init-output.log "/mnt/${serial}/cloud-init-output.log"
cp -r /home/tiny/stress_test "/mnt/${serial}/stress_test"

# log provisioning logs
sudo journalctl -o export --unit=provision | tee "/mnt/${serial}/provision.log"

sudo umount /mnt
sudo ip ad del "$ip.2" dev "$iface"

sleep 1
echo "text,Provisioning Complete" | nc -U /run/tinybox-screen.sock
sleep 1
