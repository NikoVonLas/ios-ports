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


def read_config() -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in (ROOT / "config.env").read_text().splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        key, separator, value = line.partition("=")
        if not separator:
            raise SystemExit(f"invalid config.env line: {raw_line}")
        values[key] = value
    return values


CONFIG = read_config()
VERSION = f"{CONFIG['PACKAGE_VERSION']}-{CONFIG['PACKAGE_REVISION']}"
ARCH = CONFIG["PACKAGE_ARCH"]
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
    for stale_deb in pool.glob(f"codex-ios_*_{ARCH}.deb"):
        if stale_deb != target_deb:
            stale_deb.unlink()
    shutil.copy2(source_deb, target_deb)

    relative_deb = target_deb.relative_to(REPO).as_posix()
    package_stanzas = [
        [
            "Package: com.nikovonlas.codex-ios",
            "Name: Codex CLI for iPadOS",
            f"Version: {VERSION}",
            f"Architecture: {ARCH}",
            "Maintainer: NikoVonLas",
            "Author: OpenAI (upstream), NikoVonLas (iPadOS port)",
            "Section: Development",
            "Priority: optional",
            "Depends: firmware (>= 15.0), bash, ca-certificates, git, ldid, openssh-client, ripgrep",
            f"Filename: {relative_deb}",
            f"Size: {target_deb.stat().st_size}",
            f"SHA256: {digest(target_deb, 'sha256')}",
            "Description: Experimental rootless iPadOS port of OpenAI Codex CLI",
            "Homepage: https://github.com/NikoVonLas/ios-ports/tree/main/ports/codex",
        ]
    ]

    node_debs = sorted(pool.glob(f"nodejs_*_{ARCH}.deb"))
    if node_debs:
        node_deb = node_debs[-1]
        prefix = "nodejs_"
        suffix = f"_{ARCH}.deb"
        node_version = node_deb.name[len(prefix) : -len(suffix)]
        package_stanzas.append(
            [
                "Package: nodejs-ios24",
                "Name: Node.js 24 LTS",
                f"Version: {node_version}",
                f"Architecture: {ARCH}",
                "Maintainer: NikoVonLas",
                "Section: Development",
                "Priority: optional",
                "Depends: firmware (>= 15.0), zsh",
                "Conflicts: nodejs, nodejs-ios",
                "Provides: nodejs, npm",
                "Tag: purpose::console, role::developer",
                f"Filename: {node_deb.relative_to(REPO).as_posix()}",
                f"Size: {node_deb.stat().st_size}",
                f"SHA256: {digest(node_deb, 'sha256')}",
                "Description: Node.js 24 LTS and npm for rootless jailbroken iOS",
                " Native arm64 Node.js runtime packaged below /var/jb for iOS 15 and later.",
                "Homepage: https://github.com/NikoVonLas/ios-ports/tree/main/ports/nodejs",
            ]
        )

    github_cli_debs = sorted(pool.glob(f"github-cli-ios_*_{ARCH}.deb"))
    if github_cli_debs:
        github_cli_deb = github_cli_debs[-1]
        prefix = "github-cli-ios_"
        suffix = f"_{ARCH}.deb"
        github_cli_version = github_cli_deb.name[len(prefix) : -len(suffix)]
        package_stanzas.append(
            [
                "Package: com.nikovonlas.github-cli-ios",
                "Name: GitHub CLI for iPadOS",
                f"Version: {github_cli_version}",
                f"Architecture: {ARCH}",
                "Maintainer: NikoVonLas",
                "Author: GitHub (upstream), NikoVonLas (iPadOS port)",
                "Section: Development",
                "Priority: optional",
                "Depends: firmware (>= 15.0), ca-certificates, git, ldid, openssh-client",
                "Conflicts: gh, github-cli",
                "Provides: gh, github-cli",
                "Replaces: gh, github-cli",
                "Tag: purpose::console, role::developer",
                f"Filename: {github_cli_deb.relative_to(REPO).as_posix()}",
                f"Size: {github_cli_deb.stat().st_size}",
                f"SHA256: {digest(github_cli_deb, 'sha256')}",
                "Description: Native rootless iPadOS port of the official GitHub CLI",
                "Homepage: https://github.com/NikoVonLas/ios-ports/tree/main/ports/github-cli",
            ]
        )

    package = (
        "\n\n".join("\n".join(stanza) for stanza in package_stanzas) + "\n"
    ).encode()

    packages = REPO / "Packages"
    packages.write_bytes(package)
    packages_gz = REPO / "Packages.gz"
    with packages_gz.open("wb") as output:
        with gzip.GzipFile(filename="", mode="wb", fileobj=output, mtime=0) as archive:
            archive.write(package)

    release_lines = [
        "Origin: NikoVonLas",
        "Label: NikoVonLas iOS Ports",
        "Suite: stable",
        "Codename: stable",
        "Version: 1.0",
        f"Architectures: {ARCH}",
        "Components: main",
        "Description: Developer tool ports for rootless iOS and iPadOS",
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
