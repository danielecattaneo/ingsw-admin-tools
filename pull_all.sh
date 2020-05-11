#!/bin/bash


save_xattr()
{
  if [[ $(uname -s) != 'Darwin' ]]; then return 0; fi
  f="$1"
  for attr_name in com.apple.FinderInfo com.apple.metadata:_kMDItemUserTags; do
    xattr -px ${attr_name} ${f} | tr -d ' \n'
    echo
  done
}


restore_xattr()
{
  if [[ $(uname -s) != 'Darwin' ]]; then return 0; fi
  f="$1"
  shift
  for attr_name in com.apple.FinderInfo com.apple.metadata:_kMDItemUserTags; do
    attr_data=$(echo $1 | sed -E 's/../& /g')
    xattr -wx "$attr_name" "$attr_data" "$f"
    shift
  done
}


action_update_existing()
{
  git pull
}


mkdir -p repos
cd repos

i=1
for repo in $(cat ../repos.txt); do
  repo_url="${repo%.git}.git"
  repo_dir=$(printf "group_%02d" $i)
  repo_oldxattr=
  
  ok=0
  
  while [[ $ok -eq 0 ]]; do
    if [[ -e $repo_dir ]]; then
      #### REPOSITORY EXISTS
      cd $repo_dir
      existing_url=$(git remote get-url --all origin)
      repo_oldxattr=$(save_xattr "$repo_dir")
      if [[ $existing_url != $repo_url ]]; then
        echo $repo_dir URL has changed, re-cloning
        cd ..
        rm -rf $repo_dir
      else
        echo $repo_dir exists, pulling
        if action_update_existing &> ../$repo_dir.log; then
          rm ../$repo_dir.log
          printf '%s OK, current branch %s\n' $repo_dir $(git branch --show-current)
          cd ..
          ok=1
        else
          echo $repo_dir FAIL
          cd ..
          rm -rf $repo_dir
        fi
      fi
      
    elif [[ -e $repo_dir.log ]]; then
      ### REPOSITORY HAD ERROR
      echo $repo_dir retrying after error
      rm $repo_dir.log
    
    else
      ### NEW REPOSITORY
      echo $repo_dir cloning fresh
      if git clone ${repo_url} ${repo_dir} &> $repo_dir.log; then
        rm $repo_dir.log
        printf 'DEBUG: %s' ${repo_oldxattr}
        if [[ ! -z "$repo_oldxattr" ]]; then
          restore_xattr "$repo_dir" $repo_oldxattr
        fi
        printf '%s OK, current branch %s\n' $repo_dir $(cd ${repo_dir}; git branch --show-current)
      else
        echo $repo_dir FAIL
      fi
      ok=1
    fi
  done
  
  i=$(( i + 1 ))
done

cd ..
