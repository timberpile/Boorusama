"""Verify the smoke-test label with fake binaries; never connects to Android."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / '.github/scripts/verify-android-upgrade.sh'


class InstallerSmokeScopeTests(unittest.TestCase):
    def test_success_does_not_claim_data_migration(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name, text in {
                'apkanalyzer': '#!/bin/sh\ncase "$3" in old.apk) echo 4191;; *) echo 4192;; esac\n',
                'adb': '#!/bin/sh\ncase "$*" in\n"shell pm list packages") echo package:com.timberpile.boorusama;;\n"shell dumpsys package com.timberpile.boorusama") printf "versionCode=4192\\nversionName=4.6.1-timberpile.3\\n";;\n"install old.apk"|"install -r new.apk") :;;\n*) exit 99;;\nesac\n',
            }.items():
                path = root / name
                path.write_text(text, encoding='utf-8')
                path.chmod(0o755)
            result = subprocess.run(
                ['bash', str(SCRIPT), 'old.apk', 'new.apk',
                 'com.timberpile.boorusama', '4.6.1-timberpile.3', '192'],
                env={**os.environ, 'PATH': str(root) + os.pathsep + os.environ['PATH']},
                capture_output=True, text=True, timeout=10,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('INSTALLER SMOKE ONLY', result.stdout)
            self.assertIn('No persisted-data migration was verified', result.stdout)


if __name__ == '__main__':
    unittest.main()
