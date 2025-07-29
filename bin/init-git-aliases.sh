#!/bin/bash

script_dir=$(dirname $0)
root_dir=$(echo $script_dir | perl -pe 's/^(.+)\/bin.*$/$1/g')

source "$root_dir/shared/alias.sh"

function initAliases() {
  writeLog "$# inputs: $@"

  local aliasesScript="$root_dir/git-aliases.sh"
  local shellRc="$HOME/.bashrc"
  # MAC OS case
  if [[ "$(uname)" == "Darwin" ]]; then
    local shellRc="$HOME/.zshrc"
  fi

  # Ajouter le sourcing si absent
  if ! grep -q "$aliasesScript" "$shellRc"; then
    writeLog "Add aliases in $shellRc !"
    echo -e "\n[ -f \"$aliasesScript\" ] && source \"$aliasesScript\"" >> "$shellRc"
  else
    writeLog "Aliases already exists in $shellRc !"
  fi
}

initAliases