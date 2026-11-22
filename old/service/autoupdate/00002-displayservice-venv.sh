#!/usr/bin/env bash
set -xeo pipefail

pushd /opt/tinybox
source build/venv/bin/activate

pip install pymunk

deactivate
popd
