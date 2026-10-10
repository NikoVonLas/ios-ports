#!/usr/bin/env python3
import hashlib
import io
import json
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import tarfile
import tempfile

PORT = Path(__file__).resolve().parents[1]
profile_name, deb_name = sys.argv[1:]
config = json.loads((PORT / 'config.json').read_text())
profile = config['profiles'][profile_name]
deb = Path(deb_name)
control_tar = tarfile.open(fileobj=io.BytesIO(subprocess.check_output(['dpkg-deb','--ctrl-tarfile',str(deb)])))
data = tarfile.open(fileobj=io.BytesIO(subprocess.check_output(['dpkg-deb','--fsys-tarfile',str(deb)])))
files = {entry.name.removeprefix('./'): entry for entry in data if entry.isfile()}
prefix = profile['prefix'].lstrip('/')
library = (prefix + '/Library/').lstrip('/')
assert files and all(name.startswith(library) for name in files), 'Wrong install prefix'
control = control_tar.extractfile('./control').read().decode()
assert f"Architecture: {profile['architecture']}" in control
assert f"Depends: firmware (>= {profile['minimum_ios']})" in control
assert any(name.endswith('/uYou.dylib') for name in files) == profile['bundled_uyou']
for line in control_tar.extractfile('./md5sums').read().decode().splitlines():
    digest, name = line.split('  ',1)
    assert hashlib.md5(data.extractfile(files[name]).read()).hexdigest() == digest
with tempfile.TemporaryDirectory(dir=PORT / '.build') as temp:
    for name, entry in files.items():
        if name.endswith('.plist') and '/DynamicLibraries/' in name:
            assert plistlib.loads(data.extractfile(entry).read()) == {'Filter':{'Bundles':['com.google.ios.youtube']}}
        if not name.endswith('.dylib'):
            continue
        binary = Path(temp) / Path(name).name
        binary.write_bytes(data.extractfile(entry).read())
        arch = subprocess.check_output(['xcrun','lipo','-archs',str(binary)],text=True).strip()
        assert arch == 'arm64', arch
        commands = subprocess.check_output(['xcrun','otool','-l',str(binary)],text=True)
        versions = re.findall(r'(?:minos|version)\s+(\d+\.\d+)', commands)
        # Only inspect the deployment load command, not dylib compatibility versions.
        minimum = re.search(r'cmd LC_BUILD_VERSION\s+cmdsize \d+\s+platform \d+\s+minos ([\d.]+)',commands)
        if not minimum:
            minimum = re.search(r'cmd LC_VERSION_MIN_IPHONEOS\s+cmdsize \d+\s+version ([\d.]+)',commands)
        assert minimum, 'No iOS deployment command'
        assert tuple(map(int,minimum[1].split('.'))) <= tuple(map(int,profile['minimum_ios'].split('.'))), minimum[1]
        assert 'LC_DYLD_CHAINED_FIXUPS' not in commands, 'iOS12-incompatible chained fixups'
        dependencies = subprocess.check_output(['xcrun','otool','-L',str(binary)],text=True)
        for dependency in re.findall(r'^\s+([^ ]+) \(',dependencies,re.M):
            if dependency.startswith(('/Library/','/var/jb/Library/')):
                assert dependency.startswith(profile['prefix']+'/Library/'), dependency
        subprocess.run(['codesign','--verify',str(binary)],check=True)
        print(binary.name, 'arm64, iOS >=', minimum[1], 'signature and dependencies OK')
assert hashlib.sha256(deb.read_bytes()).hexdigest() == deb.with_name(deb.name+'.sha256').read_text().split()[0]
print('PASS:', profile_name, 'DEB paths, controls, all checksums, filters, deployment targets and signatures')
