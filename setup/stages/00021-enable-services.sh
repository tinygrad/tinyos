#!/usr/bin/env bash
set -xeo pipefail

systemctl enable tinybox-secondboot
systemctl enable autoupdate-tinybox
systemctl enable tinychat
systemctl enable tinybox-setup
