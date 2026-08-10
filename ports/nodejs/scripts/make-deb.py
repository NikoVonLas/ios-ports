#!/usr/bin/env python3
"""Create a deterministic Debian binary package without dpkg-deb."""

from __future__ import annotations

import argparse
import gzip
import io
import os
from pathlib import Path
import tarfile
import time


def tar_bytes(entries: list[tuple[Path, str]], epoch: int) -> bytes:
    raw = io.BytesIO()
    with tarfile.open(fileobj=raw, mode="w", format=tarfile.GNU_FORMAT) as archive:
        for source, archive_name in entries:
            info = archive.gettarinfo(str(source), archive_name)
            info.uid = 0
            info.gid = 0
            info.uname = "root"
            info.gname = "wheel"
            info.mtime = epoch
            if info.isfile():
                with source.open("rb") as handle:
                    archive.addfile(info, handle)
            else:
                archive.addfile(info)
    compressed = io.BytesIO()
    with gzip.GzipFile(fileobj=compressed, mode="wb", mtime=epoch) as stream:
        stream.write(raw.getvalue())
    return compressed.getvalue()


def tree_entries(root: Path) -> list[tuple[Path, str]]:
    result: list[tuple[Path, str]] = []
    for path in sorted(root.rglob("*"), key=lambda item: item.as_posix()):
        relative = path.relative_to(root).as_posix()
        result.append((path, f"./{relative}"))
    return result


def ar_header(name: str, size: int, epoch: int) -> bytes:
    fields = (
        name.ljust(16)
        + str(epoch).ljust(12)
        + "0".ljust(6)
        + "0".ljust(6)
        + "100644".ljust(8)
        + str(size).ljust(10)
        + "`\n"
    )
    return fields.encode("ascii")


def add_ar_member(output, name: str, payload: bytes, epoch: int) -> None:
    output.write(ar_header(name, len(payload), epoch))
    output.write(payload)
    if len(payload) % 2:
        output.write(b"\n")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--control", type=Path, required=True)
    parser.add_argument("--data", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    epoch = int(os.environ.get("SOURCE_DATE_EPOCH", "0"))
    if epoch <= 0:
        epoch = int(time.time())

    control_archive = tar_bytes([(args.control, "./control")], epoch)
    data_archive = tar_bytes(tree_entries(args.data), epoch)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("wb") as output:
        output.write(b"!<arch>\n")
        add_ar_member(output, "debian-binary", b"2.0\n", epoch)
        add_ar_member(output, "control.tar.gz", control_archive, epoch)
        add_ar_member(output, "data.tar.gz", data_archive, epoch)


if __name__ == "__main__":
    main()
