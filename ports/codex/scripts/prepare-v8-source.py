#!/usr/bin/env python3
"""Restore the iOS ICU data omitted from published rusty_v8 crates."""

from __future__ import annotations

import base64
import hashlib
import io
import os
import pathlib
import re
import tarfile
import urllib.request


ROOT = pathlib.Path(__file__).resolve().parent.parent
LOCKFILE = ROOT / ".build" / "upstream" / "codex-rs" / "Cargo.lock"
KNOWN_SHA256 = {
    ("150.4.0", "ee5f27adc28bd3f15b2c293f726d14d2e336cbd5"):
        "742711f071304fc2bb50d33b8885d24503eead1854e41d68037efd7bb6987b79",
    ("150.4.0-common", "ee5f27adc28bd3f15b2c293f726d14d2e336cbd5"):
        "1cf67874b5a87a8363a86fb3f81e3cbbed54d389062dab8fb52308d5cf8c8612",
}


def package_version(lockfile: str, package: str) -> str:
    match = re.search(
        rf'^name = "{re.escape(package)}"\nversion = "([^"]+)"$',
        lockfile,
        re.MULTILINE,
    )
    if match is None:
        raise SystemExit(f"missing {package} package in Cargo.lock")
    return match.group(1)


def main() -> None:
    version = package_version(LOCKFILE.read_text(), "v8")
    cargo_home = pathlib.Path(os.environ.get("CARGO_HOME", pathlib.Path.home() / ".cargo"))
    candidates = list((cargo_home / "registry" / "src").glob(f"*/v8-{version}"))
    if len(candidates) != 1:
        raise SystemExit(f"expected one unpacked v8-{version} crate, found {len(candidates)}")

    crate = candidates[0]
    deps = (crate / "v8" / "DEPS").read_text()
    revision_match = re.search(
        r"chromium/deps/icu\.git'\s*\+\s*'@'\s*\+\s*'([0-9a-f]{40})'",
        deps,
    )
    if revision_match is None:
        raise SystemExit("could not resolve the ICU revision from v8/DEPS")
    revision = revision_match.group(1)
    rust_revision_match = re.search(
        r"chromium/src/third_party/rust'\s*\+\s*'@'\s*\+\s*'([0-9a-f]{40})'",
        deps,
    )
    if rust_revision_match is None:
        raise SystemExit("could not resolve the Chromium Rust revision from v8/DEPS")
    rust_revision = rust_revision_match.group(1)
    destination = crate / "third_party" / "icu" / "ios" / "icudtl.dat"
    expected = KNOWN_SHA256.get((version, revision))

    icu_ready = False
    if destination.is_file():
        digest = hashlib.sha256(destination.read_bytes()).hexdigest()
        if expected is None or digest == expected:
            print(f"iOS ICU data ready: {destination} ({digest})")
            icu_ready = True

    if not icu_ready:
        url = (
            "https://chromium.googlesource.com/chromium/deps/icu.git/+/"
            f"{revision}/ios/icudtl.dat?format=TEXT"
        )
        with urllib.request.urlopen(url) as response:
            payload = base64.b64decode(response.read(), validate=True)
        digest = hashlib.sha256(payload).hexdigest()
        if expected is not None and digest != expected:
            raise SystemExit(f"ICU checksum mismatch: expected {expected}, got {digest}")
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(payload)
        print(f"Downloaded iOS ICU data: {destination} ({digest})")

    common_destination = crate / "third_party" / "icu" / "common" / "icudtl.dat"
    common_expected = KNOWN_SHA256.get((f"{version}-common", revision))
    common_ready = False
    if common_destination.is_file():
        common_digest = hashlib.sha256(common_destination.read_bytes()).hexdigest()
        if common_expected is None or common_digest == common_expected:
            print(f"Common ICU data ready: {common_destination} ({common_digest})")
            common_ready = True
    if not common_ready:
        common_url = (
            "https://chromium.googlesource.com/chromium/deps/icu.git/+/"
            f"{revision}/common/icudtl.dat?format=TEXT"
        )
        with urllib.request.urlopen(common_url) as response:
            common_payload = base64.b64decode(response.read(), validate=True)
        common_digest = hashlib.sha256(common_payload).hexdigest()
        if common_expected is not None and common_digest != common_expected:
            raise SystemExit(
                f"common ICU checksum mismatch: expected {common_expected}, got {common_digest}"
            )
        common_destination.parent.mkdir(parents=True, exist_ok=True)
        common_destination.write_bytes(common_payload)
        print(f"Downloaded common ICU data: {common_destination} ({common_digest})")

    vendor = crate / "third_party" / "rust" / "chromium_crates_io"
    vendor_probe = vendor / "vendor" / "icu_calendar_data-v2" / "build.rs"
    if not vendor_probe.is_file():
        vendor_url = (
            "https://chromium.googlesource.com/chromium/src/third_party/rust/+archive/"
            f"{rust_revision}/chromium_crates_io.tar.gz"
        )
        with urllib.request.urlopen(vendor_url) as response:
            archive_payload = response.read()
        with tarfile.open(fileobj=io.BytesIO(archive_payload), mode="r:gz") as archive:
            for member in archive.getmembers():
                member_path = pathlib.PurePosixPath(member.name)
                if member_path.is_absolute() or ".." in member_path.parts:
                    raise SystemExit(f"unsafe Chromium Rust archive path: {member.name}")
            vendor.mkdir(parents=True, exist_ok=True)
            archive.extractall(vendor)
        archive_digest = hashlib.sha256(archive_payload).hexdigest()
        print(f"Downloaded Chromium Rust crates: {vendor} ({archive_digest})")
    else:
        print(f"Chromium Rust crates ready: {vendor}")


if __name__ == "__main__":
    main()
