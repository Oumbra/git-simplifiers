#!/bin/bash

script_dir=$(dirname $0)
root_dir=$(echo $script_dir | perl -pe 's/^(.+)\/bin.*$/$1/g')

source "$root_dir/shared/alias.sh"

# https://learn.microsoft.com/en-us/rest/api/azure/devops/git/pull-requests/create?view=azure-devops-rest-7.1&tabs=HTTP
function azureCreatePullRequest() {
  if [[ $(needToCallHelpFunction $@) == 1 ]]; then azureCreatePullRequestHelp; return; fi

  local email
  email=$( getUserEmail; exit $? )
  local cmdState=$?
  if [[ $cmdState -gt 0 ]]; then 
      echo "$email"
      return $cmdState
  fi

  local organization
  organization=$( getAzureOrganizaton; exit $? )
  local cmdState=$?
  if [[ $cmdState -gt 0 ]]; then 
      echo "$organization"
      return $cmdState
  fi

  local project
  project=$( getAzureProject; exit $? )
  local cmdState=$?
  if [[ $cmdState -gt 0 ]]; then 
      echo "$project"
      return $cmdState
  fi

  local repository
  repository=$( getAzureRepository; exit $? )
  local cmdState=$?
  if [[ $cmdState -gt 0 ]]; then 
      echo "$repository"
      return $cmdState
  fi

  local repositoryId
  repositoryId=$( getAzureRepositoryId; exit $? )
  local cmdState=$?
  if [[ $cmdState -gt 0 ]]; then 
      echo "$repositoryId"
      return $cmdState
  fi

  local commandArgs="$@"
  local commandArgsCount="$#"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -s|--source)
        if [[ $(echo "$2" | grep -Ec '^[a-z]{1,3}/[a-z]{3}/[a-z0-9_\-]+$') == 0 ]]; then
          writeErrorLog "$2 is not a valid branch name !"
          return
        fi
        local source=$2
        shift 2 # past argument and value
        ;;
      -t|--target)
        if [[ $(echo "$2" | grep -Ec '^[a-z]{1,3}/[a-z]{3}/[a-z0-9_\-]+$') == 0 ]]; then
          writeErrorLog "$2 is not a valid branch name !"
          return
        fi
        local target=$2
        shift 2 # past argument and value
        ;;
      -e|--env)
        if [[ ! " ${ENABLE_ENVIRONMENTS[@]} " =~ " $2 " ]]; then
          writeErrorLog "$2 is not a valid environment name ! (${ENABLE_ENVIRONMENTS[@]})"
          return
        fi
        local env=$2
        shift 2 # past argument and value
        ;;
      -t|--tech)
        local techArg="--tech"
        shift # past argument
        ;;
      -i|--in-place)
        local isInPlace=true
        shift # past argument
        ;;
      -w|--workitem-id)
        if [[ $(echo "$2" | grep -Ec '^[0-9]+$') == 0 ]]; then
          writeErrorLog "$2 is not workitem id !"
          return
        fi
        local workitemId=$2
        shift 2 # past argument and value
        ;;
      --workitem)
        local workitem="$2"
        if [[ $(isJson "$workitem") == 1 || $(checkJsonStructure "$workitem" $WORKITEM_KEYS) == 1 ]]; then
          writeErrorLog "Workitem is not a valid JSON: $2"
          return
        fi
        shift 2 # past argument and value
        ;;
      --azure-workitem)
        local isAzureWorkitem=true
        shift 1
        ;;
      *|-*|--*)
        writeErrorLog "Unknown option $1 !"
        return
        ;;
    esac
  done
  
  echo -e "${CYAN_COLOR}Checking parameters...${RESET_COLOR}" 

  local env="$env"
  if [[ "$env" != "develop" && ! "$commandArgs" =~ "--env " && ! "$commandArgs" =~ "-e " ]]; then local env="develop"; fi

  if [[ "$isInPlace" == true ]]; then
    # recover current branch name
    local source=$(git symbolic-ref --short HEAD)
    # recover workitem id if possible
    if [[ $(echo "$source" | grep -Ec '^[a-z]{1,3}/[a-z]{3}/[0-9]+(-[a-z]*)?$') == 1 ]]; then
      local workitemId=$(echo "$source" | perl -lne 'print $1 if /[a-z]{1,3}\/[a-z]{3}\/([0-9]+)(-[a-z]*)?/')
    fi
    # eval env if possible else develop
    local env=${env:-develop}
    for _env in "${ENABLE_ENVIRONMENTS[@]}"; do
      local countBranchInEnv=$(git branch --contains $_env 2> /dev/null | fgrep -cw "$source")
      if [[ $countBranchInEnv -eq 1 ]]; then
        local env="$_env"
        break
      fi
    done
  fi

  if [[ -z $source && -z "$workitem" && -z "$workitemId" ]]; then
    writeErrorLog "Need a source branch or a workitem id or workitem !"
    return
  fi
  
  if [[ -z $target && -z $env ]]; then
    writeErrorLog "Need a target branch or an environment !"
    return
  fi

  if [[ -z "$workitem" && -z "$workitemId" ]]; then
    writeErrorLog "Need a standard workitem or workitem id !"
    return
  fi

  if [[ -n "$workitemId" ]]; then
      if [[ "$isAzureWorkitem" == true ]]; then
        local workitem=$( azureWorkItem.sh "$workitemId" -s )
      else
        local workitem=$( notionPage.sh "$workitemId" -s )
      fi

      if [[ $(isJson "$workitem") == 1 ]]; then
        writeErrorLog "$workitem"
        return
      fi
  fi

  if [[ -n "$workitem" ]]; then 
    local branchName=$( branchName.sh --workitem "$workitem" ${techArg:-} --env "$env" )
    local title=$( commitStandardMessage.sh --workitem "$workitem" ${techArg:-} )

    if [[ "${isAzureWorkitem:-false}" == false ]]; then
      local description=$(jqAlias "$workitem" -r '.link') 
    else 
      local workitemId=$(jqAlias "$workitem" -r '.id')
      local workitemUrl=$(jqAlias "$workitem" -r '.url')
      local workItemRef=$(jqAlias '[{ "id": $workitemId, "url": $workitemUrl }]' -c -n --argjson workitemId $workitemId --arg workitemUrl "$workitemUrl")
    fi
  elif [[ -n "$source" ]]; then
    local title=$(git log -1 --pretty=%B)
  fi

  local sourceBranch="refs/heads/${source:-$branchName}"
  echo -e "${CYAN_COLOR}Checking remote source branch '$sourceBranch' exists...${RESET_COLOR}" 
  local remoteSourceBranchExists=$(git ls-remote --heads origin $sourceBranch)
  if [[ -z "$remoteSourceBranchExists" ]]; then 
    writeErrorLog "Source branch '${source:-$branchName}' not exists !"
    return
  fi

  local targetBranch="refs/heads/${target:-$env}"
  echo -e "${CYAN_COLOR}Checking remote target branch '$targetBranch' exists...${RESET_COLOR}" 
  local remoteTargetBranchExists=$(git ls-remote --heads origin $targetBranch)
  if [[ -z "$remoteTargetBranchExists" ]]; then 
    writeErrorLog "Target branch '${target:-$env}' not exists !"
    return
  fi

  #  TODO ADD identifierRef to autocomplete and reviewer
  local identityRef=$( azureUserIdentity.sh $email )

  writeLog "workItemRef: $workItemRef, identityRef: $identityRef"

  echo -e "${CYAN_COLOR}Preparing pull request creation...${RESET_COLOR}" 
  # TODO trouvé un moyen de récupérer la liste des reviewers possible et de les rendre sélectionnable
  # add description when not azure-workitem
  local jsonBody=$(
    jq -c -n \
    --arg title "$title" \
    --arg sourceBranch "$sourceBranch" \
    --arg targetBranch "$targetBranch" \
    --argjson workItemRef ${workItemRef:-'[]'} \
    --argjson identityRef "${identityRef:-null}" \
    --arg description "$description" \
    '{
      "sourceRefName": $sourceBranch,
      "targetRefName": $targetBranch,
      "title": $title,
      "workItemRefs": $workItemRef,
      "reviewers": []
    }
     + (if $description != "" then { "description": $description } else {} end)
     + (if $identityRef != null then { "autoCompleteSetBy": $identityRef } else {} end)'
  )

  echo -e "${CYAN_COLOR}Creating pull request...${RESET_COLOR}" 
  local response=$( azureRestApi.sh "git/repositories/$repositoryId/pullRequests?api-version=7.1" "$jsonBody" )
  if [[ $(isJson "$response") == 1 ]]; then
    writeErrorLog "${response}\nsended json :\n${jsonBody}"
    return
  fi

  local hasCreationError=$(jqAlias "$response" -e 'has("message")')
  if [[ $hasCreationError == true ]]; then
    local message=$(jqAlias "$response" -r '.message')
    writeErrorLog "${message}\nsended json :\n${jsonBody}"
    return 1
  fi

  local pullRequestId=$(jqAlias "$response" -r '.pullRequestId')
  local pullRequestUrl="https://dev.azure.com/$organization/$project/_git/$repository/pullrequest/$pullRequestId"
  echo -e "${GREEN_COLOR}Pull request created: $pullRequestUrl${RESET_COLOR}"

