#!/bin/sh
# GIT_ASKPASS helper: feeds git credentials from ../.git-auth (gitignored).
# Usage: GIT_ASKPASS=/home/z/my-project/scripts/git-askpass.sh git push ...
case "$1" in
  Username*) echo "jamesrudh-arch" ;;
  Password*) cat /home/z/my-project/.git-auth ;;
esac
