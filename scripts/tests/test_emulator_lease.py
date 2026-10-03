"""Independent-process checks for the host-wide emulator reservation CLI."""

import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time
import unittest
import uuid


CLI = Path(__file__).resolve().parents[1] / "emulator_lease.py"
LEASE_DIR = Path(f"/tmp/boorusama-emulator-leases-{os.getuid()}")


class EmulatorLeaseTests(unittest.TestCase):
    def setUp(self):
        self.worktrees = [tempfile.TemporaryDirectory(), tempfile.TemporaryDirectory()]
        self.serials = []

    def tearDown(self):
        for serial in self.serials:
            for suffix in (".json", ".lock"):
                (LEASE_DIR / f"{serial}{suffix}").unlink(missing_ok=True)
        for worktree in self.worktrees:
            worktree.cleanup()

    def serial(self):
        serial = f"emulator-{int(uuid.uuid4().hex[:12], 16)}"
        self.serials.append(serial)
        return serial

    def run_cli(self, cwd, *args):
        return subprocess.run(
            [sys.executable, str(CLI), *args],
            cwd=self.worktrees[cwd].name,
            text=True,
            capture_output=True,
            timeout=10,
        )

    def claim(self, cwd, serial, owner):
        return self.run_cli(cwd, "claim", serial, "--owner", owner)

    def token(self, result):
        match = re.search(r"^token=(\S+)$", result.stdout, re.MULTILINE)
        self.assertIsNotNone(match, result.stdout)
        return match.group(1)

    def test_simultaneous_claims_from_different_directories_have_one_owner(self):
        serial = self.serial()
        commands = [
            [sys.executable, str(CLI), "claim", serial, "--owner", owner]
            for owner in ("session-a /tree/a", "session-b /tree/b")
        ]
        LEASE_DIR.mkdir(mode=0o700, exist_ok=True)
        lock_fd = os.open(LEASE_DIR / f"{serial}.lock", os.O_RDWR | os.O_CREAT, 0o600)
        fcntl.flock(lock_fd, fcntl.LOCK_EX)
        try:
            processes = [
                subprocess.Popen(command, cwd=self.worktrees[index].name,
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                 text=True)
                for index, command in enumerate(commands)
            ]
            time.sleep(0.5)
            blocked = [process.poll() is None for process in processes]
        finally:
            fcntl.flock(lock_fd, fcntl.LOCK_UN)
            os.close(lock_fd)
        results = [process.communicate(timeout=10) for process in processes]
        self.assertEqual(blocked, [True, True], results)
        self.assertEqual(sorted(process.returncode for process in processes), [0, 2])
        winners = [output for process, (output, _) in zip(processes, results)
                   if process.returncode == 0]
        losers = [output for process, (output, _) in zip(processes, results)
                  if process.returncode == 2]
        self.assertIn("token=", winners[0])
        self.assertIn("owner=", losers[0])
        self.assertIn("expires=", losers[0])
        self.assertEqual(self.run_cli(0, "status", serial).returncode, 0)

    def test_different_serials_can_be_claimed_from_different_directories(self):
        first, second = self.serial(), self.serial()
        processes = [
            subprocess.Popen(
                [sys.executable, str(CLI), "claim", serial, "--owner", owner],
                cwd=self.worktrees[index].name,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            for index, (serial, owner) in enumerate(
                ((first, "session-a /tree/a"), (second, "session-b /tree/b"))
            )
        ]
        outputs = [process.communicate(timeout=10) for process in processes]
        self.assertEqual([process.returncode for process in processes], [0, 0], outputs)
        tokens = [re.search(r"^token=(\S+)$", output, re.MULTILINE).group(1)
                  for output, _ in outputs]
        self.assertNotEqual(*tokens)
        status = self.run_cli(1, "status", first)
        self.assertIn("session-a /tree/a", status.stdout)
        self.assertNotIn(tokens[0], status.stdout)

    def test_matching_token_renews_and_releases_lease(self):
        serial = self.serial()
        result = self.claim(0, serial, "session-a /tree/a")
        self.assertEqual(result.returncode, 0, result.stderr)
        token = self.token(result)
        lease_file = LEASE_DIR / f"{serial}.json"
        before = json.loads(lease_file.read_text())
        renewed = self.run_cli(1, "renew", serial, "--token", token)
        self.assertEqual(renewed.returncode, 0, renewed.stderr)
        after = json.loads(lease_file.read_text())
        self.assertEqual(
            after["token_hash"], hashlib.sha256(token.encode()).hexdigest()
        )
        self.assertNotIn(token, lease_file.read_text())
        self.assertIn("T", after["expires_utc"])
        self.assertGreater(after["expires_at"], before["expires_at"])
        self.assertAlmostEqual(after["expires_at"], time.time() + 1800, delta=5)
        self.assertEqual(self.run_cli(1, "release", serial, "--token", token).returncode, 0)
        self.assertFalse(lease_file.exists())

    def test_busy_claim_and_wrong_token_leave_owner_unchanged(self):
        serial = self.serial()
        first = self.claim(0, serial, "session-a /tree/a")
        self.assertEqual(first.returncode, 0, first.stderr)
        lease_file = LEASE_DIR / f"{serial}.json"
        original = lease_file.read_text()
        self.assertNotIn(self.token(first), original)
        status = self.run_cli(1, "status", serial)
        self.assertEqual(status.returncode, 0)
        self.assertNotIn(self.token(first), status.stdout)
        busy = self.claim(1, serial, "session-b /tree/b")
        self.assertEqual(busy.returncode, 2)
        self.assertIn("owner=session-a /tree/a", busy.stdout)
        self.assertIn("expires=", busy.stdout)
        self.assertNotIn(self.token(first), busy.stdout)
        for operation in ("renew", "release"):
            refused = self.run_cli(1, operation, serial, "--token", "wrong-token")
            self.assertEqual(refused.returncode, 2)
            self.assertEqual(lease_file.read_text(), original)

    def test_expired_token_cannot_renew_before_reclaim(self):
        serial = self.serial()
        claimed = self.claim(0, serial, "session-a /tree/a")
        self.assertEqual(claimed.returncode, 0, claimed.stderr)
        lease_file = LEASE_DIR / f"{serial}.json"
        metadata = json.loads(lease_file.read_text())
        metadata["expires_at"] = time.time() - 1
        lease_file.write_text(json.dumps(metadata))
        expired = self.run_cli(1, "status", serial)
        self.assertIn("expired", expired.stdout)
        self.assertNotIn(self.token(claimed), expired.stdout)
        refused = self.run_cli(0, "renew", serial, "--token", self.token(claimed))
        self.assertEqual(refused.returncode, 2)
        self.assertLess(json.loads(lease_file.read_text())["expires_at"], time.time())

    def test_expired_lease_is_reclaimed_and_old_token_cannot_change_new_lease(self):
        serial = self.serial()
        old = self.claim(0, serial, "session-a /tree/a")
        self.assertEqual(old.returncode, 0, old.stderr)
        old_token = self.token(old)
        lease_file = LEASE_DIR / f"{serial}.json"
        metadata = json.loads(lease_file.read_text())
        metadata["expires_at"] = time.time() - 1
        lease_file.write_text(json.dumps(metadata))
        reclaimed = self.claim(1, serial, "session-b /tree/b")
        self.assertEqual(reclaimed.returncode, 0, reclaimed.stderr)
        new_token = self.token(reclaimed)
        self.assertNotEqual(new_token, old_token)
        for operation in ("renew", "release"):
            result = self.run_cli(0, operation, serial, "--token", old_token)
            self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
            self.assertEqual(
                json.loads(lease_file.read_text())["token_hash"],
                hashlib.sha256(new_token.encode()).hexdigest(),
            )

    def test_symlinked_lease_file_is_rejected_without_reading_target(self):
        serial = self.serial()
        target = Path(self.worktrees[0].name) / "unrelated.json"
        target.write_text('sensitive unrelated content')
        LEASE_DIR.mkdir(mode=0o700, exist_ok=True)
        (LEASE_DIR / f"{serial}.json").symlink_to(target)
        status = self.run_cli(1, "status", serial)
        self.assertEqual(status.returncode, 1)
        self.assertNotIn("sensitive unrelated content", status.stdout + status.stderr)
        self.assertEqual(target.read_text(), 'sensitive unrelated content')

    def test_invalid_serial_cannot_escape_fixed_directory(self):
        result = self.claim(0, "../escape", "session-a")
        self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
