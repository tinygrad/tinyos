#!/usr/bin/env bash
set -xe

source /opt/tinybox/service/display/api.sh
source /opt/tinybox/setup/common.sh

pushd /home/tiny/tinygrad || exit
git fetch

rm -rf /tmp/tinyfs-tinygrad
git worktree prune
git worktree add /tmp/tinyfs-tinygrad 18640f57b282863052291eeac1fe6daadc78c086

pushd /tmp/tinyfs-tinygrad || exit

iface=$(get_fast_nic)
if [ -z "$iface" ]; then
  echo "no fast NIC found"
  exit 1
fi
echo "using interface $iface"

sudo ip link set "$iface" up

cat <<EOF | sudo tee /etc/systemd/network/20-fast.network
[Match]
Name=$iface

[Network]
DHCP=yes

[Link]
MTUBytes=9000
EOF
sudo systemctl restart systemd-networkd

# wait for IP address
while ! ip addr show "$iface" | grep -q "inet "; do
  echo "waiting for IP address on $iface"
  sleep 1
done

# TCP/IP performance tuning
sudo sysctl net.ipv4.tcp_timestamps=0
sudo sysctl net.ipv4.tcp_sack=1
sudo sysctl net.core.netdev_max_backlog=250000
sudo sysctl net.core.rmem_max=4194304
sudo sysctl net.core.wmem_max=4194304
sudo sysctl net.core.rmem_default=4194304
sudo sysctl net.core.wmem_default=4194304
sudo sysctl net.core.optmem_max=4194304
sudo sysctl net.ipv4.tcp_rmem="4096 87380 4194304"
sudo sysctl net.ipv4.tcp_wmem="4096 65536 4194304"
sudo sysctl net.ipv4.tcp_low_latency=1
sudo sysctl net.ipv4.tcp_congestion_control=bbr

sudo chown -R tiny:tiny /raid

function fetch_raid() {
  if has_raid; then
    TINYFS_ENDPOINT=10.0.52.11:6767 PYTHONPATH=. python extra/tinyfs/fetch_raid.py
  else
    TINYFS_ENDPOINT=10.0.52.11:6767 PYTHONPATH=. HASH=6314a042a0850129fb94bd35e901a6e5 LENGTH=158537020 python extra/tinyfs/fetch_raid.py
  fi
}

for i in {1..3}; do
  if fetch_raid; then
    echo "raid fetch succeeded"
    break
  else
    echo "raid fetch failed, retrying..."
    sleep 5
  fi

  if [ "$i" -eq 3 ]; then
    echo "raid fetch failed after 3 attempts, exiting"
    exit 1
  fi
done

sudo chown -R tiny:tiny /raid
