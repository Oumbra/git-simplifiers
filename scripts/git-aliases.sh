#!/bin/bash

alias glo='git lo'
alias gpl='git pull'
alias gcd='git co develop && gpl && git fetch'
alias gcs='git co staging && gpl && git fetch'
alias gcm='git co main && gpl && git fetch'
alias gcp='git co -'
alias grd='git rb develop'
alias grs='git rb staging'
alias grm='git rb main'
alias grc='git rb --continue' # /!\ evol to no edit /!\
alias gcpc='git cp --continue' # /!\ evol to no edit /!\
alias gp='git push --set-upstream origin $(git symbolic-ref --short HEAD)'
alias gpf='git push --force'
alias ga='git amend'
alias gap='ga && gp'
alias gapf='ga && gpf'
alias grfd='gcd && gcp && grd'
alias grfs='gcs && gcp && grs'
alias grfm='gcm && gcp && grm'