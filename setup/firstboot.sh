#!/usr/bin/env bash
set -xeo pipefail

sleep 5
echo "atext,Preparing.. ,Preparing ..,Preparing. ." | nc -U /run/tinybox-screen.sock
