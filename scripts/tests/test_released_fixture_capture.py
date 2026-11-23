"""Check capture admission only; no released writer or Flutter process is run."""
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / 'fixtures/capture_released_bookmarks.sh'
TAGS = ('v4.5.0-timberpile.3', 'v4.5.0-timberpile.4', 'v4.5.0-timberpile.5',
        'v4.6.1-timberpile.1', 'v4.6.1-timberpile.2', 'v4.6.1-timberpile.3')


class FixtureCaptureAdmissionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.repo, self.output = root / 'checkout', root / 'output'
        self.repo.mkdir()
        self.git('init', '-q')
        self.git('config', 'user.email', 'fixture@example.invalid')
        self.git('config', 'user.name', 'Capture admission fixture')
        self.git('commit', '--allow-empty', '-qm', 'synthetic checkout')
        self.git('checkout', '--detach', '-q')
        self.head = self.git('rev-parse', 'HEAD')

    def git(self, *args):
        return subprocess.run(['git', '-C', str(self.repo), *args],
                              capture_output=True, text=True, check=True).stdout.strip()

    def test_existing_json_is_not_proof_of_completed_capture(self):
        for tag in TAGS:
            target = self.output / tag
            target.mkdir(parents=True)
            (target / 'bookmarks.json').write_bytes(b'')
        result = subprocess.run(['bash', str(SCRIPT), str(self.repo), str(self.output)],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn('fresh output directory', result.stderr)
        self.assertEqual(self.git('rev-parse', 'HEAD'), self.head)
        for tag in TAGS:
            self.assertEqual((self.output / tag / 'bookmarks.json').read_bytes(), b'')

    def test_later_existing_capture_is_detected_before_switching_tags(self):
        target = self.output / TAGS[-1]
        target.mkdir(parents=True)
        (target / 'owner-data').write_bytes(b'preserve')
        result = subprocess.run(['bash', str(SCRIPT), str(self.repo), str(self.output)],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn('fresh output directory', result.stderr)
        self.assertEqual(self.git('rev-parse', 'HEAD'), self.head)
        self.assertEqual((target / 'owner-data').read_bytes(), b'preserve')
        self.assertFalse((self.output / TAGS[0]).exists())


if __name__ == '__main__':
    unittest.main()
