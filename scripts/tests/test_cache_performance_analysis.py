"""Complete cache metrics and comparisons must survive bounded detail loss."""
from copy import deepcopy
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import analyze_performance as analysis
import compare_cache_performance as comparison


class CachePerformanceAnalysisTest(unittest.TestCase):
    def distribution(self, count=10):
        return {'count': count, 'total_us': count * 1000, 'max_us': 1000,
                'histogram_bounds_us': [1000, 10000], 'histogram_counts': [count, 0, 0]}

    def report(self, frames=100, slow=10):
        scope = {'frames': frames, 'over_budget_frames': slow, 'high_latency_frames': 0,
                 'frame_budgets_us': [11111], 'estimated_budget_frames': 0,
                 **{key: self.distribution(frames) for key in analysis.FRAME_METRICS}}
        return {'schema_version': 1, 'elapsed_us': 60000000, 'foreground_us': 50000000,
                'environment': {'build_mode': 'release', 'platform': 'android', 'flavor': 'dev'},
                'summary': {**scope, 'screens': {'searchGrid': scope}, 'counters': {},
                            'operations': [{**self.distribution(), 'op': 'cacheCheckpointWorker',
                                            'kind': 'asyncWall', 'failed': 0}]},
                'coverage': {'evicted_events': 1000}, 'events': []}

    def test_fast_cache_stage_is_not_hidden_below_ten_slower_operations(self):
        report = self.report()
        report['summary']['operations'] += [
            {**self.distribution(), 'op': 'gridFilter', 'kind': 'sync', 'max_us': 1000000 + i}
            for i in range(11)]
        text = analysis.summarize(report)
        self.assertIn('cacheCheckpointWorker [asyncWall]: count=10', text)
        self.assertIn('p99=', text)
        self.assertIn('vsync_overhead: count=100', text)
        self.assertIn('searchGrid: frames=100', text)

    def test_comparison_uses_aggregates_and_frame_rates_without_detail_events(self):
        text = comparison.compare(self.report(), self.report(frames=200, slow=10))
        self.assertIn('over_budget_frames: 10.00% -> 5.00%', text)
        self.assertIn('cacheCheckpointWorker [asyncWall]: count=10', text)
        self.assertIn('foreground_us: 50.000s -> 50.000s', text)
        self.assertIn('UI delays >=50 ms: 120.00/foreground minute', text)
        self.assertIn('evicted_events: 1000 -> 1000', text)
        self.assertIn('not UI blocking', text)

    def test_tail_counts_are_complete_histogram_counts(self):
        distribution = {'count': 100, 'histogram_bounds_us': [50000, 100000, 250000],
                        'histogram_counts': [90, 5, 3, 2]}
        self.assertEqual(analysis.above_threshold(distribution, 50000), '10')
        self.assertEqual(analysis.above_threshold(distribution, 250000), '2')
        self.assertEqual(analysis.above_threshold(distribution, 12345), 'unavailable')

    def test_missing_metrics_are_unavailable_instead_of_zero_cost(self):
        text = comparison.compare(self.report(), self.report())
        self.assertIn('cacheIndexEncode: unavailable -> unavailable', text)
        self.assertIn('cacheRetainedBytes: unavailable -> unavailable', text)
        self.assertIn('items: unavailable', text)
        report = self.report()
        report['summary']['operations'][0].pop('failed')
        self.assertIn('failed=unavailable', comparison.compare(report, self.report()))

    def test_compares_workload_size_and_flags_incompatible_conditions(self):
        before, after = self.report(), self.report()
        before['summary']['counters']['cacheEntries'] = {'samples': 2, 'total': 6800, 'max': 3400, 'first': 3400, 'last': 3400}
        after['summary']['counters']['cacheEntries'] = {'samples': 2, 'total': 200, 'max': 100, 'first': 100, 'last': 100}
        after['environment']['build_mode'] = 'debug'
        after['summary']['screens']['searchGrid']['frame_budgets_us'] = [16667]
        text = comparison.compare(before, after)
        self.assertIn('first=3400', text)
        self.assertIn('first=100', text)
        self.assertIn('WARNING: use matching', text)
        self.assertIn('WARNING: screen frame budgets differ', text)

    def test_rejects_unusable_or_malformed_comparisons(self):
        for change in ('frames', 'operations', 'counters', 'ui_delay'):
            bad = deepcopy(self.report())
            bad['summary'][change] = 0 if change == 'frames' else [] if change == 'operations' else []
            with self.assertRaises(ValueError):
                comparison.compare(self.report(), bad)

    def test_unsafe_metadata_and_counter_names_are_not_printed(self):
        report = self.report()
        report['environment']['revision'] = 'SECRET_CREDENTIAL'
        report['summary']['counters']['SECRET_CREDENTIAL'] = {'samples': 1, 'total': 1}
        report['summary']['screens']['\x1bSECRET_CREDENTIAL'] = report['summary']['screens'].pop('searchGrid')
        text = comparison.compare(report, self.report())
        self.assertNotIn('SECRET_CREDENTIAL', text)
        self.assertNotIn('\x1b', text)


if __name__ == '__main__':
    unittest.main()
