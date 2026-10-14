import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "physical_core_count", Path(__file__).parents[1] / "physical_core_count.py"
)
cores = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cores)


class PhysicalCoreCountTests(unittest.TestCase):
    def topology(self, root, identities):
        for cpu, socket, core in identities:
            path = root / f"cpu{cpu}" / "topology"
            path.mkdir(parents=True)
            (path / "physical_package_id").write_text(str(socket))
            (path / "core_id").write_text(str(core))

    def test_smt_siblings_count_once(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.topology(root, [(0, 0, 0), (1, 0, 0), (2, 0, 1), (3, 0, 1)])
            self.assertEqual(cores.linux_core_count(root, {0, 1, 2, 3}), 2)

    def test_non_smt_cores_are_not_halved(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.topology(root, [(cpu, 0, cpu) for cpu in range(4)])
            self.assertEqual(cores.linux_core_count(root, set(range(4))), 4)

    def test_core_ids_are_distinct_across_sockets(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.topology(root, [(0, 0, 0), (1, 1, 0)])
            self.assertEqual(cores.linux_core_count(root, {0, 1}), 2)

    def test_affinity_limits_available_cores(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.topology(root, [(0, 0, 0), (1, 0, 0), (2, 0, 1)])
            self.assertEqual(cores.linux_core_count(root, {0, 1}), 1)

    def test_incomplete_or_invalid_topology_falls_back_to_one(self):
        for error in (FileNotFoundError(), ValueError()):
            with (
                self.subTest(error=type(error)),
                patch.object(cores.sys, "platform", "linux"),
                patch.object(cores, "linux_core_count", side_effect=error),
            ):
                self.assertEqual(cores.physical_core_count(), 1)

    def test_macos_queries_physical_cores(self):
        with (
            patch.object(cores.sys, "platform", "darwin"),
            patch.object(cores.subprocess, "check_output", return_value="8\n") as query,
        ):
            self.assertEqual(cores.physical_core_count(), 8)
            query.assert_called_once_with(["sysctl", "-n", "hw.physicalcpu"], text=True)

    def test_unknown_platform_has_conservative_fallback(self):
        with patch.object(cores.sys, "platform", "unknown"):
            self.assertEqual(cores.physical_core_count(), 1)
