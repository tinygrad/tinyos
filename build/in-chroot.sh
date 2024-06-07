#!/usr/bin/env bash
set -xeo pipefail

pushd /tmp

# disable default motd
chmod -x /etc/update-motd.d/*

# install extra packages
dpkg -i /opt/tinybox/build/deps/gum.deb

# symlink tools
ln -s /opt/tinybox/tools/fan-control /usr/local/bin/
ln -s /opt/tinybox/tools/fan-control_completion.sh /etc/bash_completion.d/
ln -s /opt/tinybox/tools/power-limit /usr/local/bin/
ln -s /opt/tinybox/tools/power-limit_completion.sh /etc/bash_completion.d/

# symlink service files
ln -s /opt/tinybox/setup/secondboot.service /etc/systemd/system/
ln -s /opt/tinynbox/service/autoupdate-tinybox.service /etc/systemd/system/
ln -s /opt/tinybox/service/buttonservice.service /etc/systemd/system/
ln -s /opt/tinybox/service/displayservice.service /etc/systemd/system/
ln -s /opt/tinybox/service/poweroff.service /etc/systemd/system/
ln -s /opt/tinybox/service/sleeping.service /etc/systemd/system/
ln -s /opt/tinybox/service/reboot.service /etc/systemd/system/
ln -s /opt/tinybox/service/llmserve.service /etc/systemd/system/

popd
