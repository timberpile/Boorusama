"""Source-contract checks for the release gate; no workflow/network execution."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class ReleaseGateTests(unittest.TestCase):
    def test_release_gate_uses_a_published_tag_not_candidate_version(self):
        workflow = (ROOT / '.github/workflows/release-validation.yml').read_text()
        gate = workflow.split('- name: Audit schema versions', 1)[1].split('- name:', 1)[0]
        self.assertIn('releases/latest', gate)
        self.assertIn('git check-ref-format', gate)
        self.assertIn('refs/tags/$baseline_tag^{commit}', gate)
        self.assertIn('--baseline "$baseline_sha" --candidate HEAD --inventory', gate)
        self.assertNotIn('pubspec.yaml', gate)
        self.assertNotIn('continue-on-error', gate)
        self.assertNotIn('|| true', gate)
        self.assertIn('fetch-depth: 0', workflow)

    def test_gate_does_not_publish_or_request_write_permissions(self):
        workflow = (ROOT / '.github/workflows/release-validation.yml').read_text()
        self.assertIn('contents: read', workflow)
        self.assertNotIn('contents: write', workflow)
        self.assertNotIn('gh release create', workflow)
        self.assertNotIn('git push', workflow)
        self.assertNotIn('gh workflow run', workflow)


if __name__ == '__main__':
    unittest.main()
