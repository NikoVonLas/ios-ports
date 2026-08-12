#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

need_command git
mkdir -p "$BUILD_ROOT"

if [[ ! -d "$UPSTREAM_DIR/.git" ]]; then
  git clone --filter=blob:none --no-checkout "$GH_CLI_UPSTREAM" "$UPSTREAM_DIR"
fi

git -C "$UPSTREAM_DIR" fetch --depth 1 origin "$GH_CLI_REVISION"
git -C "$UPSTREAM_DIR" checkout --detach --force "$GH_CLI_REVISION"
actual="$(git -C "$UPSTREAM_DIR" rev-parse HEAD)"
[[ "$actual" == "$GH_CLI_REVISION" ]] || die "upstream revision mismatch: $actual"
printf 'GitHub CLI upstream ready at %s\n' "$actual"
