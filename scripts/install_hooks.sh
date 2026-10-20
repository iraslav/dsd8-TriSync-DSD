#!/usr/bin/env bash
# install_hooks.sh -- one-time setup so `git push` certifies locally
# before it ever reaches GitHub. Run this once after cloning:
#
#   ./scripts/install_hooks.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK_SRC="$REPO_ROOT/githooks/pre-push"
HOOK_DST="$REPO_ROOT/.git/hooks/pre-push"

if [ ! -d "$REPO_ROOT/.git" ]; then
    echo "error: run this from inside a git checkout of the repository" >&2
    exit 1
fi

cp "$HOOK_SRC" "$HOOK_DST"
chmod +x "$HOOK_DST"
echo "installed pre-push hook -> $HOOK_DST"
echo "every 'git push' will now run 'make lint && make test' first."
