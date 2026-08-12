#!/usr/bin/env python3
"""Publish GitHub CLI into the monorepo's shared flat Sileo repository."""

from __future__ import annotations

import gzip
import hashlib
import pathlib
import shutil


ROOT = pathlib.Path(__file__).resolve().parent.parent
DIST = ROOT / "dist"
REPO = ROOT.parent / "codex" / "docs"


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


def digest(path: pathlib.Path, algorithm: str) -> str:
    hasher = hashlib.new(algorithm)
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def package_name(stanza: str) -> str | None:
    for line in stanza.splitlines():
        if line.startswith("Package: "):
            return line.removeprefix("Package: ")
    return None


def main() -> None:
    config = read_config()
    version = f"{config['PACKAGE_VERSION']}-{config['PACKAGE_REVISION']}"
    arch = config["PACKAGE_ARCH"]
    deb_name = f"github-cli-ios_{version}_{arch}.deb"
    source_deb = DIST / deb_name
    if not source_deb.is_file():
        raise SystemExit(f"missing package: {source_deb}; run make package")

    pool = REPO / "debs"
    pool.mkdir(parents=True, exist_ok=True)
    target_deb = pool / deb_name
    for stale_deb in pool.glob(f"github-cli-ios_*_{arch}.deb"):
        if stale_deb != target_deb:
            stale_deb.unlink()
    shutil.copy2(source_deb, target_deb)

    packages_path = REPO / "Packages"
    existing = packages_path.read_text().strip() if packages_path.exists() else ""
    stanzas = [stanza for stanza in existing.split("\n\n") if stanza.strip()]
    stanzas = [
        stanza
        for stanza in stanzas
        if package_name(stanza) != "com.nikovonlas.github-cli-ios"
    ]
    relative_deb = target_deb.relative_to(REPO).as_posix()
    stanzas.append(
        "\n".join(
            [
                "Package: com.nikovonlas.github-cli-ios",
                "Name: GitHub CLI for iPadOS",
                f"Version: {version}",
                f"Architecture: {arch}",
                "Maintainer: NikoVonLas",
                "Author: GitHub (upstream), NikoVonLas (iPadOS port)",
                "Section: Development",
                "Priority: optional",
                "Depends: firmware (>= 15.0), ca-certificates, git, ldid, openssh-client",
                "Conflicts: gh, github-cli",
                "Provides: gh, github-cli",
                "Replaces: gh, github-cli",
                "Tag: purpose::console, role::developer",
                f"Filename: {relative_deb}",
                f"Size: {target_deb.stat().st_size}",
                f"SHA256: {digest(target_deb, 'sha256')}",
                "Description: Native rootless iPadOS port of the official GitHub CLI",
                "Homepage: https://github.com/NikoVonLas/ios-ports/tree/main/ports/github-cli",
            ]
        )
    )
    package_data = ("\n\n".join(stanzas) + "\n").encode()
    packages_path.write_bytes(package_data)
    packages_gz = REPO / "Packages.gz"
    with packages_gz.open("wb") as output:
        with gzip.GzipFile(filename="", mode="wb", fileobj=output, mtime=0) as archive:
            archive.write(package_data)

    release_lines = [
        "Origin: NikoVonLas",
        "Label: NikoVonLas iOS Ports",
        "Suite: stable",
        "Codename: stable",
        "Version: 1.0",
        f"Architectures: {arch}",
        "Components: main",
        "Description: Developer tool ports for rootless iOS and iPadOS",
        "SHA256:",
    ]
    for path in (packages_path, packages_gz):
        release_lines.append(
            f" {digest(path, 'sha256')} {path.stat().st_size:16d} {path.name}"
        )
    (REPO / "Release").write_text("\n".join(release_lines) + "\n")
    print(REPO)


if __name__ == "__main__":
    main()
