#!/usr/bin/env bash
set -x

source /etc/tinybox-release
source /opt/tinybox/service/display/api.sh

pushd /home/tiny/tinygrad || exit

git worktree prune
git worktree add -d /tmp/tinygrad 25304c3dd0d2dbf7c20a67a761508f4c885f33ed

pushd /tmp/tinygrad || exit
ln -s /raid/datasets/imagenet extra/datasets/

export PYTHONPATH="."
export MODEL="resnet"

export DEFAULT_FLOAT="HALF"
export LAZYCACHE=0 RESET_STEP=0 IGNORE_OOB=1
export TARGET=0.757

if [[ "$TINYBOX_COLOR" == "green" ]]; then
  NUM_GPUS=$(nvidia-smi -L | wc -l)
  export GPUS=$NUM_GPUS
  export BS=$((256 * NUM_GPUS))
  export EVAL_BS=$((32 * NUM_GPUS))

  export CUDA=1

  export TRAIN_BEAM=4 IGNORE_JIT_FIRST_BEAM=1 BEAM_UOPS_MAX=1500 BEAM_UPCAST_MAX=64 BEAM_LOCAL_MAX=1024 BEAM_MIN_PROGRESS=10 BEAM_PADTO=0
elif [[ "$TINYBOX_COLOR" == "red" ]]; then
  export AMD=1 AM_RESET=1 AMD_IFACE=pci AMD_LLVM=1

  # switch to am driver
  sudo systemctl stop tinybox-display
  sleep 10 && sudo modprobe -r amdgpu

  # restart display to use am_smi
  sleep 10
  sudo systemctl start tinybox-display

  wait_for_display 10
  display "status"

  export GPUS=6 BS=1536 EVAL_BS=192
  export TRAIN_BEAM=4 IGNORE_JIT_FIRST_BEAM=1 BEAM_UOPS_MAX=2000 BEAM_UPCAST_MAX=96 BEAM_LOCAL_MAX=1024 BEAM_MIN_PROGRESS=5 BEAM_PADTO=0
else
  display_text "unknown tinybox color,$TINYBOX_COLOR"
  exit 1
fi

# set seed
export SEED=$RANDOM
export EPOCHS=50

# init
display "status"
BENCHMARK=10 INITMLPERF=1 python3 examples/mlperf/model_train.py

# start temp monitor
bash /opt/tinybox/setup/provision/monitortemps.sh &

# run
START_TIME=$(date +%s)
display "status"
PARALLEL=0 RUNMLPERF=1 EVAL_START_EPOCH=3 EVAL_FREQ=4 python3 examples/mlperf/model_train.py
END_TIME=$(date +%s)

# stop temp monitor
pkill -f monitortemps.sh

# ensure we are within the expected time or under the expected time
if [[ "$TINYBOX_COLOR" == "green" ]]; then
  EXPECTED_TIME=11500
elif [[ "$TINYBOX_COLOR" == "red" ]]; then
  EXPECTED_TIME=14500
else
  echo "Unknown tinybox color: $TINYBOX_COLOR"
  exit 1
fi

time_taken=$((END_TIME - START_TIME))
if [ $time_taken -gt $((EXPECTED_TIME * 105 / 100)) ]; then
  display_text "$(hostname -i | xargs):19531,,ResNet Train Failed,Expected time exceeded,${time_taken}s"
  exit 1
else
  display_text "$(hostname -i | xargs):19531,,ResNet Train Passed,${time_taken}s"
  sleep 1
fi

if [ -d /tmp/tinygrad/ckpts ]; then
  # copy checkpoints to main tinygrad dir
  cp -r /tmp/tinygrad/ckpts /home/tiny/tinygrad/ckpts
fi

popd || exit

unlink /tmp/tinygrad/extra/datasets/imagenet
rm -rf /tmp/tinygrad
git worktree prune

popd || exit
