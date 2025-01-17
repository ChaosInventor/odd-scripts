#! /bin/sh

description=$(cat <<EOF
Turns a git worktree into a bare repository.

Worktrees, directories containg a project and it's .git directory, are
gutted. The .git directory is moved to the target directory, renamed to
<project name>.git and configured to be bare.
EOF
)
authors=$(cat <<EOF
ChaosInventor
EOF
)

set -e

myName=$(basename $0)

usage() {
    cat <<EOF
Usage: $myName [-h | --help] [-t | --target <dir>] [-p | --[no-]print]
               [-P | --[no-]failures] [-z | -Z | -0 | --null] [--]
               <dir>...
$description

[-h | --help] - print this message and exit
[-t | --target <dir>] - where to put newly bare repos, pwd by default
[-p | --[no-]print] - enable or disable printing of gutted worktree
    toplevel directories, off by default
[-P | --[no-]failures] - enable or disable printing of worktree
    directories that weren't gutted, off by default. If gutted worktree
    toplevel printing is also enabled, a blank line is printed before
    the failures
[-z | -Z | -0 | --null] - when printing, separate output lines with a
    null character instead of a newline
[--] - stop option processing, allows for directories that start with -
<dir>... - list of git worktrees
EOF

    exit "${1:-1}"
}

err() {
    printf "$myName: %s\n" "$*" 1>&2
}

if [ $# -lt 1 ]; then
    usage 1>&2
fi

outDir="$(pwd)"
worktrees=
printRoots=false
rootsSeparator='\n'
printFailures=false
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage 0
            ;;
        -t|--target)
            if [ $# -lt 2 ]; then
                err "No directory specified for $1"
                usage 1>&2
            fi
            if [ ! -d $2 -o ! -w $2 ]; then
                err "$2 cannot be used as target, it is not a writable directory"
                usage 1>&2
            fi

            outDir="$2"
            shift 2
            ;;
        -p|--print)
            printRoots=true
            shift
            ;;
        --no-print)
            printRoots=false
            shift
            ;;
        -P|--failures)
            printFailures=true
            shift
            ;;
        --no-failures)
            printFailures=false
            shift
            ;;
        -0|-z|-Z|--null)
            rootsSeparator='\0'
            shift
            ;;
        --)
            shift
            break
            ;;
        -*)
            err "Unknown option $1"
            usage 1>&2
            ;;
        *)
            worktrees="$1${worktrees:+ $worktrees}"
            shift
            ;;
    esac
done
worktrees="${worktrees:+$worktrees }$@"

if [ -z "$worktrees" ]; then
    err 'no worktrees given'
    usage 1>&2
fi

failures=
failuresCount=0
for worktree in $worktrees; do
    error=
    if [ -z "$error" ] && [ ! -d $worktree ]; then
        err "$worktree is not a directory, not gutting"
        error='error'
    fi

    if [ -z "$error" ] && ! gitdir="$(git -C $worktree rev-parse --git-dir 2> /dev/null)"; then
        err "$worktree is not a git worktree, skipping"
        error='error'
    fi
    #Is path relative?
    if [ "$gitdir" = "${gitdir#/}" ]; then
        gitdir="$worktree"/"$gitdir"
    fi

    if [ -z "$error" ] && [ ! -d "$gitdir/objects" ]; then
        err "git directory $gitdir belonging to $worktree does not have an objects directory; refusing to gut likely linked worktree"
        error='error'
    fi

    if [ -z "$error" ] && [ "$(git -C $worktree config --local --bool core.bare)" = "true" ] ; then
        err "$worktree already bare, cannot gut"
        error='error'
    fi

    if [ -z "$error" ] && [ ! -z "$(git -C "$worktree" status --porcelain=v1)" ]; then
        err "$worktree has untracked changes, skipping"
        error='error'
    fi

    if [ -z "$error" ]; then
        worktreeRoot="$(git -C "$worktree" rev-parse --show-toplevel)"
        git --git-dir="$gitdir" config --local --bool core.bare true
        mv "$gitdir" "$outDir/$(basename "$worktreeRoot").git"

        if [ "$printRoots" = "true" ]; then
            printf "%s$rootsSeparator" "$worktreeRoot"
        fi
    else
        failuresCount=$((failuresCount + 1))
        if [ "$printRoots" = 'false' ] && [ "$printFailures" = 'true' ]; then
            printf "%s$rootsSeparator" "$worktree"
        else
            failures="${failures:+$failures$rootsSeparator}$worktree"
        fi
    fi
done

if [ "$printFailures" = 'true' ] && [ $printRoots = 'true' ]; then
    printf "$rootsSeparator$failures$rootsSeparator"
fi

exit $failuresCount
