#!/usr/bin/env python3
import argparse
import os
from pathlib import Path
import shutil
import subprocess
from configuration import PORT, DYLIB_SUFFIX, LIBRARIES, load_config

CONFIG = load_config()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('profile', choices=CONFIG['profiles'])
    args = parser.parse_args()
    profile = CONFIG['profiles'][args.profile]
    source = PORT / '.build' / 'source'
    # Restore only this disposable upstream checkout's tracked files.
    subprocess.run(['git', 'checkout-index', '-a', '-f'], cwd=source, check=True)
    subprocess.run(['git', 'apply', '--ignore-space-change', '--unidiff-zero', str(PORT / 'patches/local12-main.patch')], cwd=source, check=True)
    subprocess.run(['git', 'apply', '--ignore-space-change', str(PORT / 'patches/remove-player-repeat.patch')], cwd=source, check=True)
    # Remove obsolete port files in this disposable checkout before wildcard builds.
    own_names = {path.name for path in (PORT / 'sources').iterdir()}
    for installed in (source / 'Sources').glob('UYT*'):
        if installed.is_file() and installed.name not in own_names:
            installed.unlink()
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
    for name in LIBRARIES:
        candidates = list(object_dir.rglob(name + DYLIB_SUFFIX))
        if not candidates:
            raise RuntimeError('Missing compiled ' + name)
        # The architecture-specific intermediate is identical before the final strip/sign.
        candidate = object_dir / (name + DYLIB_SUFFIX)
        shutil.copy2(candidate if candidate.exists() else candidates[0], output / (name + DYLIB_SUFFIX))

if __name__ == '__main__':
    main()
