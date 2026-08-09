#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

need_command git
mkdir -p "$BUILD_ROOT"

if [[ ! -d "$UPSTREAM_DIR/.git" ]]; then
  git clone --filter=blob:none --no-checkout "$CODEX_UPSTREAM" "$UPSTREAM_DIR"
fi

git -C "$UPSTREAM_DIR" fetch --depth 1 origin "$CODEX_REVISION"
git -C "$UPSTREAM_DIR" checkout --detach --force "$CODEX_REVISION"

actual="$(git -C "$UPSTREAM_DIR" rev-parse HEAD)"
[[ "$actual" == "$CODEX_REVISION" ]] || die "upstream revision mismatch: $actual"
printf 'Codex upstream ready at %s\n' "$actual"

