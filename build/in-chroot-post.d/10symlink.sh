#!/usr/bin/env bash
set -xeo pipefail

# symlink tools
ln -s /opt/tinybox/tools/fan-control /usr/local/bin/
ln -s /opt/tinybox/tools/fan-control_completion.sh /etc/bash_completion.d/
ln -s /opt/tinybox/tools/power-limit /usr/local/bin/
ln -s /opt/tinybox/tools/power-limit_completion.sh /etc/bash_completion.d/

# symlink service files
ln -s /opt/tinybox/setup/secondboot.service /lib/systemd/system/on-secondboot.service
ln -s /opt/tinybox/service/autoupdate-tinybox.service /lib/systemd/system/
ln -s /opt/tinybox/setup/provision.service /lib/systemd/system/
ln -s /opt/tinybox/service/buttonservice.service /lib/systemd/system/
ln -s /opt/tinybox/service/displayservice.service /lib/systemd/system/
ln -s /opt/tinybox/service/poweroff.service /lib/systemd/system/on-poweroff.service
ln -s /opt/tinybox/service/sleeping.service /lib/systemd/system/on-sleeping.service
ln -s /opt/tinybox/service/reboot.service /lib/systemd/system/on-reboot.service
ln -s /opt/tinybox/service/tinychat.service /lib/systemd/system/
