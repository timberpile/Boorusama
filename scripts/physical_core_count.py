#!/usr/bin/env python3
"""Print available physical cores, falling back to one if topology is unknown."""

import os
from pathlib import Path
import subprocess
import sys


def linux_core_count(cpu_root, available_cpus):
    cores = set()
    for cpu in available_cpus:
        topology = cpu_root / f"cpu{cpu}" / "topology"
        socket = int((topology / "physical_package_id").read_text())
        core = int((topology / "core_id").read_text())
        if socket < 0 or core < 0:
            raise ValueError("Unknown CPU topology")
        cores.add((socket, core))
    return max(1, len(cores))


def physical_core_count():
    try:
        if sys.platform.startswith("linux"):
            return linux_core_count(
                Path("/sys/devices/system/cpu"), os.sched_getaffinity(0)
            )
        if sys.platform == "darwin":
            return max(
                1,
                int(subprocess.check_output(
                    ["sysctl", "-n", "hw.physicalcpu"], text=True
                )),
            )
    except (AttributeError, OSError, ValueError, subprocess.SubprocessError):
        pass
    # Do not guess physical topology from the logical thread count.
    return 1


if __name__ == "__main__":
    print(physical_core_count())
