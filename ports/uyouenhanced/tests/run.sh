#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/tests .build/host-clang-cache
for test in direct-formats sponsor public-feed; do
    xcrun --sdk macosx clang -fobjc-arc -fmodules-cache-path="$PWD/.build/host-clang-cache" \
        -framework Foundation -Isources "tests/$test.m" sources/UYTDirectFormats.m sources/UYTSponsor.m sources/UYTPublicFeed.m \
        -o ".build/tests/$test"
    ".build/tests/$test"
done
python3 -m py_compile scripts/*.py
PYTHONPATH=scripts python3 tests/packaging.py
