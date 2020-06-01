#!/usr/bin/env python3

import argparse
from pathlib import Path
import re
import functools
import subprocess
import shutil
import logging as log
import sys


def levenshtein(s1, s2):
  if len(s1) < len(s2):
    return levenshtein(s2, s1)

  # len(s1) >= len(s2)
  if len(s2) == 0:
    return len(s1)

  previous_row = range(len(s2) + 1)
  for i, c1 in enumerate(s1):
    current_row = [i + 1]
    for j, c2 in enumerate(s2):
      insertions = previous_row[j + 1] + 1
      deletions = current_row[j] + 1
      substitutions = previous_row[j] + (c1 != c2)
      current_row.append(min(insertions, deletions, substitutions))
    previous_row = current_row

  return previous_row[-1]


def parse_committer(mailmap_entry: str):
  m = re.match('[ 0-9]*([^<]+) <([^>]+)>', mailmap_entry.strip())
  if m is None:
    raise Exception('cannot parse mailmap spec ' + mailmap_entry)
  name = m.group(1).strip()
  if name == 'GitHub':
    return {}
  mail = m.group(2).strip()
  return {name: mail}


class Repository:
  def __init__(self, repo: Path, rawmap: str):
    # key: name, value: mail
    self.destination_mailmap = {}
    self.repo: Path

    self.repo = repo
    list_committers=map(lambda x: parse_committer(x), rawmap.strip().split('\t'))
    for committer in list_committers:
      self.destination_mailmap.update(committer)


  def get_current_mailmap_from_git(self):
    gitpath = shutil.which('git')
    gitp = subprocess.run([gitpath, 'shortlog', '-sne', '--all'], stdout=subprocess.PIPE, check=True, cwd=str(self.repo))
    output = gitp.stdout.decode('utf-8').splitlines()
    list_committers = map(lambda x: parse_committer(x), output)
    res = {}
    for committer in list_committers:
      res.update(committer)
    return res


  def compute_mailmap(self):
    old_mailmap = self.get_current_mailmap_from_git()

    log.info("repo = " + str(self.repo))
    res = ''

    new_names_matched = set()

    for old_name, old_mail in old_mailmap.items():
      best_name = "UNK"
      best_mail = "UNK"
      best_name_score = 0
      score = 0
      log.info('new candidate "' + best_name + '", mail "' + best_mail + '"')

      for new_name, new_mail in self.destination_mailmap.items():
        old_mail_nodomain = old_mail.split('@')[0]
        new_mail_nodomain = new_mail.split('@')[0]
        test1 = (new_name+' '+new_mail_nodomain).lower()
        test2 = (old_name+' '+old_mail_nodomain).lower()

        difference = levenshtein(test1, test2)

        diff_min = abs(len(test1) - len(test2))
        diff_max = max(len(test1), len(test2))
        score = 1 - (difference - diff_min) / (diff_max - diff_min)

        log.debug('test1="'+test1+'", test2="'+test2+'"')
        log.info('candidate matches with '+new_name+' with confidence '+str(int(score*100)))
        if score > best_name_score:
          best_name = new_name
          best_mail = new_mail
          best_name_score = score
        elif score == best_name_score:
          log.info('tie with previous candidate!')
      log.info('selected ' + best_name)

      lhs = best_name + ' <' + best_mail + '> ' + \
            old_name + ' <' + old_mail + '>'
      rhs = '# confidence ' + str(int(best_name_score * 100)) + '%\n'
      res += '%-130s%s' % (lhs, rhs)

      new_names_matched.add(best_name)

    unmatched_names = set(self.destination_mailmap.keys()).difference(new_names_matched)
    for name in unmatched_names:
      res += '# ORPHAN: ' + name + ' <' + self.destination_mailmap[name] + '>\n'

    return res


def main():
  parser = argparse.ArgumentParser(description='Automatically produces mailmap '
      'from git repos using string similarity algorithms.')
  parser.add_argument('--repos', dest='repos', type=str, default='repos',
      help='Root directory of the repository list')
  parser.add_argument('--base', dest='base', type=str, default='mailmap_base.txt',
      help='Base mailmap file.')
  parser.add_argument('--output', dest='output', type=str, default='mailmap.txt',
      help='Output mailmap file.')
  parser.add_argument('--verbose', dest='verbose', type=int, default=0,
      help='Logging level (0 to 4)', choices=range(0, 5))
  args = parser.parse_args()

  log.basicConfig(level=50-args.verbose*10, stream=sys.stderr)

  repo_dir = Path(args.repos)
  repos = sorted(repo_dir.glob('group_??'))

  base_fp = Path(args.base)
  base_maps = base_fp.read_text().splitlines()

  output_file = Path(args.output).open(mode='w')

  for repo, map in zip(repos, base_maps):
    repo_obj = Repository(repo, map)
    output_file.write(repo_obj.compute_mailmap())
    output_file.write('\n')

  output_file.close()


if __name__ == '__main__':
  main()
