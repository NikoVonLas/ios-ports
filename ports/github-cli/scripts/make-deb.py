#!/usr/bin/env python3
"""Create a deterministic Debian package without requiring dpkg-deb on macOS."""

from __future__ import annotations

import io
import os
import pathlib
import stat
import sys
import tarfile


def tar_tree(root: pathlib.Path, control: bool) -> bytes:
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w:xz", format=tarfile.GNU_FORMAT) as archive:
        for path in sorted(root.rglob("*")):
            relative = path.relative_to(root)
            if control != (relative.parts[0] == "DEBIAN"):
                continue
            if control:
                relative = pathlib.Path(*relative.parts[1:])
                if not relative.parts:
                    continue
            info = archive.gettarinfo(str(path), arcname=f"./{relative}")
            info.uid = info.gid = 0
            info.uname = info.gname = "root"
            info.mtime = int(os.environ.get("SOURCE_DATE_EPOCH", "0"))
            if path.is_file():
                with path.open("rb") as source:
                    archive.addfile(info, source)
            else:
                archive.addfile(info)
    return buffer.getvalue()


def ar_member(name: str, payload: bytes) -> bytes:
    timestamp = int(os.environ.get("SOURCE_DATE_EPOCH", "0"))
    header = f"{name + '/':<16}{timestamp:<12}{0:<6}{0:<6}{stat.S_IFREG | 0o644:<8o}{len(payload):<10}`\n"
    result = header.encode("ascii") + payload
    if len(payload) % 2:
        result += b"\n"
    return result


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: make-deb.py STAGE OUTPUT")
    stage, output = map(pathlib.Path, sys.argv[1:])
    package = b"!<arch>\n"
    package += ar_member("debian-binary", b"2.0\n")
    package += ar_member("control.tar.xz", tar_tree(stage, control=True))
    package += ar_member("data.tar.xz", tar_tree(stage, control=False))
    output.write_bytes(package)


if __name__ == "__main__":
    main()
