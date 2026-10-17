from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1]
FIXTURES = Path(__file__).resolve().parent / "fixtures" / "viewer_diagnostics"
sys.path.insert(0, str(SCRIPTS))
import apply_viewer_diagnostics as overlay
import compare_viewer_performance as comparison


def fixture(name, *, legacy=True):
    bounded = FIXTURES / 'bounded' / name
    path = bounded if not legacy and bounded.exists() else FIXTURES / 'legacy' / name
    return path.read_text()


class ViewerDiagnosticsTests(unittest.TestCase):
    def test_overlay_preserves_legacy_and_bounded_resolution_and_history(self):
        for legacy in (True, False):
            for name in overlay.INSTRUMENTED:
                if name.endswith('.json'):
                    continue
                source = fixture(name, legacy=legacy)
                result = overlay.transform(name, source)
                self.assertIn('performance', result)
                if name.endswith('/post_details_image_preloader.dart'):
                    self.assertEqual('index < widget.posts.length' in result, legacy)
                    self.assertEqual('GroupedPreloadManager' in result, not legacy)
                    self.assertIn('diagnosticResolved++', result)
                if name.endswith('/preload_manager.dart'):
                    method = result[result.index('  void preloadWithStrategy({'):result.index('  void cancelAll()')]
                    self.assertEqual('Set.from(_completedUrls)' in method, legacy)
                    self.assertEqual('UnmodifiableSetView(_completedUrls)' in result, not legacy)

    def test_installs_complete_overlay_and_rejects_dirty_target_before_writes(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            for name in overlay.INSTRUMENTED:
                path = target / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(fixture(name))
            with patch.object(overlay.subprocess, 'check_output', side_effect=[overlay.BASE, ' M existing']):
                with self.assertRaises(ValueError): overlay.apply(target)
            self.assertFalse((target / overlay.FILES[0]).exists())
            with patch.object(overlay.subprocess, 'check_output', side_effect=[overlay.BASE, '']):
                overlay.apply(target)
            self.assertTrue((target / 'lib/foundation/performance/performance_diagnostics.dart').exists())
            import json
            strings = json.loads((target / 'packages/i18n/translations/en-US.json').read_text())
            self.assertEqual(strings['performance_diagnostics']['title'], 'Performance diagnostics')
            self.assertEqual(strings['fixture_sentinel']['title'], 'Existing setting')
            self.assertIn('index < widget.posts.length', (target / 'lib/core/posts/details/src/widgets/post_details_image_preloader.dart').read_text())

    def test_failed_transformation_leaves_every_input_unchanged(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            for name in overlay.INSTRUMENTED:
                path = target / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(fixture(name))
            # A late input fails after earlier transformations were prepared.
            broken = target / overlay.INSTRUMENTED[-1]
            broken.write_text('not a JSON catalog')
            before = {p.relative_to(target): p.read_bytes()
                      for p in target.rglob('*') if p.is_file()}
            with patch.object(overlay.subprocess, 'check_output', side_effect=[overlay.BASE, '']):
                with self.assertRaises(ValueError):
                    overlay.apply(target)
            after = {p.relative_to(target): p.read_bytes()
                     for p in target.rglob('*') if p.is_file()}
            self.assertEqual(after, before)

    def test_existing_destination_rejected_before_any_write(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            for name in overlay.INSTRUMENTED:
                path = target / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(fixture(name))
            destination = target / overlay.FILES[-1]
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text('keep existing work')
            before = {p.relative_to(target): p.read_bytes()
                      for p in target.rglob('*') if p.is_file()}
            with patch.object(overlay.subprocess, 'check_output', side_effect=[overlay.BASE, '']):
                with self.assertRaises(ValueError):
                    overlay.apply(target)
            after = {p.relative_to(target): p.read_bytes()
                     for p in target.rglob('*') if p.is_file()}
            self.assertEqual(after, before)

    def test_overlay_refuses_dirty_or_unknown_targets_without_writes(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            subprocess.run(['git', 'init', '-q', directory], check=True)
            (path / 'sentinel').write_text('existing')
            subprocess.run(['git', '-C', directory, 'add', '.'], check=True)
            subprocess.run(['git', '-C', directory, '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'unknown'], check=True)
            with self.assertRaises(ValueError): overlay.apply(path)
            self.assertEqual([p.name for p in path.iterdir() if p.name != '.git'], ['sentinel'])

    def report(self, frames=100, slow=20, resolutions=1000):
        timing = {'count': frames, 'max_us': 20000, 'histogram_bounds_us': [1000, 20000], 'histogram_counts': [0, frames, 0]}
        return {'schema_version': 1, 'diagnostic_tool': 'viewerSwipeV1', 'environment': {'build_mode': 'profile', 'platform': 'android'},
                'coverage': {}, 'summary': {'screens': {'postViewer': {'frames': frames, 'over_budget_frames': slow,
                'build': timing, 'raster': timing, 'frame_latency': timing, 'ui_delay': timing}},
                'counters': {'mixedResolvedPosts': {'samples': 10, 'total': resolutions * 10, 'max': resolutions}}, 'operations': []}}

    def test_comparison_normalizes_rates_and_resolution_counts(self):
        text = comparison.compare(self.report(), self.report(frames=200, slow=10, resolutions=5))
        self.assertIn('20.00% -> 5.00% (-15.00 percentage points)', text)
        self.assertIn('1000.00 mean, 1000 max, 10 calls -> 5.00 mean, 5 max, 10 calls', text)
        self.assertIn('p95 interval 1–20 ms -> 1–20 ms', text)
        self.assertIn('unavailable', text)

    def test_comparison_rejects_empty_viewer_and_foreign_reports(self):
        for report in (self.report(frames=0), {'schema_version': 1}):
            with self.assertRaises(ValueError): comparison.compare(report, self.report())

    def test_comparison_warns_about_mismatched_modes_without_printing_free_text(self):
        report = self.report()
        report['environment'] = {'build_mode': 'debug', 'platform': 'secret\x1b[31m'}
        text = comparison.compare(report, self.report())
        self.assertIn('WARNING', text)
        self.assertNotIn('secret', text)


if __name__ == '__main__': unittest.main()
