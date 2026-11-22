"""Synthetic tests for the comparison helper, not released-data migration tests."""
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'compare_upgrade_snapshots.py'
spec = importlib.util.spec_from_file_location('compare_upgrade_snapshots', SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def snapshot():
    return {
        'profiles': [{'id': 'profile-a', 'order': 0, 'has_credentials': False}],
        'settings': {'refresh': False, 'profile_order': ['profile-a']},
        'bookmarks': {'records': [{'id': 7, 'tags': ['first', 'second']}],
                      'groups': [{'id': 'group-a', 'members': [7]}]},
        'following_topics': [{'id': 'topic-a', 'profile_id': 'profile-a'}],
        'topic_feeds': [],
        'favorite_tags': ['one'],
        'blacklisted_tags': [],
        'downloads': [],
        'search_history': [],
    }


class ComparisonTests(unittest.TestCase):
    def test_identical_complete_observations_match(self):
        self.assertEqual(module.differences(snapshot(), copy.deepcopy(snapshot())), [])

    def test_dictionary_order_does_not_change_semantics(self):
        first = snapshot()
        self.assertEqual(module.differences(first, dict(reversed(list(first.items())))), [])

    def test_missing_records_are_reported(self):
        after = snapshot()
        after['bookmarks']['records'].clear()
        self.assertTrue(module.differences(snapshot(), after))

    def test_equal_counts_do_not_conceal_changed_identity(self):
        after = snapshot()
        after['bookmarks']['records'][0]['id'] = 8
        self.assertIn('/bookmarks/records/0/id', module.differences(snapshot(), after)[0])

    def test_array_order_is_significant(self):
        after = snapshot()
        after['bookmarks']['records'][0]['tags'].reverse()
        self.assertTrue(module.differences(snapshot(), after))

    def test_boolean_does_not_equal_integer(self):
        after = snapshot()
        after['settings']['refresh'] = 0
        self.assertTrue(module.differences(snapshot(), after))

    def test_integer_does_not_equal_float(self):
        after = snapshot()
        after['bookmarks']['records'][0]['id'] = 7.0
        self.assertTrue(module.differences(snapshot(), after))

    def test_unknown_fields_are_not_silently_ignored(self):
        after = snapshot()
        after['settings']['new_field'] = True
        self.assertTrue(module.differences(snapshot(), after))

    def test_null_is_not_missing(self):
        after = snapshot()
        after['settings']['nullable'] = None
        self.assertTrue(module.differences(snapshot(), after))

    def test_comparison_never_prints_values(self):
        after = snapshot()
        after['profiles'][0]['id'] = 'DO-NOT-PRINT-THIS-VALUE'
        self.assertNotIn('DO-NOT-PRINT', '\n'.join(module.differences(snapshot(), after)))

    def test_json_pointer_keys_are_escaped(self):
        self.assertIn('/a~1b~0c', module.differences({'a/b~c': 1}, {'a/b~c': 2})[0])

    def test_difference_output_is_bounded(self):
        self.assertEqual(len(module.differences(list(range(100)), [-1] * 100)), 20)


class InputAndCliTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)

    def write(self, name, data):
        path = self.root / name
        path.write_text(json.dumps(data), encoding='utf-8')
        return path

    def raw(self, data):
        path = self.root / 'raw.json'
        path.write_text(data, encoding='utf-8')
        return path

    def cli(self, *paths):
        return subprocess.run([sys.executable, str(SCRIPT), *map(str, paths)],
                              text=True, capture_output=True, timeout=10)

    def test_complete_input_is_loaded(self):
        self.assertEqual(module.load_snapshot(self.write('full.json', snapshot())), snapshot())

    def test_missing_domain_is_rejected(self):
        data = snapshot()
        del data['downloads']
        with self.assertRaises(module.SnapshotError):
            module.load_snapshot(self.write('partial.json', data))

    def test_count_only_domain_is_rejected(self):
        data = snapshot()
        data['bookmarks'] = 10
        with self.assertRaises(module.SnapshotError):
            module.load_snapshot(self.write('counts.json', data))

    def test_duplicate_json_keys_are_rejected(self):
        with self.assertRaises(module.SnapshotError):
            module.load_snapshot(self.raw('{"settings": {}, "settings": []}'))

    def test_non_json_number_is_rejected(self):
        with self.assertRaises(module.SnapshotError):
            module.load_snapshot(self.raw('{"value": NaN}'))

    def test_overflowing_float_is_rejected(self):
        with self.assertRaises(module.SnapshotError):
            module.load_snapshot(self.raw('{"value": 1e999}'))

    def test_non_object_root_is_rejected(self):
        with self.assertRaises(module.SnapshotError):
            module.load_snapshot(self.raw('[]'))

    def test_invalid_utf8_is_rejected(self):
        path = self.root / 'bytes.json'
        path.write_bytes(b'\xff')
        with self.assertRaises(module.SnapshotError):
            module.load_snapshot(path)

    def test_excessive_nesting_is_rejected(self):
        data = snapshot()
        nested = []
        for _ in range(70):
            nested = [nested]
        data['settings']['nested'] = nested
        with self.assertRaises(module.SnapshotError):
            module.load_snapshot(self.write('deep.json', data))

    def test_file_size_is_bounded(self):
        path = self.root / 'large.json'
        path.write_bytes(b' ' * (module.MAX_BYTES + 1))
        with self.assertRaises(module.SnapshotError):
            module.load_snapshot(path)

    def test_cli_compares_first_start_and_cold_reopen(self):
        paths = [self.write(name, snapshot()) for name in ('expected', 'first', 'cold')]
        result = self.cli(*paths)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('not proof', result.stdout)

    def test_cli_detects_cold_restart_loss(self):
        before = self.write('expected', snapshot())
        first = self.write('first', snapshot())
        data = snapshot()
        data['following_topics'].clear()
        result = self.cli(before, first, self.write('cold', data))
        self.assertEqual(result.returncode, 1)
        self.assertIn('cold reopen', result.stderr)

    def test_cli_detects_first_start_loss_even_if_later_restored(self):
        before = self.write('expected', snapshot())
        after = snapshot()
        after['downloads'].append({'id': 'unexpected'})
        result = self.cli(before, self.write('first', after), self.write('cold', snapshot()))
        self.assertEqual(result.returncode, 1)
        self.assertIn('first start', result.stderr)

    def test_cli_missing_file_is_input_error(self):
        result = self.cli(self.root / 'absent', self.root / 'also-absent', self.root / 'third')
        self.assertEqual(result.returncode, 2)
        self.assertNotIn('Traceback', result.stderr)

    def test_cli_rejects_reusing_same_capture_path(self):
        path = self.write('same', snapshot())
        self.assertEqual(self.cli(path, path, path).returncode, 2)

    def test_cli_rejects_missing_arguments(self):
        self.assertEqual(self.cli().returncode, 2)


if __name__ == '__main__':
    unittest.main()
