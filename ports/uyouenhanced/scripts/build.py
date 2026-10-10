#!/usr/bin/env python3
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess

PORT = Path(__file__).resolve().parents[1]
CONFIG = json.loads((PORT / 'config.json').read_text())

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('profile', choices=CONFIG['profiles'])
    args = parser.parse_args()
    profile = CONFIG['profiles'][args.profile]
    source = PORT / '.build' / 'source'
    # Restore only this disposable upstream checkout's tracked files.
    subprocess.run(['git', 'checkout-index', '-a', '-f'], cwd=source, check=True)
    subprocess.run(['git', 'apply', '--ignore-space-change', '--unidiff-zero', str(PORT / 'patches/local12-main.patch')], cwd=source, check=True)
    for path in (PORT / 'sources').iterdir():
        shutil.copy2(path, source / 'Sources' / path.name)
    shutil.copy2(PORT / 'scripts/Tweak.mk', source / 'Makefile')
    sdk = subprocess.check_output(['xcrun', '--sdk', 'iphoneos', '--show-sdk-path'], text=True).strip()
    env = os.environ.copy()
    env['THEOS'] = str(PORT / '.build/theos')
    object_dir = source / '.theos' / ('obj-' + args.profile)
    object_dir.mkdir(parents=True, exist_ok=True)
    command = ['make', '-j4', 'all', f'TARGET=iphone:clang:latest:{profile["minimum_ios"]}',
               f'SDK_PATH={sdk}', f'SYSROOT={sdk}', f'PORT_PROFILE={args.profile}',
               f'PORT_VERSION={CONFIG["version"]}', f'THEOS_PACKAGE_SCHEME={args.profile if args.profile == "rootless" else ""}',
               f'THEOS_OBJ_DIR_NAME=obj-{args.profile}', 'FINALPACKAGE=1', 'DEBUG=0']
    subprocess.run(command, cwd=source, env=env, check=True)
    output = PORT / '.build' / args.profile
    output.mkdir(parents=True, exist_ok=True)
    for name in ('uYouEnhanced', 'YouTubeDislikesReturn'):
        candidates = list(object_dir.rglob(name + '.dylib'))
        if not candidates:
            raise RuntimeError('Missing compiled ' + name)
        # The architecture-specific intermediate is identical before the final strip/sign.
        candidate = object_dir / (name + '.dylib')
        shutil.copy2(candidate if candidate.exists() else candidates[0], output / (name + '.dylib'))

if __name__ == '__main__':
    main()
