#!/bin/bash

# import shared constants 
. shared-contantes.sh

function isJson() {
  local maybeJson=$1
  
  echo "$maybeJson" | jq -e >/dev/null 2>&1
  
  if [[ $? -gt 0 ]]; then
    echo 1
    return 1
  else 
    echo 0
    return 0
  fi
}