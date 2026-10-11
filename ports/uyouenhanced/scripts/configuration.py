"""Validate build metadata before it becomes a filename or a Make argument."""
import json
from pathlib import Path
import re

PORT = Path(__file__).resolve().parents[1]
DYLIB_SUFFIX = '.dylib'
LIBRARY_PATH = '/Library/'
LIBRARIES = ('uYouEnhanced', 'YouTubeDislikesReturn')

def load_config():
    config = json.loads((PORT / 'config.json').read_text())
    if not re.fullmatch(r'[0-9A-Za-z.+-]{1,90}', config['version']):
        raise ValueError('Version must be a package-safe filename component')
    for key, count in (('revision',40), ('theos_revision',40), ('base_sha256',64)):
        if not re.fullmatch(r'[0-9a-f]{' + str(count) + '}',config[key]):
            raise ValueError('Invalid pinned ' + key)
    expected = {
        'rootful': {'minimum_ios':'12.2','architecture':'iphoneos-arm','prefix':'','bundled_uyou':False},
        'rootless': {'minimum_ios':'16.0','architecture':'iphoneos-arm64','prefix':'/var/jb','bundled_uyou':True},
    }
    if config['profiles'] != expected:
        raise ValueError('Unexpected install paths, architectures or deployment profiles')
    urls = {'upstream':'https://github.com/arichornlover/uYouEnhanced.git', 'theos':'https://github.com/theos/theos.git'}
    if any(config[key] != value for key,value in urls.items()):
        raise ValueError('Unexpected source repository URL')
    return config

def package_path(config, profile):
    # profile is selected from a literal allowlist; all filename pieces were validated.
    if profile not in ('rootful','rootless'):
        raise ValueError('Unknown profile')
    path = PORT / 'dist' / f"uyouenhanced_{config['version']}_{config['profiles'][profile]['architecture']}.deb"
    resolved = path.resolve()
    if resolved.parent != (PORT / 'dist').resolve():
        raise ValueError('Package must stay inside dist')
    return resolved
