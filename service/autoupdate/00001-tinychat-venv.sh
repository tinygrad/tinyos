#!/usr/bin/env bash
set -xeo pipefail

pushd /opt/tinybox
source build/venv/bin/activate

pip install tiktoken blobfile bottle
pushd /opt/tinybox/tinygrad
pip install -e .
popd

deactivate
popd
