#!/usr/bin/env python3
import argparse
import hashlib
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
from configuration import PORT, LIBRARIES, load_config, package_path

CONFIG = load_config()

def run(*args):
    subprocess.run(args, check=True)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('profile', choices=CONFIG['profiles'])
    args = parser.parse_args()
    profile = CONFIG['profiles'][args.profile]
    source = PORT / '.build/source'
    build = PORT / '.build' / args.profile
    stage = build / 'stage'
    if stage.exists():
        shutil.rmtree(stage)
    library = stage / (profile['prefix'].lstrip('/') + '/Library').lstrip('/')
    dylibs = library / 'MobileSubstrate/DynamicLibraries'
    resources = library / 'Application Support'
    dylibs.mkdir(parents=True)
    resources.mkdir(parents=True)
    if profile['bundled_uyou']:
        base = source / 'Tweaks/uYou/com.miro.uyou_3.0.4_iphoneos-arm.deb'
        if hashlib.sha256(base.read_bytes()).hexdigest() != CONFIG['base_sha256']:
            raise RuntimeError('Upstream uYou archive checksum changed')
        with tempfile.TemporaryDirectory(dir=build) as temp:
            run('dpkg-deb', '-x', str(base), temp)
            original = Path(temp) / 'Library'
            shutil.copy2(original / 'MobileSubstrate/DynamicLibraries/uYou.dylib', dylibs)
            shutil.copytree(original / 'Application Support/uYouBundle.bundle', resources / 'uYouBundle.bundle')
        base_dylib = dylibs / 'uYou.dylib'
        run('xcrun', 'install_name_tool', '-id', profile['prefix'] + '/Library/MobileSubstrate/DynamicLibraries/uYou.dylib',
            '-change', '/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate',
            profile['prefix'] + '/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate', str(base_dylib))
        shutil.copytree(source / 'Localizations/uYouPlus.bundle', resources / 'uYouPlus.bundle')
    for name in LIBRARIES:
        shutil.copy2(build / (name + '.dylib'), dylibs)
    shutil.copytree(source / 'Tweaks/Return-YouTube-Dislikes/layout/Library/Application Support/RYD.bundle', resources / 'RYD.bundle')
    for dylib in dylibs.glob('*.dylib'):
        run('codesign', '--force', '--sign', '-', '--timestamp=none', str(dylib))
        with dylib.with_suffix('.plist').open('wb') as file:
            plistlib.dump({'Filter': {'Bundles': ['com.google.ios.youtube']}}, file)
    metadata = stage / 'DEBIAN'
    metadata.mkdir()
    metadata.joinpath('control').write_text(f'''Package: com.nikovonlas.uyouenhanced-local
Name: uYouEnhanced Local ({args.profile})
Version: {CONFIG['version']}
Architecture: {profile['architecture']}
Maintainer: NikoVonLas
Author: arichornlover, qnblackcat, MiRO92, PoomSmart, NikoVonLas
Section: Tweaks
Depends: firmware (>= {profile['minimum_ios']}), mobilesubstrate
Conflicts: com.miro.uyou, com.miro.uyourootless, com.miro.uyou-unofficial, com.arichorn.uyouenhanced, com.ichitaso.uyouplus, weeb.lillie.youtubedislikesreturn, com.galacticdev.isponsorblock
Description: Russian offline video library, downloads, SponsorBlock and estimated dislikes
 YouTube-only arm64 injection. Requires a compatible installed YouTube app.
 SponsorBlock segment cache supports offline playback. No YouTube IPA is included.
''')
    sums = []
    for path in sorted(stage.rglob('*')):
        if path.is_file() and 'DEBIAN' not in path.relative_to(stage).parts:
            path.chmod(0o755 if path.suffix == '.dylib' else 0o644)
            # dpkg's md5sums format requires MD5 for non-security integrity checks.
            sums.append(hashlib.md5(path.read_bytes(), usedforsecurity=False).hexdigest() + '  ' + str(path.relative_to(stage)))
    metadata.joinpath('md5sums').write_text('\n'.join(sums) + '\n')
    output = PORT / 'dist'
    output.mkdir(exist_ok=True)
    deb = package_path(CONFIG,args.profile)
    run('dpkg-deb', '-Zgzip', '--root-owner-group', '--build', str(stage), str(deb))
    deb.with_name(deb.name + '.sha256').write_text(hashlib.sha256(deb.read_bytes()).hexdigest() + '  ' + deb.name + '\n')
    run('python3', str(PORT / 'scripts/verify.py'), args.profile)
    print(deb)

if __name__ == '__main__':
    main()
