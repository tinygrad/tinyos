#!/usr/bin/env bash

function main {
  # see if the password must be changed to see if we are in first setup
  if ! passwd -S tiny | grep "1970"; then
    systemctl disable firstsetup.service
    exit 0
  fi

  # find our local ip
  local local_ip
  local_ip="$(hostname -I | awk '{print $1}')"

  # change password of tiny to something random
  local random_password
  random_password="$(openssl rand -hex 2)"
  echo "tiny:$random_password" | chpasswd
  passwd --expire tiny

  echo "text,IP: $local_ip,Password: $random_password" | nc -U /run/tinybox-screen.sock
}

main "$@"
