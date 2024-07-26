# $1 is assumed to be a git repo that is then made bare.

#TODO: Make sure $1 is a git repo dir, if $1 is not given, figure out the git
#dir by traversing from pwd.

#TODO: Make sure the work tree has no changes or untracked files.

#TODO: The git repo doesn't have to be `.git`, figure it out
#TODO: Add ability to set destination and specify multiple repos, `mv` style.
mv $1/.git $1.git
git --git-dir=$1.git config --local --bool core.bare true

#TODO: Configurable `rm`, for example, maybe trash instead or archive.
rm -rf $1
