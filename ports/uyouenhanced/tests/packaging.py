import copy
import json
from pathlib import Path
import tempfile
import unittest
import configuration

class PackagingInputTests(unittest.TestCase):
    def test_cli_profile_cannot_be_a_path_or_option(self):
        config=configuration.load_config()
        for profile in ('../rootful','--help','unknown'):
            with self.assertRaises(ValueError):
                configuration.package_path(config,profile)

    def test_untrusted_metadata_cannot_escape_artifact_directory(self):
        original=configuration.PORT
        clean=configuration.load_config()
        try:
            with tempfile.TemporaryDirectory(dir=original/'.build') as directory:
                configuration.PORT=Path(directory)
                for field,value in (('version','../../escape'),('version','v1 --help'),('revision','--help')):
                    config=copy.deepcopy(clean); config[field]=value
                    (configuration.PORT/'config.json').write_text(json.dumps(config))
                    with self.assertRaises(ValueError): configuration.load_config()
                config=copy.deepcopy(clean); config['profiles']['rootful']['prefix']='../../escape'
                (configuration.PORT/'config.json').write_text(json.dumps(config))
                with self.assertRaises(ValueError): configuration.load_config()
        finally:
            configuration.PORT=original

if __name__=='__main__':
    unittest.main()
