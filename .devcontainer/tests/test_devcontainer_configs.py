import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DEVCONTAINER = ROOT / ".devcontainer"


class DevContainerConfigTest(unittest.TestCase):
    def load(self, mode: str) -> dict:
        path = DEVCONTAINER / mode / "devcontainer.json"
        self.assertTrue(path.is_file(), f"missing {mode} Dev Container configuration")
        with path.open(encoding="utf-8") as config_file:
            return json.load(config_file)

    def test_standard_checkout_mounts_and_opens_the_repository(self) -> None:
        config = self.load("standard")

        self.assertEqual(config["workspaceFolder"], "/workspace/Boorusama")
        self.assertIn("source=${localWorkspaceFolder},", config["workspaceMount"])
        self.assertEqual(
            config["containerEnv"]["BOORUSAMA_WORKSPACE_MODE"], "standard"
        )

    def test_worktree_mounts_the_common_repository_and_opens_only_the_worktree(
        self,
    ) -> None:
        config = self.load("worktree")

        self.assertEqual(
            config["workspaceFolder"],
            "/workspace/Boorusama/.worktrees/${localWorkspaceFolderBasename}",
        )
        self.assertIn("source=${localWorkspaceFolder}/../..,", config["workspaceMount"])
        self.assertEqual(
            config["containerEnv"]["BOORUSAMA_WORKSPACE_MODE"], "worktree"
        )

    def test_both_modes_share_downloads_and_isolate_generated_state(self) -> None:
        standard = self.load("standard")
        worktree = self.load("worktree")

        shared_targets = {"/root/.pub-cache", "/root/.gradle", "/root/.cargo"}
        generated_suffixes = {"/.dart_tool", "/build", "/android/.gradle"}

        for config in (standard, worktree):
            mounts = config["mounts"]
            for target in shared_targets:
                self.assertTrue(any(f"target={target}," in mount for mount in mounts))
            for suffix in generated_suffixes:
                generated_mount = next(
                    mount for mount in mounts if f"target={config['workspaceFolder']}{suffix}," in mount
                )
                self.assertIn("source=boorusama-${devcontainerId}-", generated_mount)

    def test_both_modes_preserve_host_adb_and_use_the_shared_image(self) -> None:
        standard = self.load("standard")
        worktree = self.load("worktree")

        for config in (standard, worktree):
            self.assertEqual(
                config["containerEnv"]["ADB_SERVER_SOCKET"],
                "tcp:host.docker.internal:5037",
            )
            self.assertIn(
                "--add-host=host.docker.internal:host-gateway", config["runArgs"]
            )
            self.assertEqual(config["build"]["dockerfile"], "../Dockerfile")
            self.assertEqual(config["build"]["context"], "../..")
            self.assertEqual(
                config["postCreateCommand"], "bash .devcontainer/post-create.sh"
            )


if __name__ == "__main__":
    unittest.main()
