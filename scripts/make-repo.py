#!/usr/bin/env python3
"""Generate a small flat APT repository that Sileo can consume."""

from __future__ import annotations

import gzip
import hashlib
import os
import pathlib
import shutil


ROOT = pathlib.Path(__file__).resolve().parent.parent
DIST = ROOT / "dist"
REPO = ROOT / "docs"
VERSION = "0.1.0-1"
ARCH = "iphoneos-arm64"
DEB_NAME = f"codex-ios_{VERSION}_{ARCH}.deb"


def digest(path: pathlib.Path, algorithm: str) -> str:
    hasher = hashlib.new(algorithm)
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def main() -> None:
    source_deb = DIST / DEB_NAME
    if not source_deb.is_file():
        raise SystemExit(f"missing package: {source_deb}; run make package")

    pool = REPO / "debs"
    pool.mkdir(parents=True, exist_ok=True)
    target_deb = pool / DEB_NAME
    shutil.copy2(source_deb, target_deb)

    relative_deb = target_deb.relative_to(REPO).as_posix()
    package = "\n".join(
        [
            "Package: com.openai.codex-ios",
            "Name: Codex CLI for iPadOS",
            f"Version: {VERSION}",
            f"Architecture: {ARCH}",
            "Maintainer: Shamaal World",
            "Author: OpenAI (upstream), community iPadOS port",
            "Section: Development",
            "Priority: optional",
            "Depends: firmware (>= 15.0), bash, ca-certificates, git, ldid, openssh-client, ripgrep",
            f"Filename: {relative_deb}",
            f"Size: {target_deb.stat().st_size}",
            f"SHA256: {digest(target_deb, 'sha256')}",
            "Description: Experimental rootless iPadOS port of OpenAI Codex CLI",
            "Homepage: https://github.com/openai/codex",
            "",
        ]
    ).encode()

    packages = REPO / "Packages"
    packages.write_bytes(package)
    packages_gz = REPO / "Packages.gz"
    with packages_gz.open("wb") as output:
        with gzip.GzipFile(filename="", mode="wb", fileobj=output, mtime=0) as archive:
            archive.write(package)

    release_lines = [
        "Origin: Shamaal World",
        "Label: Codex for iPadOS",
        "Suite: stable",
        "Codename: stable",
        "Version: 1.0",
        f"Architectures: {ARCH}",
        "Components: main",
        "Description: Experimental Codex CLI packages for rootless iPadOS",
        "SHA256:",
    ]
    for path in (packages, packages_gz):
        release_lines.append(
            f" {digest(path, 'sha256')} {path.stat().st_size:16d} {path.name}"
        )
    (REPO / "Release").write_text("\n".join(release_lines) + "\n")
    print(REPO)


if __name__ == "__main__":
    main()
