#!/usr/bin/env bash
set -xe

pushd /home/tiny/tinygrad

# Check which gpus are installed
IS_NVIDIA_GPU=$(lspci | grep -i nvidia)
if [ -z "$IS_NVIDIA_GPU" ]; then
  color="tinybox_red"
else
  color="tinybox_green"
fi

export PYTHONPATH="."
export MODEL="resnet"
export SUBMISSION_PLATFORM="tinybox_$color"

export DEFAULT_FLOAT="HALF" GPUS=6 BS=1536 EVAL_BS=192
export LAZYCACHE=0 RESET_STEP=0

if [ -z "$IS_NVIDIA_GPU" ]; then
  export TRAIN_BEAM=4 IGNORE_JIT_FIRST_BEAM=1 BEAM_UOPS_MAX=2000 BEAM_UPCAST_MAX=96 BEAM_LOCAL_MAX=1024 BEAM_MIN_PROGRESS=5 BEAM_PADTO=0
else
  export TRAIN_BEAM=4 IGNORE_JIT_FIRST_BEAM=1 BEAM_UOPS_MAX=1500 BEAM_UPCAST_MAX=64 BEAM_LOCAL_MAX=1024 BEAM_MIN_PROGRESS=10 BEAM_PADTO=0
fi

export SEED=$RANDOM
DATETIME=$(date "+%m%d%H%M")
LOGFILE="resnet_${color}_${DATETIME}_${SEED}.log"

# init
BENCHMARK=10 INITMLPERF=1 python3 examples/mlperf/model_train.py | tee "$LOGFILE"

# run
START_TIME=$(date +%s)
PARALLEL=0 RUNMLPERF=1 EVAL_START_EPOCH=3 EVAL_FREQ=4 python3 examples/mlperf/model_train.py | tee -a "$LOGFILE"
END_TIME=$(date +%s)

# ensure we are within 5% of the expected time or under the expected time
if [ -z "$IS_NVIDIA_GPU" ]; then
  EXPECTED_TIME=9900
else
  EXPECTED_TIME=7200
fi

if [ $((END_TIME - START_TIME)) -gt $((EXPECTED_TIME * 105 / 100)) ]; then
  echo "text,Stress Test Failed,Expected time exceeded" | nc -U /run/tinybox-screen.sock
  exit 1
else
  echo "text,Stress Test Passed,$((END_TIME - START_TIME))s" | nc -U /run/tinybox-screen.sock
  sleep 1
fi

popd
