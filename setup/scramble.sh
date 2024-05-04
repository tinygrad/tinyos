#!/usr/bin/env bash

RANDOM_PASSWORD="$(openssl rand -hex 10)"
echo "tiny:$RANDOM_PASSWORD" | chpasswd
passwd --expire tiny
