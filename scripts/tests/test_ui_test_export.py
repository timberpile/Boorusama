"""Host-side contract tests; no app backend or device is mocked by the MVP."""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import ui_test_export as exports


def fixture(root):
    part = b'{"version":1,"data":[{"name":"Anonymous","apiKey":null}]}\n'
    (root / 'data').mkdir()
    (root / 'data/profiles.json').write_bytes(part)
    manifest = {
        'format': 'boorusama-export', 'formatVersion': 1,
        'exportId': 'ui-test-example', 'createdAt': '2026-10-20T00:00:00Z',
        'appVersion': '1.0.0', 'preset': 'custom', 'containsCredentials': False,
        'sources': [{'id': 'profiles', 'schemaVersion': 1, 'parts': [{
            'path': 'data/profiles.json', 'sha256': hashlib.sha256(part).hexdigest(),
            'byteLength': len(part),
        }]}],
    }
    (root / 'manifest.json').write_text(json.dumps(manifest))
    return manifest


class ExportTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.source = self.root / 'source'
        self.source.mkdir()
        self.manifest = fixture(self.source)
        self.archive = self.root / 'scenario.bsexport'

    def update_manifest(self):
        (self.source / 'manifest.json').write_text(json.dumps(self.manifest))

    def test_edit_pack_unpack_roundtrip_recomputes_checksums(self):
        edited = b'{"version":1,"data":[{"name":"Edited"}]}\n'
        (self.source / 'data/profiles.json').write_bytes(edited)
        exports.pack(self.source, self.archive)
        manifest, parts = exports.read_package(self.archive)
        part = manifest['sources'][0]['parts'][0]
        self.assertEqual(part['sha256'], hashlib.sha256(edited).hexdigest())
        self.assertEqual(part['byteLength'], len(edited))
        target = self.root / 'unpacked'
        exports.unpack(self.archive, target)
        self.assertEqual(json.loads((target / 'data/profiles.json').read_bytes()), json.loads(edited))
        self.assertEqual(parts['data/profiles.json'], edited)
        second = self.root / 'second.bsexport'
        exports.pack(target, second)
        exports.read_package(second)

    def test_pack_is_reproducible(self):
        exports.pack(self.source, self.archive)
        second = self.root / 'second.bsexport'
        exports.pack(self.source, second)
        self.assertEqual(self.archive.read_bytes(), second.read_bytes())

    def test_rejects_unsafe_manifest_paths(self):
        for value in ('../outside', '/absolute', 'C:/outside', 'data/../outside', 'data\\outside'):
            with self.subTest(value=value):
                self.manifest['sources'][0]['parts'][0]['path'] = value
                self.update_manifest()
                with self.assertRaises(ValueError):
                    exports.pack(self.source, self.archive)
                self.assertFalse(self.archive.exists())

    def test_rejects_symlink_part(self):
        part = self.source / 'data/profiles.json'
        part.unlink()
        outside = self.root / 'private.json'
        outside.write_text('{}')
        part.symlink_to(outside)
        with self.assertRaises(ValueError):
            exports.pack(self.source, self.archive)

    def test_rejects_credentials_even_with_false_manifest_flag(self):
        (self.source / 'data/profiles.json').write_text('{"apiKey":"do-not-print-this"}')
        with self.assertRaises(ValueError) as error:
            exports.pack(self.source, self.archive)
        self.assertNotIn('do-not-print-this', str(error.exception))

    def test_rejects_explicit_private_export(self):
        self.manifest['containsCredentials'] = True
        self.update_manifest()
        with self.assertRaises(ValueError):
            exports.pack(self.source, self.archive)

    def test_rejects_missing_part_before_writing_archive(self):
        (self.source / 'data/profiles.json').unlink()
        with self.assertRaises((ValueError, OSError)):
            exports.pack(self.source, self.archive)
        self.assertFalse(self.archive.exists())

    def test_rejects_tampered_archive_without_extracting(self):
        with zipfile.ZipFile(self.archive, 'w') as z:
            z.writestr('manifest.json', json.dumps(self.manifest))
            z.writestr('data/profiles.json', '{}')
        target = self.root / 'unpacked'
        with self.assertRaises(ValueError):
            exports.unpack(self.archive, target)
        self.assertFalse(target.exists())

    def test_rejects_unlisted_archive_member(self):
        exports.pack(self.source, self.archive)
        with zipfile.ZipFile(self.archive, 'a') as z:
            z.writestr('../outside', 'bad')
        with self.assertRaises(ValueError):
            exports.read_package(self.archive)

    def test_rejects_repeated_part(self):
        self.manifest['sources'][0]['parts'] *= 2
        self.update_manifest()
        with self.assertRaises(ValueError):
            exports.pack(self.source, self.archive)

    def test_does_not_overwrite_existing_files_or_directories(self):
        exports.pack(self.source, self.archive)
        before = self.archive.read_bytes()
        with self.assertRaises(FileExistsError):
            exports.pack(self.source, self.archive)
        with self.assertRaises(FileExistsError):
            exports.unpack(self.archive, self.source)
        self.assertEqual(self.archive.read_bytes(), before)


if __name__ == '__main__':
    unittest.main()
