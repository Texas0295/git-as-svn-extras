#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="${REPO_ROOT:-/srv/git/repositories}"
REMOTE="${REMOTE:-origin}"
SERVICE="${SERVICE:-git-as-svn.service}"
MAPDB="${MAPDB:-$HOME/.local/git-as-svn/git-as-svn.mapdb}"

log() { printf "\033[1;34m[gasvn]\033[0m %s\n" "$*"; }
die() { printf "\033[1;31m[gasvn] ERROR:\033[0m %s\n" "$*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage: $(basename "$0") <repo-name> <branch>

Env overrides:
  REPO_ROOT  (default: $REPO_ROOT)
  REMOTE     (default: $REMOTE)
  SERVICE    (default: $SERVICE)
  MAPDB      (default: $MAPDB)
EOF
  exit 1
}

[[ $# -eq 2 ]] || usage
REPO_NAME="$1"
BRANCH="$2"
REPO="${REPO_ROOT%/}/$REPO_NAME"

[[ -d "$REPO" ]] || die "Repo path not found: $REPO"
git -C "$REPO" rev-parse --is-bare-repository >/dev/null 2>&1 || die "Not a git repo: $REPO"

git -C "$REPO" remote get-url "$REMOTE" >/dev/null 2>&1 || die "Remote '$REMOTE' missing in $REPO"

if ! git -C "$REPO" config --get "remote.$REMOTE.fetch" | grep -q 'refs/heads/\*:refs/remotes/'"$REMOTE"'/\*'; then
  git -C "$REPO" config "remote.$REMOTE.fetch" '+refs/heads/*:refs/remotes/'"$REMOTE"'/*'
  log "Set fetch refspec for $REMOTE"
fi

log "Fetching $REMOTE ..."
git -C "$REPO" fetch "$REMOTE" --prune

REMOTE_REF="refs/remotes/$REMOTE/$BRANCH"
git -C "$REPO" show-ref --verify --quiet "$REMOTE_REF" || die "Remote branch not found: $REMOTE_REF"

BACKUP_REF=""
if git -C "$REPO" show-ref --verify --quiet "refs/heads/$BRANCH"; then
  CUR=$(git -C "$REPO" rev-parse "refs/heads/$BRANCH")
  BACKUP_REF="refs/heads/backup/gasvn-${BRANCH}-$(date +%Y%m%d-%H%M%S)"
  git -C "$REPO" update-ref "$BACKUP_REF" "$CUR"
  log "Backed up $BRANCH: $BACKUP_REF -> $CUR"
else
  log "No existing local branch $BRANCH (skip backup)"
fi

NEW=$(git -C "$REPO" rev-parse "$REMOTE_REF")
git -C "$REPO" update-ref "refs/heads/$BRANCH" "$NEW"
log "Updated refs/heads/$BRANCH -> $NEW (from $REMOTE_REF)"

GASVN_TIMELINE="refs/git-as-svn/v1/$BRANCH"
if git -C "$REPO" show-ref --verify --quiet "$GASVN_TIMELINE"; then
  git -C "$REPO" update-ref -d "$GASVN_TIMELINE"
  log "Deleted timeline ref $GASVN_TIMELINE"
fi

log "Restarting $SERVICE and clearing cache ..."
systemctl --user stop "$SERVICE"
[[ -f "$MAPDB" ]] && rm -f "$MAPDB" && log "Removed cache DB: $MAPDB"
systemctl --user start "$SERVICE"

log "Tail service logs (last 10):"
journalctl --user -u "$SERVICE" -n 10 --no-pager || true

if [[ -n "$BACKUP_REF" ]]; then
  git -C "$REPO" update-ref -d "$BACKUP_REF"
  log "Deleted backup ref $BACKUP_REF after successful alignment"
fi

log "Done. Tip of $REPO_NAME/$BRANCH is now $NEW"
echo
echo "SVN working copy: 建議新 checkout；或在舊目錄中："
echo "  svn revert -R . && svn cleanup --remove-unversioned --remove-ignored . && svn update --force"
