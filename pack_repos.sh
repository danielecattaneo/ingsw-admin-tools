#!/bin/bash


check_dependency()
{
  if [[ ! ( -e $(which $1) ) ]]; then
    echo "$1 not found in PATH, please install it"
  fi  
}


check_dependency realpath

repos_dir=repos
output_tar=
prefix=

while [[ $# -gt 0 ]]; do
  case $1 in
    --repos-dir)
      shift; repos_dir=$(realpath "$1");;
    -o | --output)
      shift; output_tar="$1";;
    -p | --prefix)
      shift; prefix="$1";;
    --)
      shift; break;;
    --*)
      printf 'unrecognized argument %s!\n' "$1";
      exit 1;;
    *)
      break;;
  esac
  shift
done

if [[ $# -gt 0 ]]; then
  for gid in "$@"; do
    group_dirs="$group_dirs group_$(printf '%02d' $gid)"
  done
  repos_trail=_not_complete_
else
  group_dirs=group_*
  repos_trail=_
fi

if [[ -z "$output_tar" ]]; then
  formatted_date=$(date +%Y%m%d_%H%M)
  output_tar=$(pwd)/repos${repos_trail}${formatted_date}.tar
fi

tar -cf "$output_tar" -T /dev/null
output_tar=$(realpath "$output_tar")

cd "$repos_dir"
for group in $group_dirs; do
  echo $group
  if [[ -f "$group" ]]; then
    tar -rf "$output_tar" "$group"
  elif [[ -d "$group/.git" ]]; then
    cd "$group"
    if [[ ! ( -z "$prefix" ) ]]; then
      dest_prefix=$(echo "$group" | sed -E 's/group_/'"$prefix"'/g')'/'
    else
      dest_prefix="$group/"
    fi
    this_output_tar=$(mktemp).tar
    if git archive --prefix="$dest_prefix" -o "$this_output_tar" HEAD; then echo > /dev/null; else
      echo ERROR!
      exit 1
    fi
    tar -rf "$output_tar" "@$this_output_tar"
    rm -f "$this_output_tar"
    cd ..
  fi
done

bzip2 -9 $output_tar
