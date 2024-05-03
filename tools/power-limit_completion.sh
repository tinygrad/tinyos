#!/usr/bin/env bash

_power-limit()
{
  local cur prev opts
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  opts="$(seq 100 350)"

  # only complete the first argument
  if [[ ${COMP_CWORD} -eq 1 ]] ; then
    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    return 0
  fi
}

complete -F _power-limit power-limit
