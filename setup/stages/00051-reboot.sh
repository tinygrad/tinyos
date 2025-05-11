#!/usr/bin/env bash
set -xeo pipefail

bash /opt/tinybox/service/power/reboot.sh

# manually bump the setup stage
echo "00051" > /etc/tinybox-setup-stage
sync

systemctl reboot

exit 75
