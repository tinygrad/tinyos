#!/usr/bin/env bash
set -xe

# symlink service files
for service in /opt/tinybox/service/systemd/*.service; do
  service_name=$(basename "$service")
  if [ -e "/etc/systemd/system/$service_name" ]; then
    rm -f "/etc/systemd/system/$service_name"
  fi
  ln -s "$service" "/etc/systemd/system/$service_name"
done
