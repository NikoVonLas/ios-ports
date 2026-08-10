#!/bin/sh
set -eu

# shellcheck disable=SC1091
. "$(dirname -- "$0")/common.sh"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "error: the iPhoneOS build currently requires macOS" >&2
  exit 1
fi

for tool in xcrun python3 make curl shasum patch; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "error: required tool not found: $tool" >&2
    exit 1
  fi
done

developer_dir=$(xcode-select -p 2>/dev/null || true)
case "$developer_dir" in
  */CommandLineTools)
    echo "error: Command Line Tools are selected, but the iPhoneOS SDK is absent" >&2
    echo "install full Xcode, then run:" >&2
    echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
    exit 1
    ;;
esac

sdk_root=$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null || true)
if [ -z "$sdk_root" ] || [ ! -d "$sdk_root" ]; then
  echo "error: xcrun cannot locate the iPhoneOS SDK" >&2
  exit 1
fi

if ! command -v ldid >/dev/null 2>&1; then
  echo "error: ldid is required to sign the device executable" >&2
  echo "install it with Homebrew or provide LDID=/path/to/ldid" >&2
  exit 1
fi

echo "Node.js:     $NODE_VERSION"
echo "Target:      arm64-apple-ios$IOS_DEPLOYMENT_TARGET"
echo "Developer:   $developer_dir"
echo "iPhoneOS SDK: $sdk_root"