# TODO
return
# TODO
  echo -e "${CYAN_COLOR}Clearing local branch '${source:-$branchName}'...${RESET_COLOR}" 
  git checkout -q develop && git pull -q && git fetch -q
  git branch -D "${source:-$branchName}" &> /dev/null
}


function azureCreatePullRequestHelp() {
  echo -e "
Usage: azureCreatePullRequest [OPTION...] [COMMAND]...
Create an azure pull request from two branch or a azure workitem

Options:
  -i, --in-place                     Set in place flag to eval source branch and target env
  -w, --workitem-id                  Set workitem id
  --workitem                         Set workitem object
  -s, --source                       Set source branch name
  -t, --target                       Set target branch name
  -e, --env [develop|staging|main]   Set environment of branch (default: develop)
  -t, --tech                         Set tech flag for branch name and commit name
  --azure-workitem                   Set azure flag to recover azure or notion workitem from id 
Commands:
  -h, --help                         Displays this help and exists
Examples:
  azureCreatePullRequest -w 2783
  azureCreatePullRequest -w 2783 -t
  azureCreatePullRequest -w 2783 -e staging
  azureCreatePullRequest -s f/dam/2783 -t f/dam/2783-main
  azureCreatePullRequest -w 2783 -e main
"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    azureCreatePullRequest "$@"
fi