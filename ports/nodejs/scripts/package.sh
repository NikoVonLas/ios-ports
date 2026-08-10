#!/bin/sh
set -eu

# shellcheck disable=SC1091
. "$(dirname -- "$0")/common.sh"

if [ ! -x "$stage_root/var/jb/usr/lib/nodejs-ios24/node-bin" ]; then
  echo "error: staged Node binary is missing; run make build first" >&2
  exit 1
fi

mkdir -p "$dist_root" "$build_root/package"

control="$build_root/package/control"
sed \
  -e "s/@NODE_VERSION@/$NODE_VERSION/g" \
  -e "s/@PACKAGE_REVISION@/$PACKAGE_REVISION/g" \
  "$project_root/packaging/control.in" > "$control"

output="$dist_root/nodejs_${NODE_VERSION}-${PACKAGE_REVISION}_iphoneos-arm64.deb"
python3 "$project_root/scripts/make-deb.py" \
  --control "$control" \
  --data "$stage_root" \
  --output "$output"

shasum -a 256 "$output" > "$output.sha256"
echo "package: $output"
