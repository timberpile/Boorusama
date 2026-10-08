"""Behavior checks for the worktree CLI using disposable local Git repositories."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


CLI = Path(__file__).resolve().parents[1] / "agent_worktree.py"


class AgentWorktreeTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / "primary checkout"
        self.root.mkdir()
        self.env = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
        self.env.update({
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": os.devnull,
            "GIT_TERMINAL_PROMPT": "0",
            "GIT_ALLOW_PROTOCOL": "",  # Any attempted remote transport must fail.
        })
        self.git("init", "--initial-branch=develop", "--template=")
        self.git("config", "user.name", "Worktree Test")
        self.git("config", "user.email", "worktree-test@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        (self.root / "tracked.txt").write_text("base\n")
        (self.root / ".gitignore").write_text(".worktrees/\nignored/\n")
        self.git("add", ".")
        self.git("commit", "-m", "Initial local develop")

    def git(self, *arguments, cwd=None):
        result = subprocess.run(
            ["git", "-C", str(cwd or self.root), *arguments],
            env=self.env, capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def run_cli(self, command, slug="task-a", cwd=None):
        return subprocess.run(
            [sys.executable, str(CLI), command, slug],
            cwd=cwd or self.root, env=self.env,
            capture_output=True, text=True, timeout=10,
        )

    def success(self, command, slug="task-a", cwd=None):
        result = self.run_cli(command, slug, cwd)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return json.loads(result.stdout)

    def refused(self, command, slug="task-a", cwd=None):
        result = self.run_cli(command, slug, cwd)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("Traceback", result.stderr)
        return result

    def task_path(self, slug="task-a"):
        return self.root / ".worktrees" / slug

    def primary_state(self):
        return (
            self.git("symbolic-ref", "HEAD"),
            self.git("rev-parse", "HEAD"),
            self.git("status", "--porcelain", "--untracked-files=all"),
            self.git("diff"), self.git("diff", "--cached"),
            (self.root / "tracked.txt").read_bytes(),
        )

    def test_create_uses_local_develop_ahead_of_origin_without_remote_transport(self):
        previous = self.git("rev-parse", "HEAD")
        self.git("update-ref", "refs/remotes/origin/develop", previous)
        self.git("remote", "add", "origin", "https://example.invalid/no-transport")
        (self.root / "tracked.txt").write_text("approved local commit\n")
        self.git("commit", "-am", "Approved local work")
        local = self.git("rev-parse", "develop")
        # The active primary branch also need not be develop.
        self.git("checkout", "-b", "primary-user-work", previous)
        result = self.success("create", "bookmark-sort-order")
        path = self.task_path("bookmark-sort-order")
        self.assertEqual(result["branch"], "agent/bookmark-sort-order")
        self.assertEqual(result["path"], str(path))
        self.assertEqual(result["base"], "develop")
        self.assertEqual(result["base_commit"], local)
        self.assertEqual(self.git("rev-parse", "HEAD", cwd=path), local)
        self.assertEqual(self.git("symbolic-ref", "HEAD", cwd=path), "refs/heads/agent/bookmark-sort-order")
        self.assertEqual(self.git("rev-parse", "origin/develop"), previous)
        self.assertEqual(self.git("branch", "--show-current"), "primary-user-work")

    def test_create_without_remotes_preserves_staged_unstaged_untracked_and_ignored_files(self):
        self.assertEqual(self.git("remote"), "")
        (self.root / "tracked.txt").write_text("staged user work\n")
        self.git("add", "tracked.txt")
        (self.root / "tracked.txt").write_text("unstaged user work\n")
        untracked = self.root / "notes.txt"
        untracked.write_text("unrelated notes")
        ignored = self.root / "ignored" / "artifact.txt"
        ignored.parent.mkdir()
        ignored.write_text("unrelated artifact")
        before = self.primary_state()
        self.success("create")
        self.assertEqual(self.primary_state(), before)
        self.assertEqual(untracked.read_text(), "unrelated notes")
        self.assertEqual(ignored.read_text(), "unrelated artifact")
        self.assertEqual((self.task_path() / "tracked.txt").read_text(), "base\n")

    def test_duplicate_create_leaves_existing_task_unchanged(self):
        self.success("create")
        notes = self.task_path() / "notes.txt"
        notes.write_text("task in progress")
        head = self.git("rev-parse", "HEAD", cwd=self.task_path())
        result = self.refused("create")
        self.assertIn("already has a worktree", result.stderr)
        self.assertIn("status task-a", result.stderr)
        self.assertEqual(notes.read_text(), "task in progress")
        self.assertEqual(self.git("rev-parse", "HEAD", cwd=self.task_path()), head)

    def test_existing_branch_without_worktree_is_not_reused(self):
        self.git("branch", "agent/task-a")
        result = self.refused("create")
        self.assertIn("already exists without a worktree", result.stderr)
        self.assertFalse(self.task_path().exists())
        status = json.loads(self.refused("status").stdout)
        self.assertTrue(status["branch_exists"])
        self.assertFalse(status["registered"])

    def test_branch_attached_elsewhere_is_reported_and_never_removed(self):
        other = self.root.parent / "elsewhere"
        self.git("worktree", "add", "-b", "agent/task-a", str(other), "develop")
        self.assertIn(str(other), self.refused("create").stderr)
        state = json.loads(self.refused("status").stdout)
        self.assertEqual(state["attached_paths"], [str(other)])
        self.assertIn("attached elsewhere", " ".join(state["issues"]))
        self.refused("remove")
        self.assertTrue(other.is_dir())

    def test_existing_unregistered_path_is_not_overwritten(self):
        self.task_path().mkdir(parents=True)
        notes = self.task_path() / "notes.txt"
        notes.write_text("existing unrelated directory")
        self.refused("create")
        state = json.loads(self.refused("status").stdout)
        self.assertFalse(state["registered"])
        self.assertIn("not registered", " ".join(state["issues"]))
        self.refused("remove")
        self.assertEqual(notes.read_text(), "existing unrelated directory")

    def test_existing_empty_path_or_file_is_also_not_overwritten(self):
        self.task_path().mkdir(parents=True)
        self.refused("create")
        self.task_path().rmdir()
        self.task_path().write_text("unrelated file")
        self.refused("create")
        self.refused("remove")
        self.assertEqual(self.task_path().read_text(), "unrelated file")

    def test_status_and_remove_reject_worktree_on_another_branch(self):
        self.git("worktree", "add", "-b", "other-task", str(self.task_path()), "develop")
        self.assertIn("already registered", self.refused("create").stderr)
        state = json.loads(self.refused("status").stdout)
        self.assertEqual(state["actual_branch"], "other-task")
        self.assertIn("expected agent/task-a", " ".join(state["issues"]))
        self.refused("remove")
        self.assertTrue(self.task_path().is_dir())

    def test_status_is_read_only_and_reports_head_path_and_clean_state(self):
        self.success("create")
        tracked = self.task_path() / "tracked.txt"
        info = tracked.stat()
        os.utime(tracked, ns=(info.st_atime_ns, info.st_mtime_ns + 3_000_000_000))
        index = Path(self.git("rev-parse", "--git-path", "index", cwd=self.task_path()))
        index_before = (index.read_bytes(), index.stat().st_mtime_ns)
        before = self.primary_state()
        registrations = self.git("worktree", "list", "--porcelain")
        state = self.success("status")
        self.assertEqual(state["state"], "ready")
        self.assertEqual(state["branch"], "agent/task-a")
        self.assertEqual(state["path"], str(self.task_path()))
        self.assertEqual(state["head"], self.git("rev-parse", "develop"))
        self.assertTrue(state["worktree_exists"])
        self.assertTrue(state["registered"])
        self.assertFalse(state["dirty"])
        self.assertFalse(state["ignored_files"])
        self.assertEqual((index.read_bytes(), index.stat().st_mtime_ns), index_before)
        self.assertEqual(self.primary_state(), before)
        self.assertEqual(self.git("worktree", "list", "--porcelain"), registrations)

    def test_status_reports_missing_environment_without_creating_it(self):
        state = json.loads(self.refused("status").stdout)
        self.assertEqual(state["state"], "missing")
        self.assertFalse(state["branch_exists"])
        self.assertFalse(state["worktree_exists"])
        self.assertIsNone(state["head"])
        self.assertFalse((self.root / ".worktrees").exists())

    def test_modified_staged_or_untracked_files_are_reported_and_block_removal(self):
        self.success("create")
        for change in ("modified", "staged", "untracked"):
            with self.subTest(change=change):
                changed = self.task_path() / ("notes.txt" if change == "untracked" else "tracked.txt")
                changed.write_text(f"{change} task work")
                if change == "staged":
                    self.git("add", "tracked.txt", cwd=self.task_path())
                state = self.success("status")
                self.assertTrue(state["dirty"])
                self.assertIn("dirty", self.refused("remove").stderr)
                self.assertEqual(changed.read_text(), f"{change} task work")
                if change == "untracked":
                    changed.unlink()
                else:
                    self.git("restore", "--staged", "--worktree", "tracked.txt", cwd=self.task_path())

    def test_ignored_files_are_reported_and_preserved_on_remove(self):
        self.success("create")
        artifact = self.task_path() / "ignored" / "artifact.txt"
        artifact.parent.mkdir()
        artifact.write_text("potentially useful output")
        state = self.success("status")
        self.assertFalse(state["dirty"])
        self.assertTrue(state["ignored_files"])
        self.assertIn("ignored", self.refused("remove").stderr)
        self.assertEqual(artifact.read_text(), "potentially useful output")

    def test_remove_only_expected_clean_worktree_and_preserve_its_commits_and_branch(self):
        self.success("create", "task-a")
        self.success("create", "task-ab")
        (self.task_path() / "tracked.txt").write_text("completed task\n")
        self.git("commit", "-am", "Task commit", cwd=self.task_path())
        task_head = self.git("rev-parse", "agent/task-a")
        (self.root / "tracked.txt").write_text("unrelated primary work\n")
        before = self.primary_state()
        result = self.success("remove")
        self.assertTrue(result["branch_preserved"])
        self.assertFalse(self.task_path().exists())
        self.assertEqual(self.git("rev-parse", "agent/task-a"), task_head)
        self.assertEqual(self.success("status", "task-ab")["state"], "ready")
        self.assertEqual(self.primary_state(), before)
        self.assertIn("already exists without a worktree", self.refused("create").stderr)

    def test_nested_and_linked_checkout_calls_use_the_primary_root(self):
        nested = self.root / "nested"
        nested.mkdir()
        self.success("create", cwd=nested)
        state = self.success("create", "task-b", cwd=self.task_path())
        self.assertEqual(state["path"], str(self.task_path("task-b")))
        self.assertFalse((self.task_path() / ".worktrees").exists())
        self.success("status", "task-b", cwd=self.task_path())
        self.success("remove", "task-b", cwd=self.task_path())
        self.assertTrue(self.task_path().is_dir())

    def test_invalid_slugs_cannot_change_repository_state(self):
        before = self.git("worktree", "list", "--porcelain")
        for slug in ("../escape", "Task-A", "task_a", "task/a", "a--b", "-task", "task-", "", "täst", "task\n"):
            with self.subTest(slug=slug):
                self.refused("create", slug)
        self.assertEqual(self.git("worktree", "list", "--porcelain"), before)
        self.assertFalse((self.root / ".worktrees").exists())

    def test_missing_develop_fails_without_creating_branch_or_worktree(self):
        self.git("branch", "-m", "main")
        result = self.refused("create")
        self.assertIn("Local develop is missing", result.stderr)
        self.assertFalse(self.task_path().exists())
        self.assertEqual(self.git("branch", "--list", "agent/task-a"), "")

    def test_symlinked_parent_or_target_never_redirects_operations(self):
        outside = self.root.parent / "unrelated"
        outside.mkdir()
        parent = self.root / ".worktrees"
        parent.symlink_to(outside, target_is_directory=True)
        self.assertIn("Symlinked", self.refused("create").stderr)
        self.refused("remove")
        self.assertEqual(list(outside.iterdir()), [])
        parent.unlink()
        parent.mkdir()
        self.task_path().symlink_to(self.root, target_is_directory=True)
        self.refused("create")
        self.refused("remove")
        self.assertEqual((self.root / "tracked.txt").read_text(), "base\n")
        self.task_path().unlink()
        self.task_path().symlink_to(outside / "missing")
        self.refused("create")
        self.refused("remove")

    def test_registered_but_missing_worktree_is_not_recreated_or_pruned(self):
        self.success("create")
        moved = self.root.parent / "manually-moved"
        self.task_path().rename(moved)
        before = self.git("worktree", "list", "--porcelain")
        self.refused("create")
        state = json.loads(self.refused("status").stdout)
        self.assertTrue(state["registered"])
        self.assertFalse(state["worktree_exists"])
        self.refused("remove")
        self.assertEqual(self.git("worktree", "list", "--porcelain"), before)
        self.assertTrue(moved.is_dir())

    def test_detached_or_locked_worktree_cannot_be_removed(self):
        self.success("create")
        self.git("worktree", "lock", "--reason", "Active task", str(self.task_path()))
        self.assertTrue(self.success("status")["locked"])
        self.assertIn("locked", self.refused("remove").stderr)
        self.git("worktree", "unlock", str(self.task_path()))
        self.git("checkout", "--detach", cwd=self.task_path())
        state = json.loads(self.refused("status").stdout)
        self.assertIsNone(state["actual_branch"])
        self.refused("remove")
        self.assertTrue(self.task_path().is_dir())

    def test_replaced_registered_path_cannot_remove_a_different_repository(self):
        self.success("create")
        moved = self.root.parent / "saved-task"
        self.task_path().rename(moved)
        self.task_path().mkdir()
        self.git("init", "--initial-branch=agent/task-a", "--template=", cwd=self.task_path())
        state = json.loads(self.refused("status").stdout)
        self.assertIn("does not match", " ".join(state["issues"]))
        self.refused("remove")
        self.assertTrue((self.task_path() / ".git").is_dir())
        self.assertTrue(moved.is_dir())

    def test_non_repository_call_has_clear_error_without_traceback(self):
        result = self.refused("create", cwd=self.root.parent)
        self.assertIn("not a git repository", result.stderr)

    def test_primary_path_with_quotes_newlines_and_trailing_spaces_is_supported(self):
        unusual = self.root.parent / 'checkout "quoted"\nwith trailing space '
        self.root.rename(unusual)
        self.root = unusual
        result = self.success("create")
        self.assertEqual(result["path"], str(self.task_path()))
        self.assertEqual(self.success("status")["state"], "ready")
        self.success("remove")


if __name__ == "__main__":
    unittest.main()
