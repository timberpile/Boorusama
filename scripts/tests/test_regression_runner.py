import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


class RegressionRunnerTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        for path in ("scripts", "bin", ".github/scripts"):
            (self.root / path).mkdir(parents=True)
        shutil.copy2(
            Path(__file__).parents[1] / "run_regression_tests.sh",
            self.root / "scripts",
        )
        (self.root / "scripts/physical_core_count.py").write_text("print(3)\n")
        for name, spec in (
            ("dart", "name: dart\n"),
            ("flutter", "sdk: flutter\n"),
            ("graphql", "graphql_flutter: any\n"),
        ):
            package = self.root / "packages" / name
            (package / "test").mkdir(parents=True)
            (package / "test/a_test.dart").touch()
            (package / "pubspec.yaml").write_text(spec)
        (self.root / "packages/empty/test").mkdir(parents=True)
        stub = '''#!/usr/bin/env bash
if [[ "$(basename "$0")" == python3 && "$1" == scripts/physical_core_count.py ]]; then
  exec "$REAL_PYTHON" "$@"
fi
printf '%s|%s|%s\n' "$(basename "$0")" "$PWD" "$*" >> "$TRACE"
[[ "${FAIL_AT:-}" != "$(basename "$0"):$*" ]]
'''
        for name in (
            "bin/fvm",
            "bin/python3",
            ".github/scripts/test-pull-request-policy.sh",
            ".github/scripts/test-android-release-scripts.sh",
        ):
            path = self.root / name
            path.write_text(stub)
            path.chmod(0o755)
        self.env = os.environ.copy()
        self.env.pop("TEST_CONCURRENCY", None)
        self.env.update(
            PATH=str(self.root / "bin") + os.pathsep + self.env["PATH"],
            REAL_PYTHON=sys.executable,
            TRACE=str(self.root / "trace"),
        )

    def run_script(self, **environment):
        (self.root / "trace").write_text("")
        result = subprocess.run(
            [str(self.root / "scripts/run_regression_tests.sh")],
            cwd=self.root.parent,
            env=self.env | environment,
            capture_output=True,
            text=True,
            timeout=10,
        )
        return result, (self.root / "trace").read_text().splitlines()

    def test_detected_count_reaches_application_and_every_package(self):
        result, calls = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(calls), 7)
        self.assertTrue(all("--concurrency=3" in call for call in calls[:4]))
        self.assertIn("dart test", calls[1])
        self.assertTrue(all(
            "flutter test" in call for call in (calls[0], calls[2], calls[3])
        ))
        self.assertFalse(any("benchmark/" in call for call in calls))
        self.assertTrue(calls[-1].endswith("-m unittest discover -s scripts/tests"))

    def test_override_skips_detection_and_reaches_every_package(self):
        (self.root / "scripts/physical_core_count.py").write_text(
            "raise RuntimeError('Must not run')\n"
        )
        result, calls = self.run_script(TEST_CONCURRENCY="2")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(all("--concurrency=2" in call for call in calls[:4]))

    def test_invalid_override_stops_before_running_tests(self):
        for value in ("0", "-1", "six"):
            with self.subTest(value=value):
                result, calls = self.run_script(TEST_CONCURRENCY=value)
                self.assertEqual(result.returncode, 2)
                self.assertEqual(calls, [])

    def test_failures_and_manifest_errors_stop_the_gate(self):
        result, calls = self.run_script(FAIL_AT="fvm:dart test --concurrency=3")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(calls), 2)
        (self.root / "packages/dart/pubspec.yaml").unlink()
        result, calls = self.run_script()
        self.assertEqual(result.returncode, 2)
        self.assertEqual(len(calls), 1)
