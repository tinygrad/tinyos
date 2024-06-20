#!/usr/bin/env bash
set -x

# This script is used to update the tinyos repository
pushd /opt/tinybox || true

changed=1
git fetch -v --dry-run 2>&1 | grep -q "up to date" && changed=0

if [ $changed -eq 1 ]; then
  git pull
  systemctl restart displayservice
  systemctl restart buttonservice
  systemctl restart tinychat
fi

popd || true
