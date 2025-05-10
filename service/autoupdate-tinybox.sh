#!/usr/bin/env bash
set -x

pushd /opt/tinybox || true

# get the git branch
current_branch=$(git rev-parse --abbrev-ref HEAD)
# if the branch is HEAD, it's detached so set it to main
if [ "$current_branch" == "HEAD" ]; then
  current_branch="main"
fi

git checkout "$current_branch"

# reset hard to origin/<branch>
git reset --hard "origin/$current_branch"

changed=1
git fetch -v --dry-run 2>&1 | grep "$current_branch" | grep -q "up to date" && changed=0
git status -sb | grep -q "behind" && changed=1
git status -sb | grep -q "ahead" && changed=1

if [ $changed -eq 1 ]; then
  git pull
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
if [ $changed -eq 1 ]; then
  systemctl stop tinybox-display
  systemctl stop tinybox-button
  systemctl stop tinychat
fi
systemctl start tinybox-display
systemctl start tinybox-button
systemctl start tinychat

popd || true
