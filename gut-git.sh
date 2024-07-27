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
    echo "Usage: $myName [-h | --help] [-t | --target <dir>] [--] <dir>..."
    echo "$description"
    echo
    echo "[-h | --help] - print this message and exit"
    echo "[-t | --target <dir>] - where to put newly bare repos, pwd by default"
    echo "<dir>... - list of git worktrees"

    exit 1
}

if [ $# -lt 1 ]; then
    usage
fi

outDir="$(pwd)"
worktrees=
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            ;;
        -t|--target)
            if [ $# -lt 2 ]; then
                echo "$myName: No directory specified for $1"
                usage
            fi
            if [ ! -d $2 -o ! -w $2 ]; then
                echo "$myName: $2 cannot be used as target, it is not a writable directory"
                usage
            fi

            outDir="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "$myName: Unknown option $1"
            usage
            ;;
        *)
            worktrees="$1${worktrees:+ $worktrees}"
            shift
            ;;
    esac
done
worktrees="${worktrees:+$worktrees }$@"

for worktree in $worktrees; do
    if [ ! -d $worktree ]; then
        echo "$myName: $worktree is not a directory, not gutting."
        continue
    fi

    if gitdir="$worktree/$(git -C $worktree rev-parse --git-dir 2> /dev/null)"; then
        if [ ! -d "$gitdir/objects" ]; then
            echo "$myName: git directory $gitdir belonging to $worktree does not have an objects directory; refusing to gut likely linked worktree"
            continue
        fi

        if [ ! -z "$(git -C "$worktree" status --porcelain=v1)" ]; then
            echo "$myName: $worktree has untracked changes, skipping"
            continue
        fi

        worktreeRoot="$(git -C "$worktree" rev-parse --show-toplevel)"
        git --git-dir="$gitdir" config --local --bool core.bare true
        mv "$gitdir" "$outDir/$(basename "$worktreeRoot").git"

        #TODO: Optional cleanup of worktree root
    else
        echo "$myName: $worktree is not a git worktree, skipping"
    fi
done
