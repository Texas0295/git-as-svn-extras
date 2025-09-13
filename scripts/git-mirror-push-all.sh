#!/usr/bin/env bash
set -euo pipefail

export GNUPGHOME="$HOME/.gnupg"
export GPG_TTY=$(tty)

REPO_ROOT="/srv/git/repositories"

REMOTE_NAME="origin"

shopt -s nullglob
for repo in "$REPO_ROOT"/*; do
  printf '[mirror] %s\n' "$repo"
  git -C "$repo" push --mirror "$REMOTE_NAME"
done
