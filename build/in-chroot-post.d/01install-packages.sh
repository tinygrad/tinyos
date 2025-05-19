#!/usr/bin/env bash
set -xeo pipefail

# install gum and mods
apt install gum mods -y

# install nix
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm

# fix terminal
reset
