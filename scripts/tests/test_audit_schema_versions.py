"""Synthetic Git fixtures for the source audit, not app migration evidence."""
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'scripts/audit_schema_versions.py'
spec = importlib.util.spec_from_file_location('audit_schema_versions', SCRIPT)
audit = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = audit
spec.loader.exec_module(audit)


def rule(name='bookmarks', path='lib/export.dart', pattern=r'const schema = (?P<version>[0-9]+);', **extra):
    return {'id': name, 'path': path, 'pattern': pattern, **extra}


class RuleTests(unittest.TestCase):
    def run_audit(self, before, after, rules=None):
        return audit.audit_contracts(rules or [rule()], before.get, after.get)

    def test_unchanged_and_one_increment_pass(self):
        for version in (5, 6):
            with self.subTest(version=version):
                rows = self.run_audit({'lib/export.dart': 'const schema = 5;'}, {'lib/export.dart': f'const schema = {version};'})
                self.assertEqual(rows[0]['status'], 'ok')

    def test_two_increments_fail_without_a_waiver(self):
        rows = self.run_audit({'lib/export.dart': 'const schema = 5;'}, {'lib/export.dart': 'const schema = 7;'})
        self.assertEqual(rows[0]['status'], 'violation')
        self.assertEqual(rows[0]['allowed'], [5, 6])

    def test_decrease_is_not_a_valid_fix_for_published_schema(self):
        self.assertEqual(self.run_audit({'lib/export.dart': 'const schema = 5;'}, {'lib/export.dart': 'const schema = 4;'})[0]['status'], 'violation')

    def test_new_contract_starts_at_one(self):
        for version, status in ((1, 'ok'), (2, 'violation')):
            with self.subTest(version=version):
                self.assertEqual(self.run_audit({}, {'lib/export.dart': f'const schema = {version};'})[0]['status'], status)

    def test_existing_version_zero_is_valid(self):
        self.assertEqual(self.run_audit({'lib/export.dart': 'const schema = 0;'}, {'lib/export.dart': 'const schema = 1;'})[0]['status'], 'ok')

    def test_missing_candidate_is_error_not_retirement_permission(self):
        self.assertEqual(self.run_audit({'lib/export.dart': 'const schema = 5;'}, {})[0]['status'], 'error')

    def test_missing_marker_in_existing_baseline_is_error_not_new_contract(self):
        self.assertEqual(self.run_audit({'lib/export.dart': 'const renamed = 5;'}, {'lib/export.dart': 'const schema = 1;'})[0]['status'], 'error')

    def test_explicit_preexisting_unversioned_source_can_be_reviewed_as_new(self):
        rows = self.run_audit({'lib/export.dart': '// previously unversioned'}, {'lib/export.dart': 'const schema = 1;'}, [rule(baseline_absent=True)])
        self.assertEqual(rows[0]['status'], 'ok')

    def test_absent_assertion_does_not_hide_an_actual_released_version(self):
        rows = self.run_audit({'lib/export.dart': 'const schema = 5;'}, {'lib/export.dart': 'const schema = 1;'}, [rule(baseline_absent=True)])
        self.assertEqual(rows[0]['status'], 'error')

    def test_changed_path_uses_explicit_baseline_locator(self):
        rows = self.run_audit({'lib/old.dart': 'v: 1'}, {'lib/export.dart': 'const schema = 2;'}, [rule(baseline_path='lib/old.dart', baseline_pattern=r'v: (?P<version>[0-9]+)')])
        self.assertEqual(rows[0]['status'], 'ok')
        self.assertEqual(rows[0]['released'], [1])

    def test_multiple_current_versions_are_not_collapsed_to_max(self):
        rows = self.run_audit({'lib/export.dart': 'const schema = 5;'}, {'lib/export.dart': 'const schema = 5;\nconst schema = 6;'})
        self.assertEqual(rows[0]['status'], 'violation')

    def test_repeated_identical_values_are_not_misclassified(self):
        rows = self.run_audit({'lib/export.dart': 'const schema = 5;'}, {'lib/export.dart': 'const schema = 6;\nconst schema = 6;'})
        self.assertEqual(rows[0]['status'], 'ok')

    def test_shared_source_schema_is_not_a_new_sync_protocol(self):
        rules = [rule(), rule('sync', 'lib/sync.dart', same_as='bookmarks')]
        rows = self.run_audit({'lib/export.dart': 'const schema = 5;'}, {'lib/export.dart': 'const schema = 6;', 'lib/sync.dart': 'const schema = 6;'}, rules)
        self.assertEqual([r['status'] for r in rows], ['ok', 'ok'])

    def test_shared_symbol_counts_as_final_reader_and_fails_when_missing(self):
        legacy = r'reads (?P<version>[0-9]+)'
        rules = [
            rule(),
            rule('reader', 'lib/reader.dart',
                 r'reads (?P<version>[0-9]+|schema)',
                 baseline_pattern=legacy, reader_for='bookmarks',
                 shared_symbol='schema'),
        ]
        before = {'lib/export.dart': 'const schema = 5;', 'lib/reader.dart': 'reads 4; reads 5;'}
        after = {'lib/export.dart': 'const schema = 6;', 'lib/reader.dart': 'reads 4; reads 5;'}
        self.assertEqual(self.run_audit(before, after, rules)[1]['status'], 'error')
        after['lib/reader.dart'] += ' reads schema;'
        row = self.run_audit(before, after, rules)[1]
        self.assertEqual(row['status'], 'ok')
        self.assertEqual(row['current'], [4, 5, 6])

    def test_alias_mismatch_and_alias_of_violation_fail(self):
        for primary, alias in ((6, 5), (10, 10)):
            with self.subTest(primary=primary, alias=alias):
                rows = self.run_audit({'lib/export.dart': 'const schema = 5;'}, {'lib/export.dart': f'const schema = {primary};', 'lib/sync.dart': f'const schema = {alias};'}, [rule(), rule('sync', 'lib/sync.dart', same_as='bookmarks')])
                self.assertEqual(rows[1]['status'], 'violation')

    def test_unknown_alias_and_alias_cycle_are_errors(self):
        with self.assertRaises(audit.AuditError):
            self.run_audit({}, {}, [rule(same_as='missing')])
        with self.assertRaises(audit.AuditError):
            self.run_audit({}, {}, [rule(same_as='sync'), rule('sync', same_as='bookmarks')])

    def test_rules_are_validated_without_arbitrary_traversal_or_duplicate_ids(self):
        for rules in ([rule(path='../secret')], [rule(), rule()], [rule(pattern='no capture')]):
            with self.subTest(rules=rules), self.assertRaises(audit.AuditError):
                self.run_audit({}, {}, rules)

    def test_reader_ceiling_flags_unreleased_intermediate_readers(self):
        rules = [rule(), rule('reader', 'lib/reader.dart', r'metadata.version != (?P<version>[0-9]+)', reader_for='bookmarks')]
        before = {'lib/export.dart': 'const schema = 5;', 'lib/reader.dart': 'metadata.version != 4; metadata.version != 5;'}
        after = {'lib/export.dart': 'const schema = 6;', 'lib/reader.dart': 'metadata.version != 4; metadata.version != 5; metadata.version != 6; metadata.version != 9;'}
        self.assertEqual(self.run_audit(before, after, rules)[1]['status'], 'violation')

    def test_reader_preserves_released_versions(self):
        rules = [rule(), rule('reader', 'lib/reader.dart', r'metadata.version != (?P<version>[0-9]+)', reader_for='bookmarks')]
        before = {'lib/export.dart': 'const schema = 5;', 'lib/reader.dart': 'metadata.version != 4; metadata.version != 5;'}
        after = {'lib/export.dart': 'const schema = 6;', 'lib/reader.dart': 'metadata.version != 5; metadata.version != 6;'}
        self.assertEqual(self.run_audit(before, after, rules)[1]['status'], 'violation')

    def test_conditional_writer_keeps_all_operation_versions_visible(self):
        rules = [rule(pattern=r"'version': (?P<version>[^,]+),", literal_ternary=True)]
        row = self.run_audit({}, {'lib/export.dart': "'version': mirrors != null ? 4 : restore ? 3 : organization == null ? 1 : 2,"}, rules)[0]
        self.assertEqual(row['current'], [1, 2, 3, 4])
        self.assertEqual(row['status'], 'violation')

    def test_unknown_dynamic_version_fails_closed(self):
        rules = [rule(pattern=r"'version': (?P<version>[^,]+),", literal_ternary=True)]
        self.assertEqual(self.run_audit({}, {'lib/export.dart': "'version': latest(),"}, rules)[0]['status'], 'error')

    def test_comments_do_not_invent_an_extra_writer(self):
        rows = self.run_audit({'lib/export.dart': 'const schema = 5;'}, {'lib/export.dart': 'const schema = 6; // const schema = 99;\n/* const schema = 100; */'})
        self.assertEqual(rows[0]['current'], [6])


class GitTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.git('init', '-q')
        self.git('config', 'user.email', 'fixture@example.invalid')
        self.git('config', 'user.name', 'Schema audit test')
        self.write('lib/export.dart', 'const schema = 5;\n')
        self.base = self.commit('published')
        self.write('lib/export.dart', 'const schema = 6;\n')
        self.head = self.commit('candidate')
        self.contracts = self.repo / 'contracts.json'
        self.contracts.write_text(json.dumps({'baseline_commit': self.base, 'contracts': [rule()]}), encoding='utf-8')

    def git(self, *args):
        return subprocess.run(['git', '-C', str(self.repo), *args], check=True, capture_output=True, text=True).stdout.strip()

    def write(self, name, value):
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(value, encoding='utf-8')

    def commit(self, message):
        self.git('add', 'lib')
        self.git('commit', '-qm', message)
        return self.git('rev-parse', 'HEAD')

    def cli(self, *args):
        return subprocess.run([sys.executable, str(SCRIPT), '--repo', str(self.repo), '--contracts', str(self.contracts), '--baseline', self.base, '--candidate', self.head, *args], capture_output=True, text=True)

    def test_cli_reads_pinned_trees_not_dirty_worktree(self):
        self.write('lib/export.dart', 'const schema = 99;\n')
        result = self.cli('--json')
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        self.assertEqual(data['baseline'], self.base)
        self.assertEqual(data['candidate'], self.head)
        self.assertEqual(data['contracts'][0]['current'], [6])

    def test_cli_violation_is_nonzero(self):
        self.write('lib/export.dart', 'const schema = 10;\n')
        self.head = self.commit('too many')
        self.assertEqual(self.cli().returncode, 1)

    def test_unknown_ref_and_bad_regex_fail_closed(self):
        self.assertEqual(self.cli('--baseline', 'absent-reference').returncode, 2)
        self.contracts.write_text('{"contracts":[{"id":"x","path":"lib/export.dart","pattern":"["}]}')
        self.assertEqual(self.cli().returncode, 2)

    def test_symlink_is_not_read_as_a_schema(self):
        self.git('rm', 'lib/export.dart')
        (self.repo / 'lib').mkdir(exist_ok=True)
        (self.repo / 'lib/export.dart').symlink_to('/etc/passwd')
        self.head = self.commit('symlink')
        self.assertEqual(self.cli().returncode, 2)

    def test_inventory_reports_changes_in_unregistered_version_markers(self):
        self.write('lib/new.dart', "const payloadVersion = 3;\n// schemaVersion = 90\n")
        self.head = self.commit('new contract')
        data = json.loads(self.cli('--json', '--inventory').stdout)
        self.assertTrue(any(row['path'] == 'lib/new.dart' for row in data['review_candidates']))

    def test_catalog_validation_is_non_destructive(self):
        self.write('lib/unrelated.txt', 'preserve me\n')
        before = self.git('status', '--porcelain')
        self.cli()
        self.assertEqual(self.git('status', '--porcelain'), before)

    def test_new_public_baseline_requires_catalog_refresh(self):
        result = self.cli('--baseline', self.head)
        self.assertEqual(result.returncode, 2)
        self.assertIn('Catalog baseline differs', result.stderr)

    def test_invalid_utf8_is_incomplete(self):
        (self.repo / 'lib/export.dart').write_bytes(b'\xff')
        self.head = self.commit('invalid source')
        self.assertEqual(self.cli().returncode, 2)

    def test_duplicate_catalog_keys_are_rejected(self):
        self.contracts.write_text('{"contracts":[],"contracts":[]}')
        self.assertEqual(self.cli().returncode, 2)

