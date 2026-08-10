#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

need_command git
need_command cargo
need_command rustup
need_command xcrun
need_command python3

developer_dir="$(xcode-select -p 2>/dev/null || true)"
if [[ "$developer_dir" == "/Library/Developer/CommandLineTools" ]]; then
  die "Command Line Tools are selected; install/select full Xcode for the iPhoneOS SDK"
fi

sdk_path="$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null || true)"
[[ -n "$sdk_path" && -d "$sdk_path" ]] || die "iPhoneOS SDK not found"

if ! rustup target list --installed | grep -qx "$IOS_TARGET"; then
  die "Rust target missing; run: rustup target add $IOS_TARGET"
fi

printf 'Xcode developer dir: %s\n' "$developer_dir"
printf 'iPhoneOS SDK: %s\n' "$sdk_path"
printf 'Rust target: %s\n' "$IOS_TARGET"
printf 'Deployment target: %s\n' "$IOS_DEPLOYMENT_TARGET"
if command -v ldid >/dev/null 2>&1; then
  printf 'Host signing: ldid\n'
else
  printf 'Host signing: skipped (package postinst will use ldid on the iPad)\n'
fi
