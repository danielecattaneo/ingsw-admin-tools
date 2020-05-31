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

index_file="$stats_dir"/index.html

make_process_list()
{
  cd "$repos_dir"
  for repo in group_??; do
    printf 'process_one %s %s 2>&1\n' "$repos_dir/$repo" "$stats_dir/$repo"
    echo '<a href="'"$repo"'/index.html"><b>'"$repo"'</b></a> <a href="'"$repo"'/authors.html">authors</a><br>' >> "$index_file"
  done
}

export -f process_one
echo '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>stats index</title></head><body>' > "$index_file"
make_process_list | parallel --bar > test.log
echo '</body></html>' >> "$index_file"

