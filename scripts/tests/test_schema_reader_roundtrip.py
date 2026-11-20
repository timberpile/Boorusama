"""A declared reader must accept the writer's current schema as well as old ones."""
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'scripts/audit_schema_versions.py'
spec = importlib.util.spec_from_file_location('schema_reader_audit', SCRIPT)
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)

RULES = [
    {'id': 'writer', 'path': 'lib/writer.dart',
     'pattern': r'const schema = (?P<version>[0-9]+);'},
    {'id': 'reader', 'path': 'lib/reader.dart',
     'pattern': r'reads (?P<version>[0-9]+);', 'reader_for': 'writer'},
]
BASE = {'lib/writer.dart': 'const schema = 5;',
        'lib/reader.dart': 'reads 4; reads 5;'}


class ReaderRoundtripTests(unittest.TestCase):
    def result(self, reader, writer=6):
        current = {'lib/writer.dart': f'const schema = {writer};',
                   'lib/reader.dart': reader}
        return audit.audit_contracts(RULES, BASE.get, current.get)[1]['status']

    def test_old_readers_without_current_writer_are_rejected(self):
        self.assertEqual(self.result('reads 4; reads 5;'), 'violation')

    def test_complete_published_and_current_readers_pass(self):
        self.assertEqual(self.result('reads 4; reads 5; reads 6;'), 'ok')

    def test_unchanged_writer_and_readers_pass(self):
        self.assertEqual(self.result('reads 4; reads 5;', writer=5), 'ok')

    def test_missing_published_reader_remains_rejected(self):
        self.assertEqual(self.result('reads 5; reads 6;'), 'violation')

    def test_extra_unreleased_reader_remains_rejected(self):
        self.assertEqual(self.result('reads 4; reads 5; reads 6; reads 7;'), 'violation')

    def test_cli_rejects_old_only_reader_on_a_new_writer_commit(self):
        with tempfile.TemporaryDirectory() as temp:
            repo = Path(temp)

            def git(*args):
                return subprocess.run(['git', '-C', str(repo), *args],
                                      check=True, capture_output=True,
                                      text=True).stdout.strip()

            git('init', '-q')
            git('config', 'user.name', 'Schema fixture')
            git('config', 'user.email', 'fixture@example.invalid')
            (repo / 'lib').mkdir()
            for path, source in BASE.items():
                (repo / path).write_text(source, encoding='utf-8')
            git('add', 'lib')
            git('commit', '-qm', 'published fixture')
            base = git('rev-parse', 'HEAD')
            (repo / 'lib/writer.dart').write_text('const schema = 6;', encoding='utf-8')
            git('add', 'lib')
            git('commit', '-qm', 'writer changed without its reader')
            catalog = repo / 'contracts.json'
            catalog.write_text(json.dumps({'baseline_commit': base, 'contracts': RULES}), encoding='utf-8')
            result = subprocess.run(
                [sys.executable, str(SCRIPT), '--repo', str(repo),
                 '--contracts', str(catalog), '--baseline', base,
                 '--candidate', 'HEAD', '--json'],
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertEqual(json.loads(result.stdout)['contracts'][1]['status'], 'violation')


if __name__ == '__main__':
    unittest.main()
