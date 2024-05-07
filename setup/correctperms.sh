#!/usr/bin/env bash
set -x

if [ "$(stat -c %U /raid)" == "root" ]; then
  chown tiny:tiny /raid
  chmod 777 /raid
fi

chmod +x /usr/bin/fan-control
chmod +x /usr/bin/power-limit
