#!/usr/bin/env bash
set -xe

# symlink service files
for service in /opt/tinybox/service/systemd/*.service; do
  service_name=$(basename "$service")
  rm -f "/etc/systemd/system/$service_name" || true
  ln -s "$service" "/etc/systemd/system/$service_name"
done
