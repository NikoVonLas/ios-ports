#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

need_command git
need_command go
need_command xcrun
need_command python3

[[ "$(uname -s)" == Darwin ]] || die "the iPhoneOS build requires macOS"
developer_dir="$(xcode-select -p 2>/dev/null || true)"
[[ "$developer_dir" != /Library/Developer/CommandLineTools ]] || \
  die "Command Line Tools are selected; select the full Xcode installation"
sdk_path="$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null || true)"
[[ -n "$sdk_path" && -d "$sdk_path" ]] || die "iPhoneOS SDK not found"

printf 'Go host: %s\n' "$(go version)"
printf 'iPhoneOS SDK: %s\n' "$sdk_path"
printf 'Target: ios/arm64 (iOS %s+)\n' "$IOS_DEPLOYMENT_TARGET"
if command -v ldid >/dev/null 2>&1; then
  printf 'Host signing: ldid\n'
else
  printf 'Host signing: skipped (package postinst will sign on device)\n'
fi
