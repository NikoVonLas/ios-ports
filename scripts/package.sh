#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

binary="$TARGET_DIR/$IOS_TARGET/release/codex"
[[ -x "$binary" ]] || die "missing binary; run make build first"

rm -rf "$STAGE_DIR"
mkdir -p \
  "$STAGE_DIR/var/jb/usr/bin" \
  "$STAGE_DIR/var/jb/usr/share/codex-ios" \
  "$STAGE_DIR/DEBIAN" \
  "$DIST_DIR"
install -m 0755 "$binary" "$STAGE_DIR/var/jb/usr/bin/codex"
install -m 0644 \
  "$PROJECT_ROOT/packaging/entitlements.plist" \
  "$STAGE_DIR/var/jb/usr/share/codex-ios/entitlements.plist"
install -m 0755 "$PROJECT_ROOT/packaging/postinst" "$STAGE_DIR/DEBIAN/postinst"

sed \
  -e "s/@VERSION@/$PACKAGE_VERSION-$PACKAGE_REVISION/g" \
  -e "s/@ARCH@/$PACKAGE_ARCH/g" \
  "$PROJECT_ROOT/packaging/control.in" > "$STAGE_DIR/DEBIAN/control"

output="$DIST_DIR/codex-ios_${PACKAGE_VERSION}-${PACKAGE_REVISION}_${PACKAGE_ARCH}.deb"
python3 "$PROJECT_ROOT/scripts/make-deb.py" "$STAGE_DIR" "$output"
printf 'Package: %s\n' "$output"
