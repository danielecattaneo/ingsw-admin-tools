#!/bin/bash


check_dependency()
{
  if [[ ! ( -e $(which $1) ) ]]; then
    echo "$1 not found in PATH, please install it"
  fi  
}


process_one()
{
  repo_origin="$1"
  repo_tmp_dir="$2"
  repo_dest_dir="$3"
  
  # clone as bare repo in temporary dir
  git clone "$repo_origin" "$repo_tmp_dir"
  
  # rewrite history in temporary copy
  cd "$repo_tmp_dir"
  git filter-branch --index-filter 'git rm -r --cached --ignore-unmatch '"'"':!*.java'"'"'' -- --all
  rm -rf refs/original
  git reflog expire --expire=now --all
  git fsck --full --unreachable
  git repack -A -d
  git gc --aggressive --prune=now
  cd ..
  
  # clone temporary copy to destination
  rm -rf "$repo_dest_dir"
  git clone "$repo_tmp_dir" "$repo_dest_dir"
  
  # cleanup
  rm -rf "$repo_tmp_dir"
}


use_ramdisk()
{
  # ramdisk_size is in kB
  if [[ -e $1 ]]; then
    echo "estimating ramdisk size..." > /dev/stderr
    ramdisk_size=$(du -sk repos | cut -f1)
    ramdisk_size=$(( ramdisk_size / 2 ))
    echo "ramdisk size =" $(echo "scale=1; $ramdisk_size / 1000000" | bc) "GB" > /dev/stderr
  else
    echo "WARNING: cannot estimate ramdisk size using cache, using 1 GB" > /dev/stderr
    ramdisk_size=1000000
  fi
  
  case $(uname -s) in
    Darwin)
      ramdisk_name="strip_non_java_ramdisk_$RANDOM"
      diskutil erasevolume HFS+ "$ramdisk_name" $(hdiutil attach -nobrowse -nomount ram://$(( ramdisk_size * 2 ))) > /dev/stderr
      mkdir -p "/Volumes/$ramdisk_name/tmp"
      printf '%s\n' "/Volumes/$ramdisk_name/tmp";;
    *)
      echo "ERROR: I don't know how to make a ramdisk on platform " $(uname -s) > /dev/stderr
      exit 1;;
  esac
}


cleanup()
{
  echo Cleaning up...
  rm -rf "$TEMP_DIR"
}


check_dependency realpath
check_dependency parallel

trap 'cleanup' SIGINT

REPOS_DIR=repos_stripped
REPOS_FILE=repos.txt
TEMP_DIR=
CACHE=
LOG=/dev/null
USE_RAMDISK=0

while [[ $# -gt 0 ]]; do
  case $1 in
    --repos-dir)
      shift; REPOS_DIR="$1";;
      
    --repos-file)
      shift; REPOS_FILE="$1";;
      
    --use-cache)
      shift; CACHE=$(realpath "$1");;
    
    --temp-dir)
      shift; TEMP_DIR="$1";;
      
    --use-ramdisk)
      USE_RAMDISK=1;;
      
    --log)
      shift; LOG="$1";;
      
    *)
      printf 'unrecognized argument %s!\n' "$1";
      exit 1;;
  esac
  shift
done

if [[ $USE_RAMDISK -ne 0 ]]; then
  TEMP_DIR=$(use_ramdisk "$CACHE")
fi
if [[ -z "$TEMP_DIR" ]]; then
  TEMP_DIR=$(mktemp -d)
fi
mkdir -p "$TEMP_DIR"

mkdir -p "$REPOS_DIR"
touch "$LOG"
REPOS_DIR=$(realpath "$REPOS_DIR")
LOG=$(realpath "$LOG")
TMP_REPOS_DIR="$TEMP_DIR/repos"
mkdir -p "$TMP_REPOS_DIR"


gen_command()
{
  printf 'process_one "%s" "%s" "%s" 2>&1\n' "$1" "$TMP_REPOS_DIR/$2" "$REPOS_DIR/$2"
}

if [[ ! ( -z "$CACHE" ) ]]; then
  cd "$CACHE"
  for f in group_??; do
    gen_command "$CACHE/$f/.git" $f >> "$TEMP_DIR"/_commands.txt
  done
else
  i=1
  for repo in $(cat "$REPOS_FILE"); do
    repo_url="${repo%.git}.git"
    repo_dir=$(printf "group_%02d" $i)
    gen_command "$repo_url" "$repo_dir" >> "$TEMP_DIR"/_commands.txt
    i=$(( i + 1 ))
  done
fi

export -f process_one
parallel --bar < "$TEMP_DIR"/_commands.txt >> "$LOG"
cleanup

