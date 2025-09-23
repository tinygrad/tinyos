#!/usr/bin/env bash

source /opt/tinybox/service/display/api.sh

pushd /home/tiny/tinygrad || exit

git fetch origin pull/10799/head:pr-10799
git worktree add /tmp/tinyfs-tinygrad pr-10799

pushd /tmp/tinyfs-tinygrad || exit

iface="$1"
echo "using interface ${iface}"

sudo ip link set "$iface" up
sudo ip link set "$iface" mtu 9000
sudo dhclient -v "$iface"

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
