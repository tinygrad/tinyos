#!/usr/bin/env bash
set -x

source /etc/tinybox-release

pushd /home/tiny/tinygrad || exit

export PYTHONPATH="."
export MODEL="resnet"

export DEFAULT_FLOAT="HALF"
export LAZYCACHE=0 RESET_STEP=0

if [[ "$TINYBOX_COLOR" == "green" ]]; then
  NUM_GPUS=$(nvidia-smi -L | wc -l)
  export GPUS=$NUM_GPUS
  export BS=$((256 * NUM_GPUS))
  export EVAL_BS=$((32 * NUM_GPUS))

  export TRAIN_BEAM=4 IGNORE_JIT_FIRST_BEAM=1 BEAM_UOPS_MAX=1500 BEAM_UPCAST_MAX=64 BEAM_LOCAL_MAX=1024 BEAM_MIN_PROGRESS=10 BEAM_PADTO=0
elif [[ "$TINYBOX_COLOR" == "red" ]]; then
  export GPUS=6 BS=1536 EVAL_BS=192
  export TRAIN_BEAM=4 IGNORE_JIT_FIRST_BEAM=1 BEAM_UOPS_MAX=2000 BEAM_UPCAST_MAX=96 BEAM_LOCAL_MAX=1024 BEAM_MIN_PROGRESS=5 BEAM_PADTO=0
else
  echo "Unknown tinybox color: $TINYBOX_COLOR"
  exit 1
fi

# set seed
export SEED=$RANDOM
export EPOCHS=39

# init
echo "status" | nc -U /run/tinybox-screen.sock
BENCHMARK=10 INITMLPERF=1 python3 examples/mlperf/model_train.py

# start temp monitor
bash /opt/tinybox/setup/provision/monitortemps.sh &

# run
START_TIME=$(date +%s)
echo "status" | nc -U /run/tinybox-screen.sock
PARALLEL=0 RUNMLPERF=1 EVAL_START_EPOCH=3 EVAL_FREQ=4 python3 examples/mlperf/model_train.py
END_TIME=$(date +%s)

# stop temp monitor
pkill -f monitortemps.sh

# ensure we are within the expected time or under the expected time
if [[ "$TINYBOX_COLOR" == "green" ]]; then
  EXPECTED_TIME=9500
elif [[ "$TINYBOX_COLOR" == "red" ]]; then
  EXPECTED_TIME=12500
else
  echo "Unknown tinybox color: $TINYBOX_COLOR"
  exit 1
fi

time_taken=$((END_TIME - START_TIME))
if [ $time_taken -gt $((EXPECTED_TIME * 105 / 100)) ]; then
  echo "text,$(hostname -i | xargs):19531,,ResNet Train Failed,Expected time exceeded,${time_taken}s" | nc -U /run/tinybox-screen.sock
  exit 1
else
  echo "text,$(hostname -i | xargs):19531,,ResNet Train Passed,${time_taken}s" | nc -U /run/tinybox-screen.sock
  sleep 1
fi

popd || exit
