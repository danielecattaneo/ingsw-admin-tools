#!/bin/bash


check_dependency()
{
  if [[ ! ( -e $(which $1) ) ]]; then
    echo "$1 not found in PATH, please install it"
  fi  
}


do_project() {
  cd $1
  pname=$(basename $1)
  echo "******** project $pname"
  pompath=$(find . -name 'pom.xml' | head -n 1)
  if [[ ! ( -e $pompath ) ]]; then
    echo 'POM not found!'
    return 1
  fi
  cd $(dirname $pompath)
  mvn org.sonarsource.scanner.maven:sonar-maven-plugin:3.7.0.1746:sonar \
      -Dsonar.host.url=http://localhost:9000 \
      -Dsonar.projectKey=$pname \
      -Dsonar.projectName=$pname \
      -Dsonar.login=admin -Dsonar.password=admin
}


check_dependency parallel

repos_dir=repos

while [[ $# -gt 0 ]]; do
  case $1 in
    --repos-dir)
      shift; repos_dir="$1";;
    *)
      printf 'unrecognized argument %s!\n' "$1";
      exit 1;;
  esac
  shift
done

make_process_list()
{
  cd "$repos_dir"
  for repo in group_??; do
    printf 'do_project %s 2>&1\n' "$repos_dir/$repo"
  done
}

export -f do_project
make_process_list | parallel --bar > sonar_all.log
