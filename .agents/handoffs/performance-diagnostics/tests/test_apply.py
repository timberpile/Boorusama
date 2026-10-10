import importlib.util
import json
from pathlib import Path
import tempfile
import subprocess
import unittest

ROOT=Path(__file__).parents[1]
spec=importlib.util.spec_from_file_location('apply_diagnostics',ROOT/'apply.py')
apply=importlib.util.module_from_spec(spec)
spec.loader.exec_module(apply)

class ApplyTests(unittest.TestCase):
    def test_expression_wrapper_preserves_named_arguments_and_string_delimiters(self):
        text="Widget build() => Scope(child: Text('})['), items: {'a': [1, 2]});\n"
        result=apply.transform(text,[{'kind':'expression','target':'Widget build() => Scope(',
            'expression_offset':len('Widget build() => '),'prefix':'Outer(child: ','suffix':')'}])
        self.assertEqual(result,"Widget build() => Outer(child: Scope(child: Text('})['), items: {'a': [1, 2]}));\n")

    def test_matching_handles_nested_comments_raw_strings_and_multiline_strings(self):
        text="f(/* { /* ) */ } */ r'\\', ''' } ) ] ''', [1, 2])"
        self.assertEqual(apply.matching(text,1),len(text)-1)

    def test_const_wrapper_stays_const(self):
        result=apply.transform('return const A(child: B());',[
            {'kind':'expression','target':'return const A(',
             'expression_offset':len('return const '),'prefix':'Outer(child: ','suffix':')'}])
        self.assertEqual(result,'return const Outer(child: A(child: B()));')

    def test_body_wrapper_keeps_finally_and_rethrow(self):
        result=apply.transform('  Future<void> run() async {\n    await work();\n  }\n',[
            {'kind':'body','anchor':'  Future<void> run() async {','operation':'cacheRead','span_kind':'asyncWall'}])
        self.assertIn('await work();',result)
        self.assertIn('rethrow;',result)
        self.assertIn('performanceSpan.finish(failed: performanceFailed)',result)
        self.assertIn('PerfSpanKind.asyncWall',result)
        # Every top-level function brace still matches its final closing brace.
        opening=result.index('{')
        self.assertEqual(apply.matching(result,opening),result.rindex('}'))

    def test_all_manifest_method_anchors_generate_balanced_wrappers(self):
        manifest=json.loads((ROOT/'integration.json').read_text())
        for path, operations in manifest['edits'].items():
            for operation in operations:
                if operation['kind']!='body': continue
                with self.subTest(path=path,anchor=operation['anchor']):
                    source=operation['anchor']+'\n    return value;\n  }\n'
                    result=apply.transform(source,[operation])
                    outer=result.index(operation['anchor'])+len(operation['anchor'])-1
                    self.assertEqual(apply.matching(result,outer),result.rindex('}'))

    def test_locale_insertion_preserves_existing_text(self):
        source='{\n  "existing": { "x": "unchanged" }\n}\n'
        result=apply.transform(source,[{'kind':'locale','data':{'title':'Diagnosis'}}])
        self.assertIn('  "existing": { "x": "unchanged" }',result)
        self.assertEqual(json.loads(result)['performance_diagnostics']['title'],'Diagnosis')

    def test_imports_are_not_duplicated(self):
        result=apply.transform('void f() {}\n',[
            {'kind':'import','library':'package:foundation/performance.dart'},
            {'kind':'import','library':'package:foundation/performance.dart'}])
        self.assertEqual(result.count("import '"),1)

    def test_drifted_and_ambiguous_anchors_fail_before_writing(self):
        for text in ('nothing here','old old'):
            with self.assertRaises(ValueError):
                apply.transform(text,[{'kind':'replace','old':'old','new':'new'}])

    def test_prepare_does_not_modify_worktree_when_a_later_file_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            (root/'one').write_text('old')
            (root/'two').write_text('drifted')
            manifest={'edits':{
                'one':[{'kind':'replace','old':'old','new':'new'}],
                'two':[{'kind':'replace','old':'old','new':'new'}]}}
            with self.assertRaises(ValueError): apply.prepare(root,manifest)
            self.assertEqual((root/'one').read_text(),'old')


class BaseValidationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.git('init', '-b', 'task')
        self.git('config', 'user.name', 'Test')
        self.git('config', 'user.email', 'test@example.invalid')
        (self.root / 'source.dart').write_text('original\n')
        self.git('add', '.')
        self.git('commit', '-m', 'base')
        self.base = self.git('rev-parse', 'HEAD')
        self.manifest = {'base_commit': self.base, 'edits': {'source.dart': []}}

    def git(self, *args):
        return subprocess.check_output(
            ['git', '-C', str(self.root), *args], text=True,
            stderr=subprocess.DEVNULL,
        ).strip()

    def test_unchanged_base_is_accepted(self):
        apply.validate_base_inputs(self.root, self.manifest)

    def test_preparation_commits_do_not_invalidate_identical_source_inputs(self):
        (self.root / 'handoff.md').write_text('preparation only\n')
        self.git('add', '.')
        self.git('commit', '-m', 'prepare branch')
        apply.validate_base_inputs(self.root, self.manifest)

    def test_changed_source_requires_an_explicit_port(self):
        (self.root / 'source.dart').write_text('changed\n')
        self.git('add', '.')
        self.git('commit', '-m', 'change source')
        with self.assertRaisesRegex(ValueError, 'changed since'):
            apply.validate_base_inputs(self.root, self.manifest)

    def test_unsafe_manifest_paths_are_rejected(self):
        for path in ('../outside', '/absolute', 'dir\\file'):
            with self.subTest(path=path), self.assertRaises(ValueError):
                apply.validate_base_inputs(self.root, {
                    'base_commit': self.base, 'edits': {path: []},
                })

if __name__=='__main__': unittest.main()
