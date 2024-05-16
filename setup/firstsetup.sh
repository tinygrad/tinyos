#!/usr/bin/env bash

function check_cloudinit {
  # check if cloud-init succeeded
  if [[ $(cloud-init status --wait --format json | jq -r '.status') != "done" ]]; then
    gum log -sl error "cloud-init failed to run. Check the user manual for how to proceed."
    exit 1
  fi
}

function set_locale {
  local locales
  locales="$(sed -e '1,6d' /etc/locale.gen | sed 's/^#[ ]*//')"
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

    break
  done
  gum log -sl info "Locale set to $locale."
}

function add_keys {
  local fetch_keys_method
  fetch_keys_method="$(gum choose --header "Where to add SSH keys from?" github paste none)"

  local keys
  if [[ "$fetch_keys_method" == "github" ]]; then
    while true; do
      local github_username
      while true; do
        github_username="$(gum input --header "Github username")"

        if [[ -z "$github_username" ]]; then
          continue
        fi

        # confirm username
        gum confirm "Confirm username: $github_username" && break
      done

      # fetch keys
      keys="$(curl -s "https://github.com/${github_username}.keys")"

      # check if keys were fetched
      if [[ -z "$keys" ]]; then
        gum log -sl warn "No keys found for $github_username."

        # try again?
        gum confirm "Try again?" && continue
        gum log -sl error "Failed to fetch keys from Github."
        break
      fi

      break
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
      gum log -sl info "Keys provided:" keys "$keys"
      gum confirm "Are the keys correct?" && break
    done
  else
    # no keys
    gum log -sl info "Not adding any SSH keys."
    return
  fi
  gum log -sl info "Added $(echo "$keys" | wc -l) SSH keys."
  echo "$keys"
}

function main {
  check_cloudinit
  set_locale
  add_keys
}

main "$@"
