#!/usr/bin/env bash
set -x

pushd /opt/tinybox || true

changed=1
git fetch -v --dry-run 2>&1 | grep -q "up to date" && changed=0

if [ $changed -eq 1 ]; then
  git pull
  systemctl daemon-reload
  systemctl stop displayservice
  systemctl stop buttonservice
  systemctl stop tinychat
fi

# check current update stage and see if there are any stages to be run
if [ -f /etc/tinybox-update-stage ]; then
  CURRENT_STAGE=$(cat /etc/tinybox-update-stage)
else
  CURRENT_STAGE=0
fi

# run all stages from the current stage to the latest
stage_files=$(find /opt/tinybox/service/autoupdate/ -type f -name "*.sh" | sort -n)
for stage_file in $stage_files; do
  stage=$(basename "$stage_file" | cut -d'-' -f1)
  if [ "$stage" -gt "$CURRENT_STAGE" ]; then
    bash "$stage_file"
    echo "$stage" > /etc/tinybox-update-stage
  fi
done

systemctl start displayservice
systemctl start buttonservice
systemctl start tinychat

popd || true
