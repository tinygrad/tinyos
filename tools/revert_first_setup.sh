#!/usr/bin/env bash

# go back to before first setup
echo "bash /opt/tinybox/setup/firstsetup.sh" >> /home/tiny/.profile
touch /home/tiny/.before_firstsetup
