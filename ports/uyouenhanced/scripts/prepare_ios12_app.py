#!/usr/bin/env python3
"""Prepare a locally supplied, pinned legacy IPA for Amethyst's rootful package.

No proprietary app is downloaded or included in this repository. Native iOS
requirements are preserved. Requires macOS codesign and an active AppSync device.
"""
import argparse
import hashlib
from pathlib import Path, PurePosixPath
import plistlib
import stat
import struct
import subprocess
import tempfile
import zipfile

SOURCE_SHA256 = 'ea9a9eb3c39ccbfc9f23bd0bf4eb9c1981c1da28e47b0e695a462f7688752a83'
OLD_LIBRARIES = {
    'uYouPlus.dylib', 'uYou.dylib', 'libcolorpicker.dylib', 'iSponsorBlock.dylib',
    'YTUHD.dylib', 'YouPiP.dylib', 'YouTubeDislikesReturn.dylib', 'YoutubeSpeed.dylib',
}
EXCLUDED = (
    'SC_Info/', 'YouPiP.bundle/', 'uYouBundle.bundle/', 'uYouPlus.bundle/',
    'iSponsorBlock.bundle/', 'Frameworks/Alderis.framework/',
    'Frameworks/CydiaSubstrate.framework/', 'PlugIns/OpenYoutubeSafariExtension.appex/',
)
LOAD_PATHS = (
    '/Library/MobileSubstrate/DynamicLibraries/uYouEnhanced.dylib',
    '/Library/MobileSubstrate/DynamicLibraries/YouTubeDislikesReturn.dylib',
)


def replace_old_loads(executable):
    binary = bytearray(executable.read_bytes())
    magic, cpu, _, _, count, size, _, _ = struct.unpack_from('<8I', binary)
    if magic != 0xfeedfacf or cpu != 0x100000c:
        raise ValueError('Expected the pinned thin arm64 Mach-O')
    commands, removed, offset = [], set(), 32
    for _ in range(count):
        command, length = struct.unpack_from('<II', binary, offset)
        if length < 8 or offset + length > 32 + size:
            raise ValueError('Invalid load command boundary')
        chunk = binary[offset:offset + length]
        offset += length
        if command in (0xc, 0x80000018, 0x8000001f, 0x80000023):
            name_offset = struct.unpack_from('<I', chunk, 8)[0]
            name = bytes(chunk[name_offset:]).split(b'\0')[0].decode()
            basename = PurePosixPath(name).name
            if basename in OLD_LIBRARIES:
                removed.add(basename)
                continue
        commands.append(chunk)
    if offset != 32 + size or removed != OLD_LIBRARIES:
        raise ValueError('Pinned embedded library set did not match')
    for name in LOAD_PATHS:
        data = name.encode() + b'\0'
        length = (24 + len(data) + 7) // 8 * 8
        commands.append(struct.pack('<6I', 0xc, length, 24, 0, 0, 0) +
                        data + bytes(length - 24 - len(data)))
    joined = b''.join(commands)
    if len(joined) > size:
        raise ValueError('New commands do not fit existing header space')
    # Keep all section/data offsets unchanged, including the native deployment command.
    binary[32:32 + size] = joined + bytes(size - len(joined))
    struct.pack_into('<II', binary, 16, len(commands), len(joined))
    executable.write_bytes(binary)
    executable.chmod(0o755)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--compact-locales', action='store_true',
                        help='Keep Russian/English/Base resources for faster iOS 12 installation')
    args = parser.parse_args()
    if args.input.resolve() == args.output.resolve():
        parser.error('Input and output must differ')
    if hashlib.sha256(args.input.read_bytes()).hexdigest() != SOURCE_SHA256:
        parser.error('Input is not the pinned developer release')
    with tempfile.TemporaryDirectory(prefix='youtube-ios12-') as temporary:
        stage = Path(temporary)
        with zipfile.ZipFile(args.input) as archive:
            for entry in archive.infolist():
                path = PurePosixPath(entry.filename)
                mode = entry.external_attr >> 16
                if path.is_absolute() or '..' in path.parts or stat.S_ISLNK(mode):
                    raise ValueError('Unsafe archive path')
                if not entry.filename.startswith('Payload/YouTube.app/'):
                    continue
                relative = entry.filename.removeprefix('Payload/YouTube.app/')
                if (relative.startswith(EXCLUDED) or path.name in OLD_LIBRARIES or
                        '_CodeSignature' in path.parts or path.name == 'embedded.mobileprovision'):
                    continue
                if args.compact_locales and any(
                    part.endswith('.lproj') and part not in
                    {'ru.lproj', 'en.lproj', 'en_GB.lproj', 'Base.lproj'} for part in path.parts
                ):
                    continue
                target = stage / entry.filename
                if entry.is_dir():
                    target.mkdir(parents=True, exist_ok=True)
                else:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(archive.read(entry))
                    target.chmod(mode & 0o777 or 0o644)
        app = stage / 'Payload/YouTube.app'
        info = plistlib.loads((app / 'Info.plist').read_bytes())
        if (info.get('CFBundleIdentifier') != 'com.google.ios.youtube' or
                info.get('CFBundleShortVersionString') != '16.42.3' or
                info.get('MinimumOSVersion') != '12.0'):
            raise ValueError('Unexpected native app identity or minimum OS')
        replace_old_loads(app / 'YouTube')
        bundles = sorted((app / 'Frameworks').glob('*.framework'))
        bundles += sorted((app / 'PlugIns').glob('*.appex')) + [app]
        for bundle in bundles:
            subprocess.run(['codesign', '--force', '--sign', '-', '--timestamp=none',
                            str(bundle)], check=True, stdout=subprocess.DEVNULL)
        subprocess.run(['codesign', '--verify', '--deep', str(app)], check=True)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(args.output, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as output:
            for path in sorted(stage.rglob('*')):
                if path.is_file():
                    output.write(path, path.relative_to(stage))
    print('Native version 16.42.3 / minimum iOS 12.0 unchanged; old embedded tweaks removed.')
    print('Rootful package and active Amethyst/AppSync are required; native app data is retained.')
    print('SHA256:', hashlib.sha256(args.output.read_bytes()).hexdigest())


if __name__ == '__main__':
    main()
