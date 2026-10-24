"""Unexecuted runner regression tests; no Flutter subprocess is started here."""
import importlib.util
import json
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("scalability_compare", Path(__file__).with_name("compare.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def reporter(*, success=True):
    events = [{"type": "print", "message": module.PREFIX + json.dumps({
        "schema": 1, "scenario": name, "scale": "small", "warmups": 1,
        "samples_us": [2, 4, 6], "inputs": {"n": 10}, "work": {"visits": 10}
    })} for name in sorted(module.SCENARIOS)]
    events.append({"type": "done", "success": success})
    return "\n".join(json.dumps(event) for event in events)


class ComparisonTests(unittest.TestCase):
    def test_complete_report_is_required(self):
        self.assertEqual(len(module.parse_results(reporter(), "small", 3, 1)), len(module.SCENARIOS))
        with self.assertRaises(ValueError):
            module.parse_results(reporter(success=False), "small", 3, 1)
        with self.assertRaises(ValueError):
            module.parse_results("\n".join(reporter().splitlines()[:-1]), "small", 3, 1)

    def test_missing_duplicate_or_wrong_scale_results_are_rejected(self):
        lines = reporter().splitlines()
        for content in ["\n".join(lines[1:]), "\n".join([lines[0], *lines])]:
            with self.assertRaises(ValueError):
                module.parse_results(content, "small", 3, 1)
        with self.assertRaises(ValueError):
            module.parse_results(reporter(), "large", 3, 1)
        with self.assertRaises(ValueError):
            module.parse_results(reporter(), "small", 4, 1)

    def test_comparison_keeps_work_counters_and_paired_rounds(self):
        rows = module.parse_results(reporter(), "small", 3, 1)
        records = [{**row, "variant": label, "round": round_index}
                   for round_index in [1, 2] for label in ["baseline", "candidate"] for row in rows]
        output = module.compare(records)
        self.assertEqual(len(output), len(module.SCENARIOS))
        self.assertEqual(output[0]["candidate_over_baseline_median"], 1)
        self.assertEqual(output[0]["candidate"]["round_medians_us"], [4, 4])
        self.assertEqual(output[0]["baseline"]["work_by_round"], [{"visits": 10}, {"visits": 10}])
        records[0] = {**records[0], "inputs": {"n": 11}}
        with self.assertRaises(ValueError):
            module.compare(records)


if __name__ == "__main__":
    unittest.main()
