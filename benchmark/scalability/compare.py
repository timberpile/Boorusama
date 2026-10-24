#!/usr/bin/env python3
"""Run identical opt-in workloads in two already prepared, clean worktrees.

Never installs SDKs, resolves packages, modifies tracked source, or operates a device.
No timings in this repository were produced by this script during the static audit.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import shutil
import statistics
import subprocess
import sys
import tempfile
from typing import Any

BASELINE = "4129eae5d6b4d3947c7d2d878b49e7db9830a97c"
SCENARIOS = {"cover_group", "cover_all", "bookmark_publication", "feed_materialization",
             "preload_history", "cache_byte_reads", "cover_random_group", "cover_random_large_group"}
PREFIX = "SCALABILITY_RESULT "


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def command(args: list[str], cwd: Path) -> str:
    result = subprocess.run(args, cwd=cwd, capture_output=True, text=True,
                            encoding="utf-8", errors="replace", check=True, timeout=120)
    return result.stdout.strip()


def inspect_tree(root: Path) -> dict[str, str]:
    if command(["git", "rev-parse", "--show-toplevel"], root) != str(root):
        # Git on Windows can use '/' where Python prints '\\'.
        actual = Path(command(["git", "rev-parse", "--show-toplevel"], root)).resolve()
        if actual != root:
            raise ValueError(f"Not a worktree root: {root}")
    if command(["git", "status", "--porcelain", "--untracked-files=no"], root):
        raise ValueError(f"Tracked changes in {root}; commit the exact candidate first")
    required = [".fvmrc", "pubspec.lock", ".dart_tool/package_config.json",
                ".fvm/flutter_sdk/bin/flutter",
                "test/core/search/following_topics/topic_test_utils.dart"]
    for name in required:
        if not (root / name).is_file():
            raise ValueError(f"Prepare the pinned FVM dependencies/generated files first: {root / name}")
    return {"root": str(root), "commit": command(["git", "rev-parse", "HEAD"], root),
            "fvmrc_sha256": digest(root / ".fvmrc"), "lock_sha256": digest(root / "pubspec.lock")}


def parse_results(text: str, scale: str, iterations: int, warmups: int) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    failed = False
    finished = False
    for line in text.splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue  # Tool bootstrap may precede the JSON reporter.
        if not isinstance(event, dict):
            continue
        if event.get("type") == "done":
            finished = True
            failed |= event.get("success") is not True
        failed |= event.get("type") == "error"
        failed |= event.get("type") == "testDone" and event.get("result") not in ("success", None)
        if event.get("type") != "print":
            continue
        message = event.get("message", "")
        if not isinstance(message, str) or not message.startswith(PREFIX):
            continue
        row = json.loads(message[len(PREFIX):])
        if not isinstance(row, dict) or row.get("schema") != 1 or row.get("scale") != scale:
            raise ValueError("Invalid workload schema/scale")
        samples = row.get("samples_us")
        if (not isinstance(samples, list) or len(samples) != iterations
                or any(type(value) is not int or value < 0 for value in samples)
                or row.get("warmups") != warmups
                or not isinstance(row.get("inputs"), dict)
                or not isinstance(row.get("work"), dict)):
            raise ValueError("Incomplete or invalid workload measurements")
        rows.append(row)
    names = [row.get("scenario") for row in rows]
    if failed or not finished or len(names) != len(SCENARIOS) or set(names) != SCENARIOS:
        raise ValueError(f"Failed/incomplete workload run; received {names}")
    return rows


def distribution(samples: list[int]) -> dict[str, float | int]:
    ordered = sorted(samples)
    return {"samples": len(ordered), "median_us": statistics.median(ordered),
            "p95_us": ordered[math.ceil(.95 * len(ordered)) - 1],
            "min_us": ordered[0], "max_us": ordered[-1]}


def compare(records: list[dict[str, Any]]) -> list[dict[str, Any]]:
    output = []
    keys = sorted({(row["scale"], row["scenario"]) for row in records})
    for scale, scenario in keys:
        selected = [row for row in records if (row["scale"], row["scenario"]) == (scale, scenario)]
        inputs = {json.dumps(row["inputs"], sort_keys=True) for row in selected}
        if len(inputs) != 1:
            raise ValueError(f"Unequal fixture inputs for {scale}/{scenario}")
        entry: dict[str, Any] = {"scale": scale, "scenario": scenario, "inputs": selected[0]["inputs"]}
        for label in ("baseline", "candidate"):
            side = sorted((row for row in selected if row["variant"] == label), key=lambda row: row["round"])
            if not side:
                raise ValueError(f"Missing {label} for {scale}/{scenario}")
            entry[label] = {**distribution([sample for row in side for sample in row["samples_us"]]),
                           "round_medians_us": [statistics.median(row["samples_us"]) for row in side],
                           "work_by_round": [row["work"] for row in side]}
        base = entry["baseline"]["median_us"]
        entry["candidate_over_baseline_median"] = entry["candidate"]["median_us"] / base if base else None
        output.append(entry)
    return output


def write_json(path: Path, data: Any) -> None:
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", required=True, type=Path)
    parser.add_argument("--candidate", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--expected-baseline", default=BASELINE)
    parser.add_argument("--scales", nargs="+", choices=["small", "medium", "large"], default=["small", "medium", "large"])
    parser.add_argument("--rounds", type=int, default=3)
    parser.add_argument("--warmups", type=int, default=2)
    parser.add_argument("--iterations", type=int, default=7)
    parser.add_argument("--timeout", type=int, default=1800, help="Per-process hang guard, not a performance budget")
    args = parser.parse_args(argv)
    if args.rounds < 1 or args.iterations < 1 or args.warmups < 0 or args.timeout < 1:
        parser.error("Invalid iteration/timeout parameters")
    if len(set(args.scales)) != len(args.scales):
        parser.error("Duplicate scales")
    roots = {"baseline": args.baseline.resolve(), "candidate": args.candidate.resolve()}
    output = args.output.resolve()
    if roots["baseline"] == roots["candidate"]:
        parser.error("Baseline and candidate must be distinct worktrees")
    if any(output == root or root in output.parents for root in roots.values()):
        parser.error("Output must be outside both measured trees")
    if output.exists():
        parser.error("Output already exists; use a new directory to preserve prior measurements")
    fvm = shutil.which("fvm")
    if not fvm:
        parser.error("fvm is not on PATH")
    source = Path(__file__).resolve().parent
    harness = {name: (source / name).read_bytes() for name in ("fixtures.dart", "workloads_test.dart")}
    output.mkdir(parents=True)
    manifest: dict[str, Any] = {"schema": 1, "status": "incomplete", "platform": platform.platform(),
        "python": platform.python_version(), "cpu_count": os.cpu_count(), "fvm": fvm,
        "scales": args.scales, "rounds": args.rounds, "warmups": args.warmups, "iterations": args.iterations,
        "harness_sha256": {name: hashlib.sha256(data).hexdigest() for name, data in harness.items()}}
    temporary: dict[str, Path] = {}
    records: list[dict[str, Any]] = []
    try:
        manifest["trees"] = {name: inspect_tree(root) for name, root in roots.items()}
        if manifest["trees"]["baseline"]["commit"] != args.expected_baseline:
            raise ValueError("Baseline HEAD differs from --expected-baseline")
        for key in ("fvmrc_sha256", "lock_sha256"):
            if manifest["trees"]["baseline"][key] != manifest["trees"]["candidate"][key]:
                raise ValueError(f"Unequal toolchain/dependencies: {key}")
        versions = {name: command([fvm, "flutter", "--version"], root) for name, root in roots.items()}
        manifest["flutter_versions"] = versions
        if versions["baseline"] != versions["candidate"]:
            raise ValueError("FVM resolved different SDK versions")
        for label, root in roots.items():
            directory = Path(tempfile.mkdtemp(prefix="scalability-run-", dir=root / "benchmark"))
            temporary[label] = directory
            for name, data in harness.items():
                (directory / name).write_bytes(data)
        manifest["runs"] = []
        write_json(output / "manifest.json", manifest)
        for round_index in range(args.rounds):
            order = ["baseline", "candidate"] if round_index % 2 == 0 else ["candidate", "baseline"]
            for scale in args.scales:
                for label in order:
                    root = roots[label]
                    test_path = (temporary[label] / "workloads_test.dart").relative_to(root).as_posix()
                    invocation = [fvm, "flutter", "test", "--no-pub", "--concurrency=1", "--reporter=json",
                        f"--dart-define=SCALABILITY_SCALE={scale}",
                        f"--dart-define=SCALABILITY_WARMUPS={args.warmups}",
                        f"--dart-define=SCALABILITY_ITERATIONS={args.iterations}", test_path]
                    stem = f"{round_index + 1:02d}-{scale}-{label}"
                    run = {"variant": label, "scale": scale, "round": round_index + 1, "command": invocation}
                    manifest["runs"].append(run)
                    write_json(output / "manifest.json", manifest)
                    with (output / f"{stem}.jsonl").open("w", encoding="utf-8") as stdout, \
                         (output / f"{stem}.stderr.txt").open("w", encoding="utf-8") as stderr:
                        result = subprocess.run(invocation, cwd=root, stdout=stdout, stderr=stderr,
                                                timeout=args.timeout, check=False)
                    run["exit_code"] = result.returncode
                    if result.returncode:
                        raise RuntimeError(f"{stem} failed; inspect retained logs")
                    rows = parse_results((output / f"{stem}.jsonl").read_text(encoding="utf-8"),
                                         scale, args.iterations, args.warmups)
                    records.extend({**row, "variant": label, "round": round_index + 1} for row in rows)
                    write_json(output / "records.json", records)
        for label, root in roots.items():
            if inspect_tree(root)["commit"] != manifest["trees"][label]["commit"]:
                raise RuntimeError("A measured worktree changed HEAD during execution")
        write_json(output / "comparison.json", compare(records))
        manifest["status"] = "complete"
        return 0
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        manifest["error"] = str(error)
        print(str(error), file=sys.stderr)
        return 1
    finally:
        for directory in temporary.values():
            # Only the unique directories created by this invocation are removed.
            shutil.rmtree(directory, ignore_errors=True)
        write_json(output / "manifest.json", manifest)


if __name__ == "__main__":
    raise SystemExit(main())
