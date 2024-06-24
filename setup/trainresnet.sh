#!/usr/bin/env bash
set -x

pushd /home/tiny/tinygrad || exit

# if we already have a checkpoint saved we can skip training
if [ -d "ckpts" ]; then
  echo "text,skipping training" | nc -U /run/tinybox-screen.sock
  exit 0
fi

export PYTHONPATH="."
export MODEL="resnet"

export DEFAULT_FLOAT="HALF" GPUS=6 BS=1536 EVAL_BS=192
export LAZYCACHE=0 RESET_STEP=0

if [ -z "$IS_NVIDIA_GPU" ]; then
  export TRAIN_BEAM=4 IGNORE_JIT_FIRST_BEAM=1 BEAM_UOPS_MAX=2000 BEAM_UPCAST_MAX=96 BEAM_LOCAL_MAX=1024 BEAM_MIN_PROGRESS=5 BEAM_PADTO=0
else
  export TRAIN_BEAM=4 IGNORE_JIT_FIRST_BEAM=1 BEAM_UOPS_MAX=1500 BEAM_UPCAST_MAX=64 BEAM_LOCAL_MAX=1024 BEAM_MIN_PROGRESS=10 BEAM_PADTO=0
fi

# set seed
export SEED=$RANDOM

# init
BENCHMARK=10 INITMLPERF=1 python3 examples/mlperf/model_train.py

# start temp monitor
bash /opt/tinybox/setup/monitortemps.sh &

# run
START_TIME=$(date +%s)
PARALLEL=0 RUNMLPERF=1 EVAL_START_EPOCH=3 EVAL_FREQ=4 python3 examples/mlperf/model_train.py
END_TIME=$(date +%s)

# stop temp monitor
pkill -f monitortemps.sh

# ensure we are within 5% of the expected time or under the expected time
if [ -z "$IS_NVIDIA_GPU" ]; then
  EXPECTED_TIME=11400
else
  EXPECTED_TIME=9300
fi

if [ $((END_TIME - START_TIME)) -gt $((EXPECTED_TIME * 105 / 100)) ]; then
  echo "text,Stress Test Failed,Expected time exceeded" | nc -U /run/tinybox-screen.sock
  exit 1
else
  echo "text,Stress Test Passed,$((END_TIME - START_TIME))s" | nc -U /run/tinybox-screen.sock
  sleep 1
fi

popd || exit
