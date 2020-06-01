# ingsw-admin-tools

Administrative tools for handling student projects at PoliMi for the Computer Science and Engineering BSc course "Prova Finale di Ingegneria del Software".

## `pull_all.sh`

Retrieves a list of repositories provided in a file (named `repos.txt` by default).

Each repository in the list is given a serial number starting with 1. Upon process completion, each repository is found in the directory `repos/group_xx` where `xx` is the serial number as a 2-digit zero-padded decimal number.

If possible, the tool simply pulls the changes from the remote. Otherwise, if it fails, it clones the repository fresh.

On macOS, this tools tries very hard to preserve extended attributes on the root directory of each repository. This means that Finder tags and color labels are mantained even if an error occurs and the repository is cloned fresh.

### Usage

`./pull_all.sh [OPTIONS]`

**Options:**

* `--repos-dir <dir>`: Changes the output directory from `./repos` to the specified one
* `--repos-file <file>`: Changes the list of remote URLs from `./repos.txt` to the specified file
* `--bare`: Clones bare repositories instead.

## `pack_repos.sh`

Creates a tarball using `git-archive` containing all the repositories retrieved by `pull_all.sh`.

The default file name of the tarball contains the current time and date.

### Usage

`./pack_repos.sh [OPTIONS] [--] [gid1, gid2, ...]`

`gid1`, `gid2`,... are repository serial numbers. If no list of serial numbers are given, all repositories are packed. Instead, only the repositories with the given serials are packed.

**Options:**

* `--repos-dir <dir>`: Changes the directory of repositories to pack from `./repos` to the specified one. Note that this tool expects a directory produced by `pull-all.sh`.
* `-o <file>`, `--output <file>`: Changes the default destination filename to the given one.

**Examples:**

* `./pack_repos.sh`

Packs all repositories previously retrieved by `pull_all.sh` in the `./repos` directory to a file named `repos_<DATE>_<TIME>.tar.bz2`. `<DATE>` and `<TIME>` are automatically generated from the current date and time.

* `./pack_repos.sh 7 14 28 42`

Packs repositories 7, 14, 28 and 42 in a file named `repos_not_complete_<DATE>_<TIME>.tar.bz2`.


## `make_stats.sh`

Generates statistics for all repositories using `gitstats`.

### Usage

`./make_stats.sh [OPTIONS]`

**Options:**

* `--repos-dir <dir>`: Changes the directory of repositories to analyze from `./repos` to the specified one. Note that this tool expects a directory produced by `pull-all.sh`.
* `-o <dir>`, `--output <dir>`: Changes the default destination directory to the given one.

## `strip_non_java.sh`

Rewrites history of all repositories to remove all non Java source code files. Useful for:

1. Generation of a clean set of files to feed into MOSS for similarity detection, in combination with `pack_repos.sh`
2. Distributing project students to co-workers to analyze without having to pass around gigabyte-sized tarballs, still in combination with `pack_repos.sh`
3. Reliably checking the amount of work of each student team member, in combination with `make_stats.sh`

### Usage

`./strip_non_java.sh [OPTIONS]`

**Options:**

* `--repos-file <file>`: Tells the tool to process the repositories listed in the given file. This is the default behavior, and the default file name is `./repos.txt`
* `--use-cache <dir>`: Tells the tool to process the repositories from an already existing `./repos` directory. This option overrides `--repos-file`. Note that this tool expects a directory produced by `pull-all.sh`.
* `--repos-dir <dir>`: Changes the directory where the processed repositories are saved to the given one. Default directory is `repos_stripped`.
* `--use-mailmap <file>`: Allows remapping the mails in all the repositories according to the single mailmap-formatted file given (see [the git documentation](https://git-scm.com/docs/git-check-mailmap) for more info about mailmap files).
* `--temp-dir <dir>`: Changes the temporary directory to use to the given one. **THE TEMPORARY DIRECTORY IS DELETED ON EXIT OR SIGINT (CTRL+C)**. By default a new temporary directory is created using `mktemp`.
* `--use-ramdisk` Moves the temporary directory to a newly-created ramdisk. Make sure you have a lot of RAM, even though this tool tries to save disk space when it can. When in doubt, don't use this. This option overrides `--temp-dir`.
* `--log <file>` Outputs a log to the specified file. Logs tend to be very large. When in doubt, don't use this.
