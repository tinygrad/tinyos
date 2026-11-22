#!/usr/bin/env bash
set -xeo pipefail

ldconfig
update-initramfs -u
update-pciids
