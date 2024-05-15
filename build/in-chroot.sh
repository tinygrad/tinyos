#!/usr/bin/env bash
set -xeo pipefail

pushd /tmp

curl -o gum.deb -L "https://github.com/charmbracelet/gum/releases/download/v0.14.0/gum_0.14.0_amd64.deb"
dpkg -i gum.deb

popd