class CatalogPatternTests(unittest.TestCase):
    """Minimal source syntax samples for the registered candidate locators."""

    def samples(self):
        catalog = json.loads((ROOT / 'scripts/schema_contracts.json').read_text())
        before, after = {}, {}
        constants = {
            'bookmark-export': ('kBookmarksBackupVersion', 5, 6),
            'profiles-export': ('kBooruConfigsExporterImporterVersion', 1, 1),
            'settings-export': ('kSettingsBackupVersion', 1, 1),
            'favorite-tags-export': ('kFavoriteTagsBackupVersion', 1, 1),
            'blacklist-export': ('kBlacklistedTagsBackupVersion', 1, 1),
            'export-container': ('kExportPackageFormatVersion', 1, 1),
            'downloads-sqlite': ('_kDownloadVersion', 2, 2),
            'history-sqlite': ('_kSearchHistoryVersion', 0, 0),
            'post-common-snapshot': ('commonSchemaVersion', 2, 2),
            'mitemite-protocol': ('miteMiteProtocol', None, 1),
        }
        final_only = {
            'mitemite-bookmark-payload': 'static const schema = kBookmarksBackupVersion;',
            'mitemite-following-payload': 'static const schema = 2;',
            'group-snapshot': 'this.schemaVersion = 1,',
            'bookmark-mutation-journal': "final journal = {'version': 1, 'operation': kind};",
            'bookmark-repository-schema': '_metadata.put(_schema, 1);',
            'bookmark-mirror-state': "'version': 1, 'epoch': epoch,",
            'post-listed-payload': 'static const payloadVersion = 1;',
            'mitemite-activity': "'version': 1, 'sequence': sequence,",
            'mitemite-local-events': "'version': 1, 'notificationOutbox': outbox,",
            'mitemite-notification-outbox': "'version': 1, 'unseenOffers': receipts,",
            'following-mirror-rollback': "'version': 1, 'metadataEncoding': 'typedMaps',",
            'mitemite-notification-intent': "static const payloadPrefix = 'mitemite:v1:';",
            'following-mirror-state': "'version': 1, 'epoch': epoch,",
        }
        for rule_ in catalog['contracts']:
            name, path = rule_['id'], rule_['path']
            if name in constants:
                symbol, old, new = constants[name]
                if old is not None:
                    before[rule_.get('baseline_path', path)] = f'const {symbol} = {old};'
                after[path] = f'const {symbol} = {new};'
            elif name in final_only:
                after[path] = after.get(path, '') + '\n' + final_only[name]
            elif name == 'bookmark-import-readers':
                legacy = 'metadata.version != 4 && metadata.version != 5'
                before[path] = legacy
                after[path] = f'final nested = metadata.version == kBookmarksBackupVersion; {legacy}'
            elif name in ('following-export', 'feeds-export'):
                cls, v = ('FollowingTopicsBackupSource', 2) if name == 'following-export' else ('TopicFeedsBackupSource', 1)
                before[path] = after[path] = f'class {cls} {{ version: {v}, }}'
            elif name == 'link-file':
                before[path] = after[path] = "'format': 'boorusama-link', 'version': 1,"
            elif name == 'post-gelbooru-v2-payload':
                before[path] = after[path] = 'int get currentVersion => 2;'
            elif name == 'bookmark-organization':
                before[rule_['baseline_path']] = "await storage.put('version', 1);"
                after[path] = 'static const schemaVersion = 2;'
            else:
                self.fail('Add a source-syntax sample for ' + name)
        return catalog['contracts'], before, after

    def test_reviewed_locators_still_reject_the_four_original_contract_violations(self):
        rules, before, after = self.samples()
        paths = {r['id']: r['path'] for r in rules}
        after[paths['bookmark-export']] = 'const kBookmarksBackupVersion = 10;'
        after[paths['bookmark-organization']] = 'static const schemaVersion = 3;'
        repository = paths['bookmark-repository-schema']
        after[repository] = after[repository].replace('_schema, 1', '_schema, 2')
        after[repository] = after[repository].replace("'version': 1", "'version': 4")
        rows = audit.audit_contracts(rules, before.get, after.get)
        self.assertEqual({r['id'] for r in rows if r['status'] != 'ok'}, {
            'bookmark-export', 'bookmark-import-readers', 'mitemite-bookmark-payload',
            'bookmark-organization', 'bookmark-repository-schema', 'bookmark-mutation-journal',
        })
        self.assertFalse(any(r['status'] == 'error' for r in rows))

    def test_zero_or_one_increment_passes_for_all_registered_contracts(self):
        rules, before, after = self.samples()
        rows = audit.audit_contracts(rules, before.get, after.get)
        self.assertEqual(len(rows), 29)
        self.assertEqual({r['status'] for r in rows}, {'ok'})


if __name__ == '__main__':
    unittest.main()
