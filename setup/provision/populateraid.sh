#!/usr/bin/env bash
set -xe

source /opt/tinybox/service/display/api.sh

pushd /home/tiny/tinygrad || exit

rm -rf /tmp/tinyfs-tinygrad
git worktree prune
git branch -D pr-10799 || true
git fetch https://github.com/wozeparrot/tinygrad.git tinyfs_device:pr-10799
git worktree add /tmp/tinyfs-tinygrad pr-10799

pushd /tmp/tinyfs-tinygrad || exit

iface="$1"
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

TINYFS_ENDPOINT=10.0.52.11:6767 PYTHONPATH=. python extra/tinyfs/fetch_raid.py

sudo chown -R tiny:tiny /raid
