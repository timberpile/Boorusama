import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('analyze_performance', Path(__file__).parents[1] / 'analyze_performance.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class PerformanceAnalysisTests(unittest.TestCase):
    def report(self, events):
        return {'schema_version': 1, 'events': events, 'environment': {'build_mode': 'release'},
                'summary': {}, 'coverage': {}}

    def test_uses_intervals_not_export_order_and_separates_waiting(self):
        report = self.report([
            {'type': 'span', 'op': 'cacheRead', 'kind': 'asyncWall', 't_us': 0, 'duration_us': 900000},
            {'type': 'span', 'op': 'cacheEvictionScan', 'kind': 'sync', 't_us': 110000, 'duration_us': 80000},
            {'type': 'ui_delay', 'screen': 'bookmarks', 't_us': 100000, 'duration_us': 100000},
        ])
        text = module.summarize(report)
        self.assertIn('Synchronous overlap: cacheEvictionScan', text)
        self.assertIn('Async wall-time overlap (includes waiting): cacheRead', text)
        self.assertIn('not causal stack traces', text)

    def test_does_not_attribute_non_overlapping_work(self):
        report = self.report([
            {'type': 'span', 'op': 'gridFilter', 'kind': 'sync', 't_us': 0, 'duration_us': 1000},
            {'type': 'ui_delay', 'screen': 'bookmarks', 't_us': 100000, 'duration_us': 100000},
        ])
        self.assertIn('Synchronous overlap: none recorded', module.summarize(report))

    def test_excludes_diagnostics_screen_details(self):
        report = self.report([{'type': 'ui_delay', 'screen': 'diagnostics', 'duration_us': 100000}])
        self.assertIn('No retained stall details', module.summarize(report))

    def test_reports_percentiles_as_ranges_not_fabricated_precision(self):
        histogram = {'count': 10, 'histogram_bounds_us': [1000, 10000], 'histogram_counts': [2, 8, 0]}
        self.assertEqual(module.percentile_range(histogram, .95), '1–10 ms')
        histogram['histogram_counts'] = [2, 7, 1]
        self.assertEqual(module.percentile_range(histogram, .95), '>10 ms')

    def test_rejects_unknown_schema(self):
        with self.assertRaises(ValueError): module.summarize({'schema_version': 99})

    def test_never_prints_freeform_names_or_revision_strings(self):
        report = self.report([{'type': 'ui_delay', 'screen': '\x1b[31msecret', 'duration_us': 100000}])
        report['environment']['revision'] = 'secret-token'
        text = module.summarize(report)
        self.assertNotIn('secret', text)
        self.assertNotIn('\x1b', text)

if __name__ == '__main__': unittest.main()
