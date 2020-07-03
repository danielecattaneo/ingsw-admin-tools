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
deadline=1593813600 # saturday 4 july 2020, 00:00:00 GMT+2

while [[ $# -gt 0 ]]; do
  case $1 in
    --repos-dir)
      shift; repos_dir="$1";;
    -o | --output)
      shift; stats_dir="$1";;
    -d | --deadline)
      shift; deadline="$1";;
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
    last_commit_date=$(cd $repo; git log -n 1 --date=iso --format=format:%cd)
    last_commit_date_epoch=$(cd $repo; git log -n 1 --format=format:%ct)
    
    echo '<tr>' >> "$index_file"
    echo '<td><a href="'"$repo"'/index.html"><b>'"$repo"'</b></a></td>' >> "$index_file"
    echo '<td><a href="'"$repo"'/authors.html">authors</a></td>' >> "$index_file"
    echo '<td><font face="monospace">'"$last_commit_date"'</font></td>' >> "$index_file"
    if [[ $last_commit_date_epoch > $deadline ]]; then
      echo '<td><font color="red">BLOWN</font></td>' >> "$index_file"
    else
      echo '<td><font color="green">OK</font></td>' >> "$index_file"
    fi
    echo '</tr>' >> "$index_file"
  done
}

export -f process_one
echo '<!DOCTYPE html><html>'> "$index_file"
echo '<head><meta charset="UTF-8"><style>td { text-align: center; }</style><title>stats index</title></head>' >> "$index_file"
echo '<body><table><tr>' >> "$index_file"
echo '<th>Index</th><th>Authors</th><th>Last commit</th><th>Deadline Status</th>' >> "$index_file"
echo '</tr>' >> "$index_file"
make_process_list | parallel --bar > make_stats.log
echo '</table>' >> "$index_file"
echo '</body></html>' >> "$index_file"

