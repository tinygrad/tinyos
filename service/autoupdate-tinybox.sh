#!/usr/bin/env bash
set -x

pushd /opt/tinybox || true

# get the git branch
current_branch=$(git rev-parse --abbrev-ref HEAD)

# reset hard to the current branch not upstream
git reset --hard HEAD

changed=1
git fetch -v --dry-run 2>&1 | grep "$current_branch" | grep -q "up to date" && changed=0

if [ $changed -eq 1 ]; then
  git pull
  systemctl stop displayservice
  systemctl stop buttonservice
  systemctl stop tinychat
fi

# reset hard to origin/<branch> in case pull failed to merge in changes
git reset --hard "origin/$current_branch"

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
    # run the stage
    # and if it succeeds, update the current stage
    if bash "$stage_file" ; then
      echo "$stage" > /etc/tinybox-update-stage
    else
      echo "Failed to run stage $stage"
      break
    fi
  fi
done

systemctl daemon-reload
systemctl start displayservice
systemctl start buttonservice
systemctl start tinychat

popd || true
