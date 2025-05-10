#!/usr/bin/env bash
set -xeo pipefail

source /etc/tinybox-release

if [[ -z "$TINYGRAD_CORE" ]]; then
  # symlink tools
  ln -s /opt/tinybox/tools/fan-control /usr/local/bin/
  ln -s /opt/tinybox/tools/fan-control_completion.sh /etc/bash_completion.d/
  ln -s /opt/tinybox/tools/power-limit /usr/local/bin/
  ln -s /opt/tinybox/tools/power-limit_completion.sh /etc/bash_completion.d/

  # symlink service files
  for service in /opt/tinybox/service/systemd/*.service; do
    service_name=$(basename "$service")
    ln -s "$service" "/etc/systemd/system/$service_name"
  done
else
  # just symlink setup service and autoupdate service
  ln -s /opt/tinybox/service/systemd/tinybox-setup.service /etc/systemd/system/
  ln -s /opt/tinybox/service/systemd/autoupdate-tinybox.service /etc/systemd/system/
fi
