#!/bin/bash


check_dependency()
{
  if [[ ! ( -e $(which $1) ) ]]; then
    echo "$1 not found in PATH, please install it"
  fi  
}


process_one()
{
  repo_dir="$1"
  repo_stat_dir="$2"
  rm -rf "$repo_stat_dir"
  mkdir -p "$repo_stat_dir"
  gitstats "$repo_dir" "$repo_stat_dir"
}


check_dependency parallel
check_dependency realpath
check_dependency gitstats

repos_dir=repos
stats_dir=stats

while [[ $# -gt 0 ]]; do
  case $1 in
    --repos-dir)
      shift; repos_dir="$1";;
    -o | --output)
      shift; stats_dir="$1";;
    *)
      printf 'unrecognized argument %s!\n' "$1";
      exit 1;;
  esac
  shift
done

mkdir -p "$stats_dir"
repos_dir=$(realpath "$repos_dir")
stats_dir=$(realpath "$stats_dir")

make_process_list()
{
  cd "$repos_dir"
  for repo in group_??; do
    printf 'process_one %s %s 2>&1\n' "$repos_dir/$repo" "$stats_dir/$repo"
  done
}

export -f process_one
make_process_list | parallel --bar > test.log

