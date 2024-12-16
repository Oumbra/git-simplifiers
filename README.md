# Help scripts for Git usage

### Recommanded git aliases

```
[alias]
	co = checkout
	cob = checkout -b
 	br = branch
 	brd = branch -D
 	sts = status
 	lo = log --oneline
 	cim = !git add -A && git commit -m
 	amend = !git add -A && git commit --amend --no-edit
 	undo = reset --soft HEAD^
 	rh = reset --hard HEAD^
 	rb = rebase
 	rbi = rebase -i
 	rbc = rebase --continue
 	cp = cherry-pick
    cpc = cherry-pick --continue
```

### Git utils

list of shortcuts to speed up and simplify certain Git actions :

- **glo**: Git log oneline 
- **gco**: Moving to specified branch
- **gbr**: Show locales branches
- **gpl**: Git pull
- **gcd**: Move to **develop** branch, pull it and fecth
- **gcs**: Move to **staging** branch, pull it and fecth
- **gcm**: Move to **main** branch, pull it and fecth
- **gcp**: Move to previous branch
- **grd**: Rebase current branch from **develop** branch
- **grs**: Rebase current branch from **staging** branch
- **grm**: Rebase current branch from **main** branch
- **grbc**: Continue current rebase # /!\ evol to no edit /!\
- **gcpc**: Continue current cherry-pick  # /!\ evol to no edit /!\
- **gp**: Push current branch to remote (Create only)
- **gpf**: Push **_force_** current branch to remote
- **ga**: Amend commit of current branch
- **gap**: Amend commit and push current branch
- **gapf**: Amend commit and push **_force_** current branch
- **grfd**: Rebase current branch from **develop** branch, after updating the **develop** branch
- **grfs**: Rebase current branch from **staging** branch, after updating the **staging** branch
- **grfm**: Rebase current branch from **main** branch, after updating the **main** branch

- **gcb**: Remove current local branch
- **gdb**: Remove remote branch
- **grb**: Rename current or specified branch in local **and** remote
- **gcpbe**: Cherry pick specified commit SHA to specified environnments
- **removeLocalOrphanBranch**: Remove local branches if they don't exist remotely

### Azure

To use Azure functions you need to configure a SOPHT_AZURE_ACCESSTOKEN environnment variable.

This token must be have rights :

- Code (Read, write & mange)
- Connected server
- Graph (Read)
- Identity (Read)
- Member Entitlement Management (Read)
- Pull Request Threads (Read & write)
- Work Items (Read, write & mange)