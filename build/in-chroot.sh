#!/usr/bin/env bash
set -xeo pipefail

# enable networking in chroot
mkdir -p /run/systemd/resolve
echo "nameserver 1.1.1.1" > /run/systemd/resolve/stub-resolv.conf

# run in-chroot-pre scripts
scripts=$(find /opt/tinybox/build/in-chroot-pre.d/ -type f -name "*.sh" | sort)
for script in $scripts; do
  bash "$script"
done

# replace /opt/tinybox with the git repo
rm -rf /opt/tinybox
git clone https://github.com/tinygrad/tinyos /opt/tinybox

# merge /opt/tinybox/userspace into /
rsync -ah --info=progress2 /opt/tinybox/userspace/ /
chown -R tiny:tiny /home/tiny/

# run in-chroot-post scripts
scripts=$(find /opt/tinybox/build/in-chroot-post.d/ -type f -name "*.sh" | sort)
for script in $scripts; do
  if [[ $script == *"__user"* ]]; then
    su tiny -c "bash $script"
  else
    bash "$script"
  fi
done

# remove the chroot networking hack
rm -r /run/systemd
