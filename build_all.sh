#!/bin/bash


check_dependency()
{
  if [[ ! ( -e $(which $1) ) ]]; then
    echo "$1 not found in PATH, please install it"
  fi  
}

check_dependency parallel
if which -s timeout > /dev/null; then
  export TIMEOUT=timeout
else
  export TIMEOUT=gtimeout
fi
check_dependency $TIMEOUT


do_project() {
  cd "$1"
  pname=$(basename $1)
  htmlfile="$2"
  
  echo "******** project $pname"
  echo "<tr><td>${pname:(-2)}</td>" >> "$htmlfile"
  
  last_commit_date=$(git log -n 1 --date=iso --format=format:%cd)
  echo '<td><font face="monospace">'"$last_commit_date"'</font></td>' >> "$htmlfile"
  
  pompath=$(find . -name 'pom.xml' | head -n 1)
  if [[ ! ( -e $pompath ) ]]; then
    echo 'POM not found!'
    echo "<td>--</td><td>--</td><td>POM non trovato!</td><td>--</td></tr>" >> "$htmlfile"
    return 1
  fi
  
  cd $(dirname $pompath)
  error_report=''
  ok_td='<td bgcolor=#0f0>👍</td>'
  ng_td='<td bgcolor=#f00>👎</td>'
  mvn \
    clean \
    compile
  if [[ $? -eq 0 ]]; then
    echo "$ok_td" >> "$htmlfile"
  else
    echo "$ng_td" >> "$htmlfile"
    error_report='Build failed'
  fi
  $TIMEOUT 1m \
    mvn \
      org.jacoco:jacoco-maven-plugin:0.8.6:prepare-agent test org.jacoco:jacoco-maven-plugin:0.8.6:report
  test_result=$?
  if [[ $test_result -eq 0 ]]; then
    echo "$ok_td" >> "$htmlfile"
    covperc=$(cat target/site/jacoco/index.html | sed -n -E 's/^.*<td>Total<\/td><[^>]+>[^<]+<\/[^>]+><td class="ctr2">([0-9]+\%).*$/\1/p')
    echo '<td>'"$error_report"'</td><td>'$covperc'</td>' >> "$htmlfile"
  elif [[ $test_result -eq 124 ]]; then
    echo "$ng_td" >> "$htmlfile"
    error_report='Timeout!'
    echo '<td>'"$error_report"'</td><td>--</td>' >> "$htmlfile"
  else
    echo "$ng_td" >> "$htmlfile"
    error_report='Test failed'
    echo '<td>'"$error_report"'</td><td>--</td>' >> "$htmlfile"
  fi
  
  if [[ $run_sonar -ne 0 ]]; then
    mvn \
      org.sonarsource.scanner.maven:sonar-maven-plugin:3.7.0.1746:sonar \
        -Dsonar.coverage.jacoco.xmlReportPaths='${project.build.directory}/site/jacoco/jacoco.xml' \
        -Dsonar.jacoco.reportsPaths='${project.build.directory}/jacoco.exec' \
        -Dsonar.host.url=http://localhost:9000 \
        -Dsonar.projectKey=$pname \
        -Dsonar.projectName=$pname \
        -Dsonar.login=admin -Dsonar.password=password
  fi
  echo '</tr>' >> "$htmlfile"
}


repos_dir=repos
temp_html_dir=$(mktemp -d)

summary_file=./build_summary.html
export run_sonar=0

while [[ $# -gt 0 ]]; do
  case $1 in
    --repos-dir)
      shift; repos_dir="$1";;
    --sonar)
      shift; export run_sonar=1;;
    *)
      printf 'unrecognized argument %s!\n' "$1";
      exit 1;;
  esac
  shift
done

touch ./build_summary.html
summary_file="$(realpath ./build_summary.html)"

make_process_list()
{
  cd "$repos_dir"
  for repo in group_??; do
    printf 'do_project %s %s 2>&1\n' "$repos_dir/$repo" "$temp_html_dir/$repo.html"
  done
}

export -f do_project
make_process_list | parallel --jobs 50% --bar > sonar_all.log

echo '<!DOCTYPE html><html>'> "$summary_file"
echo '<head><meta charset="UTF-8"><style>td { text-align: center; }</style><title>repo build summary</title></head>' >> "$summary_file"
echo '<body><table><tr>' >> "$summary_file"
echo '<th>Gruppo</th><th>Data commit testato</th><th>mvn compile</th><th>mvn test</th><th>Errori</th><th>Copertura</th>' >> "$summary_file"
cd "$repos_dir"
for repo in group_??; do
  cat "$temp_html_dir"/${repo}.html >> "$summary_file"
done
echo '</tr>' >> "$summary_file"
echo '</table>' >> "$summary_file"
echo '</body></html>' >> "$summary_file"
rm -rf "$temp_html_dir"
