#!/usr/bin/env python3
import json
from pathlib import Path
import subprocess

PORT = Path(__file__).resolve().parents[1]
CONFIG = json.loads((PORT / 'config.json').read_text())

def run(*args, cwd=None):
    subprocess.run(args, cwd=cwd, check=True)

def checkout(name, url, revision, modules):
    directory = PORT / '.build' / name
    directory.parent.mkdir(parents=True, exist_ok=True)
    if not (directory / '.git').exists():
        run('git', 'clone', '--no-checkout', url, str(directory))
    resolved = subprocess.run(['git', 'cat-file', '-e', revision], cwd=directory, capture_output=True)
    if resolved.returncode:
        run('git', 'fetch', 'origin', revision, cwd=directory)
    run('git', 'checkout', '--detach', revision, cwd=directory)
    run('git', 'submodule', 'update', '--init', *modules, cwd=directory)
    return directory

if __name__ == '__main__':
    checkout('source', CONFIG['upstream'], CONFIG['revision'], ['Tweaks/YouTubeHeader', 'Tweaks/PSHeader', 'Tweaks/RemoteLog', 'Tweaks/Return-YouTube-Dislikes'])
    checkout('theos', CONFIG['theos'], CONFIG['theos_revision'], ['vendor/include', 'vendor/lib', 'vendor/logos', 'vendor/dm.pl'])
