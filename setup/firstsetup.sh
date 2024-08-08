#!/usr/bin/env bash

trap "" SIGINT SIGHUP

NEED_REBOOT=0
OLD_TERM="$TERM"

function check_cloudinit {
  # check if cloud-init succeeded
  while true; do
    if [[ $(cloud-init status --wait --format json | jq -r '.status') != "done" ]]; then
      gum log -sl error "cloud-init failed to run. Check the user manual for how to proceed."
      exit 1
    else
      break
    fi
  done
}

function set_timezone {
  local timezones
  timezones="$(timedatectl list-timezones)"
  readarray -t timezones <<< "$timezones"

  local current_timezone
  current_timezone="$(timedatectl show --property=Timezone --value)"
  gum confirm "Current timezone is $current_timezone. Change?"
  if [[ $? -eq 1 ]]; then
    gum log -sl info "Not changing timezone."
    return
  fi

  local timezone
  while true; do
    timezone="$(gum filter --header "Select a timezone" --placeholder "UTC" "${timezones[@]}")"

    if [[ -z "$timezone" ]]; then
      gum log -sl warn "No timezone selected."
      gum confirm "Try again?" && continue
      gum log -sl error "No timezone selected."
      return
    fi

    # confirm timezone
    gum confirm "Confirm timezone: $timezone" && break
  done

  # set timezone
  sudo timedatectl set-timezone "$timezone"

  gum log -sl info "Timezone set to $timezone."
}

function add_keys {
  local fetch_keys_method
  fetch_keys_method="$(gum choose --header "Where to add SSH keys from?" github gitlab manual none)"
  if [[ $? -eq 1 ]]; then
    return 2
  fi

  local keys
  if [[ "$fetch_keys_method" == "github" ]]; then
    while true; do
      local username
      while true; do
        username="$(gum input --header "Github username")"
        if [[ $? -eq 1 ]]; then
          return 2
        fi

        if [[ -z "$username" ]]; then
          continue
        fi

        # confirm username
        gum confirm "Confirm username: $username" && break
      done

      # fetch keys
      keys="$(gum spin -s jump --title "Fetching keys..." --show-output -- curl -s "https://github.com/${username}.keys")"

      # check if keys were fetched
      if [[ -z "$keys" ]]; then
        gum log -sl warn "No keys found for $username."

        # try again?
        gum confirm "Try again?" && continue
        gum log -sl error "Failed to fetch keys from Github."
        break
      fi

      gum log -sl info "" keys "$keys"
      gum confirm "Are the keys correct?" && break
    done
  elif [[ "$fetch_keys_method" == "gitlab" ]]; then
    while true; do
      local username
      while true; do
        username="$(gum input --header "Gitlab username")"
        if [[ $? -eq 1 ]]; then
          return 2
        fi

        if [[ -z "$username" ]]; then
          continue
        fi

        # confirm username
        gum confirm "Confirm username: $username" && break
      done

      # fetch keys
      keys="$(gum spin -s jump --title "Fetching keys..." --show-output -- curl -s "https://gitlab.com/${username}.keys")"

      # check if keys were fetched
      if [[ -z "$keys" ]]; then
        gum log -sl warn "No keys found for $username."

        # try again?
        gum confirm "Try again?" && continue
        gum log -sl error "Failed to fetch keys from Gitlab."
        break
      fi

      gum log -sl info "" keys "$keys"
      gum confirm "Are the keys correct?" && break
    done
  elif [[ "$fetch_keys_method" == "manual" ]]; then
    local keys
    while true; do
      keys="$(gum write --header "Paste or type your SSH keys one per line. Press Ctrl+D to save and continue." --placeholder "ssh-ed25519...")"
      if [[ $? -eq 1 ]]; then
        return 2
      fi

      if [[ -z "$keys" ]]; then
        gum log -sl warn "No keys provided."
        gum confirm "Try again?" && continue
        gum log -sl error "No keys provided."
        break
      fi

      # confirm keys
      gum log -sl info "" keys "$keys"
      gum confirm "Are the keys correct?" && break
    done
  else
    # no keys
    gum log -sl info "Not adding any SSH keys."
    return
  fi
  gum log -sl info "Added $(echo "$keys" | wc -l) SSH keys."

  mkdir -p "$HOME"/.ssh
  echo "$keys" > "$HOME"/.ssh/authorized_keys
}

function prompt_update {
  gum confirm "Update packages?" && sudo apt update -y && sudo apt upgrade -y
}

function prompt_reboot {
  if [[ $NEED_REBOOT -eq 0 ]]; then
    gum log -sl info "No changes require a reboot."
    return
  fi
  gum log -sl info "Some changes require a reboot."
  gum confirm "Reboot now?" && sudo systemctl reboot
  gum log -sl info "Not rebooting."
}

function main {
  # check if we are logged in over serial
  # and need to force color
  if tty | grep -q "ttyS"; then
    export TERM=xterm-256color
  fi

  check_cloudinit

  set_timezone

  while true; do
    add_keys
    if [[ $? -eq 2 ]]; then
      continue
    fi
    break
  done

  prompt_update

  # remove from .profile
  sed -i '/bash \/opt\/tinybox\/setup\/firstsetup.sh/d' "$HOME"/.profile
  # remove trigger file
  rm -f "$HOME"/.before_firstsetup

  prompt_reboot

  # restore TERM
  export TERM="$OLD_TERM"
}

main "$@"
