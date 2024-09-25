#!/usr/bin/env bash
set -xeo pipefail

source /etc/tinybox-release

# symlink tools
ln -s /opt/tinybox/tools/fan-control /usr/local/bin/
ln -s /opt/tinybox/tools/fan-control_completion.sh /etc/bash_completion.d/
ln -s /opt/tinybox/tools/power-limit /usr/local/bin/
ln -s /opt/tinybox/tools/power-limit_completion.sh /etc/bash_completion.d/

# symlink service files
ln -s /opt/tinybox/service/autoupdate-tinybox.service /etc/systemd/system/
ln -s /opt/tinybox/setup/secondboot.service /etc/systemd/system/

if [ -z "$TINYBOX_PRO" ]; then
  ln -s /opt/tinybox/setup/provision.service /etc/systemd/system/
  ln -s /opt/tinybox/service/buttonservice.service /etc/systemd/system/
  ln -s /opt/tinybox/service/displayservice.service /etc/systemd/system/
  ln -s /opt/tinybox/service/poweroff.service /etc/systemd/system/
  ln -s /opt/tinybox/service/reboot.service /etc/systemd/system/
  ln -s /opt/tinybox/service/tinychat.service /etc/systemd/system/
fi
