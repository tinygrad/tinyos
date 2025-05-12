#!/usr/bin/env bash
set -xeo pipefail

source /etc/tinybox-release

systemctl enable autoupdate-tinybox
systemctl enable tinybox-setup
