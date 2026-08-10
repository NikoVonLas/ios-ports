#!/usr/bin/env python3
"""Update the pinned Codex stable release in config.env."""

from __future__ import annotations

import argparse
import pathlib
import re


TAG_PATTERN = re.compile(r"rust-v(\d+\.\d+\.\d+)")
REVISION_PATTERN = re.compile(r"[0-9a-f]{40}")


def replace_value(text: str, key: str, value: str) -> str:
    pattern = re.compile(rf"^{re.escape(key)}=.*$", re.MULTILINE)
    replacement = f"{key}={value}"
    if not pattern.search(text):
        raise SystemExit(f"missing {key} in config")
    return pattern.sub(replacement, text, count=1)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("tag")
    parser.add_argument("revision")
    parser.add_argument(
        "--config",
        type=pathlib.Path,
        default=pathlib.Path(__file__).resolve().parent.parent / "config.env",
    )
    args = parser.parse_args()

    tag_match = TAG_PATTERN.fullmatch(args.tag)
    if tag_match is None:
        raise SystemExit("tag must look like rust-v1.2.3")
    if REVISION_PATTERN.fullmatch(args.revision) is None:
        raise SystemExit("revision must be a lowercase 40-character commit SHA")

    text = args.config.read_text()
    text = replace_value(text, "CODEX_LAST_RELEASE", args.tag)
    text = replace_value(text, "CODEX_REVISION", args.revision)
    text = replace_value(text, "PACKAGE_VERSION", tag_match.group(1))
    text = replace_value(text, "PACKAGE_REVISION", "1")
    args.config.write_text(text)


if __name__ == "__main__":
    main()
