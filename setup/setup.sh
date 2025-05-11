#!/usr/bin/env bash
set -xeo pipefail

source /opt/tinybox/service/display/api.sh

# check if "/home/tiny/.before_firstsetup" doesn't exist
if [ ! -f /home/tiny/.before_firstsetup ] || [ -f "/tmp/force_setup" ]; then
  exit 0
fi

wait_for_display 10

# check current setup stage and see if there are any stages to be run
if [ -f /etc/tinybox-setup-stage ]; then
  CURRENT_STAGE=$(cat /etc/tinybox-setup-stage)
else
  CURRENT_STAGE=0
fi

# run all stages from the current stage to the latest
ran_stage=0
failed=0
stage_files=$(find /opt/tinybox/setup/stages/ -type f -name "*.sh" | sort -n)
for stage_file in $stage_files; do
  stage=$(basename "$stage_file" | cut -d'-' -f1)
  if [ "$stage" -gt "$CURRENT_STAGE" ]; then
    ran_stage=1
    display_wtext "running stage $stage"

    # run the stage
    exit_code=1
    if [[ $stage_file == *"__user"* ]]; then
      su tiny -c "bash $stage_file"
      exit_code=$?
    else
      bash "$stage_file"
      exit_code=$?
    fi

    # and if it succeeds, update the current stage
    if [[ $exit_code -eq 0 ]]; then
      echo "$stage" > /etc/tinybox-setup-stage
    elif [[ $exit_code -eq 75 ]]; then
      # 75 means we are rebooting, so just exit and wait for system to come up again
      failed=1
      break
    else
      display_text "setup stage failed,$stage,$(hostname -i | xargs):19531"
      failed=1
      break
    fi
  fi
done

if [[ $ran_stage -ne 0 ]] && [[ $failed -eq 0 ]]; then
  display_text "setup completed"
fi
