#!/usr/bin/env bash
set -xe

# This script is used to update the tinyos repository
pushd /opt/tinybox

git pull

popd
