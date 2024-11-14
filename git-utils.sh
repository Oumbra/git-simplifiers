#!/bin/bash

# import shared constants and functions
. shared-contantes.sh
. shared-functions.sh

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

# Git clean branch : passe sur develop et supprime la branche précédemment en cours
function gcb() {
  local current_branch=$(git symbolic-ref --short HEAD)
  if [[ "$current_branch" != 'develop' ]]; then
    gcd
    git br -D ${current_branch}
  fi
}

# Git delete branch : supprime la branche désigné en remote (sur le serveur)
function gdb() {
  if [[ -n "$1" ]]; then
    git push origin --delete "$1"
  fi
}

# Git rename branch : Renomme la branche en cours (ou la branche désigné) en local et en remote
function grb() {
  local old_branch_name
  local new_branch_name

  if [[ $# == 2 && -n "${1}" && -n "${2}" ]]; then
    old_branch_name="${1}"
    new_branch_name="${2}"
  else
    old_branch_name=$(git symbolic-ref --short HEAD)
    new_branch_name="${1}"
  fi

  if [[ -n "${new_branch_name}" && -n "${old_branch_name}" ]]; then
    git br -m "${new_branch_name}"
    git push origin -u "${new_branch_name}"
    gdb "${old_branch_name}"
  fi
}

function removeLocalOrphanBranch() {
  local remote=( $( git branch -r --format="%(refname:short)" | while read b; do echo '"'$b'"'; done ) ) 
  local local=( $( git branch --format="%(refname:short)" | while read b; do echo '"'$b'"'; done ) )

  for branch in "${local[@]}"; do
    if [[ $(echo ${remote[@]} | fgrep -cw "$branch") -eq 0 ]]; then
      git branch -D $branch
    fi
  done
}

# Git Cherry Pick Branch Environment
function gcpbe() {
  if [[ $# == 0 || "$@" =~ "-h" ]]; then 
    echo -e "gcpbe [OPTIONS...]\n\nOptions:\n\t-w, --workitem-id                  Set Azure workitem id (mandatory)\n\t-c, --commit-sha                   Set commitSHA to cherry pick (mandatory)\n\t-e, --env [develop|staging|main]   Set environments of branch (mandatory). One or two environments, separated by comma, where create branch (develop | staging | main)\n\t-pr, --pull-request                Create pull request for branch on specified environment\n\t-t, --tech                         Set tech flag for branch name and commit name"
    return 
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -c|--commit-sha)
        if [[ $(echo "${#2}") != 40 ]]; then
          echo -e "${redColor}$2 is not a valid branch name !${resetColor}"
          return
        fi
        local commitSHA=$2
        shift 2 # past argument and value
        ;;
      -e|--env)
        local envs=( $(echo "$2" | tr ',' ' ') )
        for env in ${envs[@]}; do
          if [[ ! " ${environments[@]} " =~ " $env " ]]; then
            echo -e "${redColor}$2 is not a valid environment name ! (${environments[@]})${resetColor}"
            return
          fi
        done
        shift 2 # past argument and value
        ;;
      -t|--tech)
        local isTechWork=true
        shift # past argument
        ;;
      -w|--workitem-id)
        if [[ $(echo "$2" | grep -Ec '^[0-9]+$') == 0 ]]; then
          echo -e "${redColor}$2 is not workitem id !${resetColor}"
          return
        fi
        local workitemId=$2
        shift 2 # past argument and value
        ;;
      -pr|--pull-resquest)
        local buildPullRequest=true
        shift # past argument
        ;;
      *|-*|--*)
        echo -e "${redColor}Unknown option $1 !${resetColor}"
        return
        ;;
    esac
  done

  if [[ -z "$envs" ]]; then echo -e "${redColor}Environnments is mandatory !${resetColor}"; return; fi
  if [[ -z "$workitemId" ]]; then echo -e "${redColor}Workitem id is mandatory !${resetColor}"; return; fi
  if [[ -z "$commitSHA" ]]; then echo -e "${redColor}Commit SHA is mandatory !${resetColor}"; return; fi

  if [[ "$isTechWork" == true ]]; then local techArg="--tech"; fi

  for env in ${envs[@]}; do
    echo -e "${cyanColor}## Env: $env${resetColor}"
    local branchName=$(azureBranchName -w $workitemId -e $env ${techArg:-})

    git brd $env &> /dev/null

    echo -e "${cyanColor}Going to branch $env...${resetColor}"
    git checkout -q $env && git pull -q && git fetch -q

    echo -e "${cyanColor}Creating branch $branchName...${resetColor}"
    git checkout -q -b $branchName

    echo -e "${cyanColor}Cherry picking...${resetColor}"
    git cherry-pick $commitSHA > /dev/null 2>&1

    # check if cp has conflit
    if git status | grep -q "Unmerged paths"; then
      echo -e "${redColor}There are merge conflicts. Please resolve them, then gcpc and gp${resetColor}"
      return
    fi

    echo -e "${cyanColor}Pushing branch $branchName...${resetColor}"
    git push -q --set-upstream origin "$branchName"
    
    if [[ "${buildPullRequest:-false}" == true ]]; then
      echo -e "${cyanColor}Building pull request on $env...${resetColor}"
      azureCreatePullRequest -e $env -w $workitemId
    fi
    echo ""
  done
}

. git-azure.sh