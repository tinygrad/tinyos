#!/usr/bin/env bash

function main {
  # find our local ip
  local local_ip
  local_ip="$(hostname -I | awk '{print $1}')"

  # change password of tiny to something random
  local random_password
  random_password="$(openssl rand -hex 2)"
  echo "tiny:$random_password" | chpasswd

  echo "text,IP: $local_ip,Password: $random_password" | nc -U /run/tinybox-screen.sock
}

main "$@"
