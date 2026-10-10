#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/tests .build/host-clang-cache
for test in direct-formats sponsor; do
    xcrun --sdk macosx clang -fobjc-arc -fmodules-cache-path="$PWD/.build/host-clang-cache" \
        -framework Foundation -Isources "tests/$test.m" sources/UYTDirectFormats.m sources/UYTSponsor.m \
        -o ".build/tests/$test"
    ".build/tests/$test"
done
python3 -m py_compile scripts/fetch.py scripts/build.py scripts/package.py scripts/verify.py
