"""Worker elapsed time must not become a UI-blocking overlap hint."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location(
    'checkpoint_analysis', Path(__file__).resolve().parents[1] / 'analyze_performance.py')
analysis = importlib.util.module_from_spec(spec)
spec.loader.exec_module(analysis)


class CheckpointAnalysisTest(unittest.TestCase):
    def test_worker_duration_is_reported_only_as_async_wall_overlap(self):
        report = {
            'schema_version': 1,
            'summary': {}, 'environment': {}, 'coverage': {},
            'events': [
                {'type': 'ui_delay', 'screen': 'search', 't_us': 0, 'duration_us': 60000},
                {'type': 'span', 'op': 'cacheCheckpointSnapshot', 'kind': 'sync', 't_us': 0, 'duration_us': 3000},
                {'type': 'span', 'op': 'cacheCheckpointDispatch', 'kind': 'sync', 't_us': 3000, 'duration_us': 1000},
                {'type': 'span', 'op': 'cacheCheckpointWorker', 'kind': 'asyncWall', 't_us': 3000, 'duration_us': 57000},
            ],
        }
        lines = analysis.summarize(report).splitlines()
        synchronous = next(line for line in lines if 'Synchronous overlap:' in line)
        asynchronous = next(line for line in lines if 'Async wall-time overlap' in line)
        self.assertIn('cacheCheckpointSnapshot', synchronous)
        self.assertIn('cacheCheckpointDispatch', synchronous)
        self.assertNotIn('cacheCheckpointWorker', synchronous)
        self.assertIn('cacheCheckpointWorker', asynchronous)


if __name__ == '__main__':
    unittest.main()
