#!/usr/bin/env bash
set -xeo pipefail

# check if "/home/tiny/.before_firstsetup" doesn't exist
if [ ! -f /home/tiny/.before_firstsetup ]; then
  return
fi

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
    echo "atext,running stage $stage.. ,running stage $stage ..,running stage $stage. ." | nc -U /run/tinybox-screen.sock

    # run the stage
    exit_code=1
    if [[ $stage_file == *"__user"* ]]; then
      exit_code=$(su tiny -c "bash $stage_file")
    else
      exit_code=$(bash "$stage_file")
    fi

    # and if it succeeds, update the current stage
    if [[ $exit_code -eq 0 ]]; then
      echo "$stage" > /etc/tinybox-setup-stage
    else
      echo "text,setup stage failed,$stage,$(hostname -i | xargs):19531" | nc -U /run/tinybox-screen.sock
      failed=1
      break
    fi
  fi
done

if [[ $ran_stage -ne 0 ]] && [[ $failed -eq 0 ]]; then
  echo "text,setup completed" | nc -U /run/tinybox-screen.sock
fi
