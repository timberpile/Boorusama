"""Exercise label setup against a fake gh boundary, never a live repository."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
CLI = ROOT / "scripts" / "setup_issue_labels.py"
CATALOG = ROOT / ".github" / "labels.json"


class IssueLabelTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.state = self.directory / "labels.json"
        self.state.write_text(json.dumps({"unrelated-label": {"color": "123456"}}))
        self.calls = self.directory / "calls.jsonl"
        gh = self.directory / "gh"
        gh.write_text(f"#!{sys.executable}\n" + '''import json, os, pathlib, sys
args = sys.argv[1:]
with open(os.environ["FAKE_GH_CALLS"], "a") as stream:
    stream.write(json.dumps(args) + "\\n")
if os.environ.get("FAKE_GH_FAIL"):
    sys.exit(1)
assert args[:2] == ["label", "create"]
assert args[args.index("--repo") + 1] == "github.com/timberpile/Boorusama"
assert "--force" in args
path = pathlib.Path(os.environ["FAKE_GH_STATE"])
state = json.loads(path.read_text())
state[args[2]] = {"color": args[args.index("--color") + 1],
                  "description": args[args.index("--description") + 1]}
path.write_text(json.dumps(state))
''')
        gh.chmod(0o755)
        self.env = dict(os.environ, PATH=f"{self.directory}{os.pathsep}{os.environ['PATH']}",
                        FAKE_GH_CALLS=str(self.calls), FAKE_GH_STATE=str(self.state),
                        GH_HOST="example.invalid", GH_REPO="unrelated/repository")
        self.env.pop("FAKE_GH_FAIL", None)

    def run_cli(self, *args, env=None):
        return subprocess.run([sys.executable, str(CLI), *args], cwd=self.directory,
                              env=env or self.env, capture_output=True, text=True, timeout=60)

    def test_default_is_an_offline_preview_even_outside_the_repository(self):
        result = self.run_cli()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--apply", result.stdout)
        self.assertIn("area:backups", result.stdout)
        self.assertFalse(self.calls.exists())
        self.assertEqual(json.loads(self.state.read_text()), {"unrelated-label": {"color": "123456"}})

    def test_apply_is_repeatable_and_preserves_unrelated_labels_without_touching_issues(self):
        catalog = json.loads(CATALOG.read_text())
        for _ in range(2):
            result = self.run_cli("--apply")
            self.assertEqual(result.returncode, 0, result.stderr)
        actual = json.loads(self.state.read_text())
        self.assertEqual(len(actual), len(catalog) + 1)
        self.assertEqual(actual["unrelated-label"], {"color": "123456"})
        for label in catalog:
            self.assertEqual(actual[label["name"]], {key: label[key] for key in ("color", "description")})
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        self.assertEqual(len(calls), len(catalog) * 2)
        self.assertTrue(all(call[:2] == ["label", "create"] and "--force" in call for call in calls))

    def test_a_github_failure_stops_without_attempting_later_labels(self):
        result = self.run_cli("--apply", env=dict(self.env, FAKE_GH_FAIL="1"))
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("Traceback", result.stderr)
        self.assertEqual(len(self.calls.read_text().splitlines()), 1)
        self.assertEqual(json.loads(self.state.read_text()), {"unrelated-label": {"color": "123456"}})

    def test_catalog_and_templates_use_the_agreed_types_and_areas(self):
        catalog = json.loads(CATALOG.read_text())
        names = {label["name"] for label in catalog}
        self.assertEqual(len(catalog), 26)
        self.assertEqual(len(names), len(catalog))
        self.assertTrue({"bug", "feature", "maintenance", "in-progress", "blocked", "review",
                         "priority:high", "priority:low", "area:backups", "area:following-topics",
                         "ux", "performance"} <= names)
        self.assertFalse({"area:sites", "area:data", "area:import-export", "area:storage",
                          "area:pinned-searches", "area:feeds", "done", "ready", "priority:normal"} & names)
        for kind, filename in (("bug", "bug_report.md"), ("feature", "feature_request.md"),
                               ("maintenance", "maintenance.md")):
            content = (ROOT / ".github" / "ISSUE_TEMPLATE" / filename).read_text()
            self.assertRegex(content, rf"(?m)^labels: {kind}$")
            self.assertIn("## Problem", content)
            self.assertIn("## Expected behavior", content)
            self.assertNotIn("## Verification", content)


if __name__ == "__main__":
    unittest.main()
