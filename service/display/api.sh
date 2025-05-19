#!/usr/bin/env bash

function display() {
  local command="$1"
  echo "$command" | nc -U /run/tinybox-screen.sock 2>/dev/null || true
}

function display_text() {
  local text="$1"
  display "text,$text"
}

function display_atext() {
  local text="$1"
  display "atext,$text"
}

function display_wtext() {
  local text="$1"
  display_atext "$text.. ,$text ..,$text. ."
}

function display_sleep() {
  local DELAY=$1

  for i in $(seq "$DELAY" -1 1); do
    for s in / - \\ \|; do
      display "text,$s = $i"
      sleep 0.25
    done
  done
}

# wait for display socket with timeout
function wait_for_display() {
  local timeout="$1"
  local elapsed=0
  while [ ! -S /run/tinybox-screen.sock ] && ! nc -zU /run/tinybox-screen.sock; do
    sleep 1
    elapsed=$((elapsed + 1))
    if [ "$elapsed" -ge "$timeout" ]; then
      echo "timed out waiting for display socket, continuing anyway"
      return 0
    fi
  done
  return 0
}
