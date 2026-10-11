#!/usr/bin/env python3
import hashlib
import argparse
import io
from pathlib import Path, PurePosixPath
import plistlib
import re
import subprocess
import tarfile
import tempfile
from configuration import PORT, LIBRARY_PATH, LIBRARIES, DYLIB_SUFFIX, load_config, package_path

parser = argparse.ArgumentParser()
parser.add_argument('profile',choices=('rootful','rootless'))
profile_name = parser.parse_args().profile
config = load_config()
profile = config['profiles'][profile_name]
deb = package_path(config,profile_name)
control_tar = tarfile.open(fileobj=io.BytesIO(subprocess.check_output(['dpkg-deb','--ctrl-tarfile',str(deb)])))
data = tarfile.open(fileobj=io.BytesIO(subprocess.check_output(['dpkg-deb','--fsys-tarfile',str(deb)])))
members = data.getmembers()
files = {entry.name.removeprefix('./'): entry for entry in members if entry.isfile()}
prefix = profile['prefix'].lstrip('/')
library = (prefix + LIBRARY_PATH).lstrip('/')
assert files and all(name.startswith(library) for name in files), 'Wrong install prefix'
assert all(not PurePosixPath(name).is_absolute() and '..' not in PurePosixPath(name).parts and '\\' not in name for name in files), 'Unsafe archive path'
seen = set()
for entry in members:
    name = entry.name.removeprefix('./')
    assert name not in seen, 'Duplicate archive entry'
    seen.add(name)
    assert entry.isfile() or entry.isdir(), 'Links and special archive entries are not supported'
    assert not PurePosixPath(name).is_absolute() and '..' not in PurePosixPath(name).parts and '\\' not in name, 'Unsafe archive path'
    if name not in ('','.'):
        assert name.startswith(library) or (entry.isdir() and library.startswith(name.rstrip('/')+'/')), 'Entry outside library'
control = control_tar.extractfile('./control').read().decode()
assert f"Architecture: {profile['architecture']}" in control
assert f"Depends: firmware (>= {profile['minimum_ios']})" in control
assert any(name.endswith('/uYou.dylib') for name in files) == profile['bundled_uyou']
for line in control_tar.extractfile('./md5sums').read().decode().splitlines():
    digest, name = line.split('  ',1)
    assert hashlib.md5(data.extractfile(files[name]).read(),usedforsecurity=False).hexdigest() == digest
with tempfile.TemporaryDirectory(dir=PORT / '.build') as temp:
    for name, entry in files.items():
        if name.endswith('.plist') and '/DynamicLibraries/' in name:
            assert plistlib.loads(data.extractfile(entry).read()) == {'Filter':{'Bundles':['com.google.ios.youtube']}}
    expected_libraries = LIBRARIES + (('uYou',) if profile['bundled_uyou'] else ())
    expected_paths = {library + 'MobileSubstrate/DynamicLibraries/' + name + DYLIB_SUFFIX for name in expected_libraries}
    assert {name for name in files if name.endswith(DYLIB_SUFFIX)} == expected_paths, 'Unexpected or missing dylib'
    for basename in expected_libraries:
        # Materialize only explicit known library names, never an archive-provided path.
        entry = files[library + 'MobileSubstrate/DynamicLibraries/' + basename + DYLIB_SUFFIX]
        binary = Path(temp) / (basename + DYLIB_SUFFIX)
        binary.write_bytes(data.extractfile(entry).read())
        arch = subprocess.check_output(['xcrun','lipo','-archs',str(binary)],text=True).strip()
        assert arch == 'arm64', arch
        commands = subprocess.check_output(['xcrun','otool','-l',str(binary)],text=True)
        # Only inspect the deployment load command, not dylib compatibility versions.
        minimum = re.search(r'cmd LC_BUILD_VERSION\s+cmdsize \d+\s+platform \d+\s+minos ([\d.]+)',commands)
        if not minimum:
            minimum = re.search(r'cmd LC_VERSION_MIN_IPHONEOS\s+cmdsize \d+\s+version ([\d.]+)',commands)
        assert minimum, 'No iOS deployment command'
        assert tuple(map(int,minimum[1].split('.'))) <= tuple(map(int,profile['minimum_ios'].split('.'))), minimum[1]
        assert 'LC_DYLD_CHAINED_FIXUPS' not in commands, 'iOS12-incompatible chained fixups'
        dependencies = subprocess.check_output(['xcrun','otool','-L',str(binary)],text=True)
        for line in dependencies.splitlines():
            if not line.startswith('\t'):
                continue
            dependency = line.strip().partition(' (')[0]
            if profile_name == 'rootful':
                assert not dependency.startswith(('@rpath/', '@loader_path/', '@executable_path/')), 'Unbundled iOS 12 dependency: ' + dependency
            if dependency.startswith((LIBRARY_PATH,'/var/jb'+LIBRARY_PATH)):
                assert dependency.startswith(profile['prefix']+LIBRARY_PATH), dependency
        if profile_name == 'rootful' and basename == 'uYouEnhanced':
            assert '/System/Library/Frameworks/CoreMedia.framework/CoreMedia ' in dependencies, 'Use the native CoreMedia provider on iOS 12'
        subprocess.run(['codesign','--verify',str(binary)],check=True)
        print(binary.name, 'arm64, iOS >=', minimum[1], 'signature and dependencies OK')
assert hashlib.sha256(deb.read_bytes()).hexdigest() == deb.with_name(deb.name+'.sha256').read_text().split()[0]
print('PASS:', profile_name, 'DEB paths, controls, all checksums, filters, deployment targets and signatures')
