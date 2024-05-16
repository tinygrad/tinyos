#!/usr/bin/env bash

trap "" SIGINT SIGHUP

NEED_REBOOT=0

function check_cloudinit {
  # check if cloud-init succeeded
  if [[ $(cloud-init status --wait --format json | jq -r '.status') != "done" ]]; then
    gum log -sl error "cloud-init failed to run. Check the user manual for how to proceed."
    exit 1
  fi
}

function set_locale {
  local locales
  locales="$(sed -e '1,6d' /etc/locale.gen | sed 's/^#[ ]*//' | sed 's/ .*//')"
  readarray -t locales <<< "$locales"

  local current_locale
  current_locale="$(locale | grep LANG | cut -d= -f2)"

  gum confirm "Current locale is $current_locale. Change?"
  if [[ $? -eq 1 ]]; then
    gum log -sl info "Not changing locale."
    return
  fi

  local locale
  while true; do
    locale="$(gum filter --header "Select a locale" --placeholder "en_US..." "${locales[@]}")"

    if [[ -z "$locale" ]]; then
      gum log -sl warn "No locale selected."
      gum confirm "Try again?" && continue
      gum log -sl error "No locale selected."
      return
    fi

    # confirm locale
    gum confirm "Confirm locale: $locale" && break
  done

  # generate locale
  sudo locale-gen "$locale"
  sudo update-locale LANG="$locale"
  sudo localectl set-locale "LANG=$locale"
  NEED_REBOOT=1

  gum log -sl info "Locale set to $locale."
}

function add_keys {
  local fetch_keys_method
  fetch_keys_method="$(gum choose --header "Where to add SSH keys from?" github gitlab paste none)"

  local keys
  if [[ "$fetch_keys_method" == "github" ]]; then
    while true; do
      local username
      while true; do
        username="$(gum input --header "Github username")"

        if [[ -z "$username" ]]; then
          continue
        fi

        # confirm username
        gum confirm "Confirm username: $username" && break
      done

      # fetch keys
      keys="$(curl -s "https://github.com/${username}.keys")"

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

        if [[ -z "$username" ]]; then
          continue
        fi

        # confirm username
        gum confirm "Confirm username: $username" && break
      done

      # fetch keys
      keys="$(curl -s "https://gitlab.com/${username}.keys")"

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
  elif [[ "$fetch_keys_method" == "paste" ]]; then
    # paste keys
    local keys
    while true; do
      keys="$(gum write --header "Paste your SSH keys one per line. Press Ctrl+D to save and continue." --placeholder "ssh-ed25519...")"

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

  echo "$keys" > "$HOME"/.ssh/authorized_keys
}

function prompt_reboot {
  if [[ $NEED_REBOOT -eq 0 ]]; then
    gum log -sl info "No changes require a reboot."
    return
  fi
  gum log -sl info "Some changes require a reboot."
  gum confirm "Reboot now?" && sudo systemctl reboot
}

function main {
  check_cloudinit
  set_locale
  add_keys
  prompt_reboot
}

main "$@"
