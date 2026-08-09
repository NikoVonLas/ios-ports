#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

need_command scp
need_command ssh

SSH_HOST="${SSH_HOST:-127.0.0.1}"
SSH_PORT="${SSH_PORT:-2222}"
SSH_USER="${SSH_USER:-root}"
package="$DIST_DIR/codex-ios_${PACKAGE_VERSION}-${PACKAGE_REVISION}_${PACKAGE_ARCH}.deb"
remote_package="/var/tmp/$(basename "$package")"

[[ -f "$package" ]] || die "package not found; run make package first"

scp -P "$SSH_PORT" "$package" "$SSH_USER@$SSH_HOST:$remote_package"
ssh -t -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" \
  "dpkg -i '$remote_package' && rm -f '$remote_package' && /var/jb/usr/bin/codex --version"

