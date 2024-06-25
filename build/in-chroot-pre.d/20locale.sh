#!/usr/bin/env bash
set -xeo pipefail

LOCALE="en_US.UTF-8"

locale-gen $LOCALE
update-locale LANG=$LOCALE
localectl set-locale LANG=$LOCALE
