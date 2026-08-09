#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../config.env
source "$PROJECT_ROOT/config.env"

BUILD_ROOT="$PROJECT_ROOT/.build"
UPSTREAM_DIR="$BUILD_ROOT/upstream"
TARGET_DIR="$BUILD_ROOT/target"
STAGE_DIR="$BUILD_ROOT/stage"
DIST_DIR="$PROJECT_ROOT/dist"

export IPHONEOS_DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

need_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

