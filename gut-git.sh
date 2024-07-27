#! /bin/sh

description=$(cat <<EOF
Turns a git worktree into a bare repository.

Worktrees, directories containg a project and it's .git directory, are
gutted. The .git directory is moved to the target directory, renamed to
<project name>.git and configured to be bare.
EOF
)

set -e

myName=$(basename $0)

usage() {
    echo "Usage: $myName [-h | --help] [-t | --target <dir>] [-p | --[no-]print] [-z | -Z | -0 | --null] [--] <dir>..."
    echo "$description"
    echo
    echo "[-h | --help] - print this message and exit"
    echo "[-t | --target <dir>] - where to put newly bare repos, pwd by default"
    echo "[--] - stop option processing, allows for directories that start with -"
    echo "[-p | --[no-]print] - enable or disable printing of gutted worktree toplevel directories, off by default"
    echo "[-z | -Z | -0 | --null] - when printing, separate gutted worktrees with a null character instead of a newline"
    echo "<dir>... - list of git worktrees"

    exit 1
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
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
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
    err "no worktrees given"
    usage 1>&2
fi

failuresCount=0
for worktree in $worktrees; do
    if [ ! -d $worktree ]; then
        err "$worktree is not a directory, not gutting"
        failuresCount=$((failuresCount + 1))
        continue
    fi

    if gitdir="$worktree/$(git -C $worktree rev-parse --git-dir 2> /dev/null)"; then
        if [ ! -d "$gitdir/objects" ]; then
            err "git directory $gitdir belonging to $worktree does not have an objects directory; refusing to gut likely linked worktree"
            failuresCount=$((failuresCount + 1))
            continue
        fi

        if [ ! -z "$(git -C "$worktree" status --porcelain=v1)" ]; then
            err "$worktree has untracked changes, skipping"
            failuresCount=$((failuresCount + 1))
            continue
        fi

        worktreeRoot="$(git -C "$worktree" rev-parse --show-toplevel)"
        git --git-dir="$gitdir" config --local --bool core.bare true
        mv "$gitdir" "$outDir/$(basename "$worktreeRoot").git"

        if [ "$printRoots" = "true" ]; then
            printf "%s$rootsSeparator" "$worktreeRoot"
        fi
    else
        err "$worktree is not a git worktree, skipping"
        failuresCount=$((failuresCount + 1))
    fi
done

exit $failuresCount
