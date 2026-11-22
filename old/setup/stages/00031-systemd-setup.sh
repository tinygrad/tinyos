#!/usr/bin/env bash
set -xeo pipefail

hostnamectl hostname tinybox

timedatectl set-ntp true
