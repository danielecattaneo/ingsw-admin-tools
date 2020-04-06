#!/bin/bash

formatted_date=$(date +%Y%m%d_%H%M)

temp_tar=$(pwd)/repos_$formatted_date.tar
tar -cf "$temp_tar" -T /dev/null

cd repos
for group in group_*; do
  echo $group
  if [[ -f "$group" ]]; then
    tar -rf "$temp_tar" "$group"
  elif [[ -d "$group/.git" ]]; then
    cd "$group"
    this_temp_tar=$(mktemp).tar
    git archive --prefix="$group/" -o "$this_temp_tar" HEAD
    tar -rf "$temp_tar" "@$this_temp_tar"
    rm -f "$this_temp_tar"
    cd ..
  fi
done

bzip2 -9 $temp_tar
