#!/usr/bin/env python3
"""Manage isolated agent worktrees without changing the primary checkout."""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys


SLUG_PATTERN = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*\Z")


class WorktreeError(Exception):
    pass


def git(directory, *arguments, check=True):
    result = subprocess.run(
        ["git", "-C", str(directory), *arguments],
        capture_output=True,
        text=True,
    )
    if check and result.returncode:
        detail = result.stderr.strip() or result.stdout.strip()
        raise WorktreeError(detail or f"Git {' '.join(arguments)} failed")
    return result


def worktrees(directory):
    # NUL records preserve paths containing spaces, quotes, or newlines.
    output = git(directory, "worktree", "list", "--porcelain", "-z").stdout
    records = []
    for block in output.split("\0\0"):
        record = {}
        for field in block.split("\0"):
            if field:
                key, _, value = field.partition(" ")
                record[key] = value
        if record:
            records.append(record)
    return records


def repository():
    directory = Path.cwd()
    try:
        records = worktrees(directory)
    except WorktreeError as error:
        raise WorktreeError(f"{error}. Run this helper inside a repository checkout.") from error
    # Git lists the primary worktree first, including from a linked worktree.
    if not records or "bare" in records[0]:
        raise WorktreeError("Run this helper inside a non-bare repository checkout.")
    root = Path(records[0]["worktree"]).resolve()
    if not root.is_dir():
        raise WorktreeError(f"Primary checkout is missing: {root}. Restore it first.")
    return root, records


def branch_exists(root, branch):
    result = git(
        root, "show-ref", "--verify", "--quiet", f"refs/heads/{branch}", check=False
    )
    if result.returncode not in (0, 1):
        raise WorktreeError(result.stderr.strip() or f"Cannot inspect branch {branch}")
    return result.returncode == 0


def path_issue(path):
    if path.parent.is_symlink() or path.is_symlink():
        return f"Symlinked worktree path is unsafe: {path}. Inspect it manually."
    if path.parent.exists() and not path.parent.is_dir():
        return f"Worktree parent is not a directory: {path.parent}. Inspect it manually."
    return None


def inspect(root, records, slug):
    branch = f"agent/{slug}"
    path = root / ".worktrees" / slug
    expected_ref = f"refs/heads/{branch}"
    record = next(
        (item for item in records if Path(item["worktree"]) == path), None
    )
    attached = [
        item["worktree"] for item in records if item.get("branch") == expected_ref
    ]
    result = {
        "branch": branch,
        "path": str(path),
        "branch_exists": branch_exists(root, branch),
        "worktree_exists": path.is_dir(),
        "registered": record is not None,
        "attached_paths": attached,
        "head": None,
        "actual_branch": None,
        "dirty": None,
        "ignored_files": None,
        "locked": record is not None and "locked" in record,
        "issues": [],
    }
    issues = result["issues"]
    unsafe = path_issue(path)
    if unsafe:
        issues.append(unsafe)
    if not result["branch_exists"]:
        issues.append(f"Branch {branch} is missing.")
    elsewhere = [location for location in attached if Path(location) != path]
    if elsewhere:
        issues.append(f"Branch {branch} is attached elsewhere: {', '.join(elsewhere)}.")
    if record is None:
        if os.path.lexists(path):
            issues.append(f"Path {path} exists but is not registered with Git. Inspect it manually.")
        else:
            issues.append(f"Worktree {path} is missing.")
    elif not result["worktree_exists"]:
        issues.append(f"Registered worktree {path} is missing on disk. Inspect it manually.")
    elif not unsafe:
        try:
            actual_root = Path(
                git(path, "rev-parse", "--show-toplevel").stdout.removesuffix("\n")
            ).resolve()
            common = git(
                path, "rev-parse", "--path-format=absolute", "--git-common-dir"
            ).stdout.removesuffix("\n")
            expected_common = git(
                root, "rev-parse", "--path-format=absolute", "--git-common-dir"
            ).stdout.removesuffix("\n")
            if (
                actual_root != path
                or Path(common).resolve() != Path(expected_common).resolve()
            ):
                raise WorktreeError(
                    f"Path {path} does not match this repository's registered worktree."
                )
            ref = git(path, "symbolic-ref", "--quiet", "HEAD", check=False)
            result["actual_branch"] = (
                ref.stdout.strip().removeprefix("refs/heads/") or None
            )
            result["head"] = git(path, "rev-parse", "--verify", "HEAD").stdout.strip()
            # Status must not refresh/write the index while inspecting a task.
            changes = git(
                path, "--no-optional-locks", "status", "--porcelain", "-z",
                "--untracked-files=all", "--ignored=matching",
            ).stdout
            entries = changes.split("\0")
            result["dirty"] = any(entry and not entry.startswith("!! ") for entry in entries)
            result["ignored_files"] = any(entry.startswith("!! ") for entry in entries)
            if ref.stdout.strip() != expected_ref or record.get("branch") != expected_ref:
                issues.append(
                    f"Worktree {path} is on "
                    f"{result['actual_branch'] or 'detached HEAD'}, expected {branch}."
                )
        except WorktreeError as error:
            issues.append(str(error))
    if not issues:
        result["state"] = "ready"
    elif not result["registered"] and not os.path.lexists(path) and not result["branch_exists"]:
        result["state"] = "missing"
    else:
        result["state"] = "mismatch"
    return result


def operate(args):
    root, records = repository()
    branch = f"agent/{args.slug}"
    path = root / ".worktrees" / args.slug

    if args.command == "create":
        unsafe = path_issue(path)
        if unsafe:
            raise WorktreeError(unsafe)
        attached = [
            item["worktree"] for item in records
            if item.get("branch") == f"refs/heads/{branch}"
        ]
        if attached:
            raise WorktreeError(
                f"Branch {branch} already has a worktree at {', '.join(attached)}. "
                f"Run status {args.slug} and deliberately continue there."
            )
        if any(Path(item["worktree"]) == path for item in records):
            raise WorktreeError(
                f"Worktree {path} is already registered. "
                f"Run status {args.slug} and inspect the mismatch."
            )
        if os.path.lexists(path):
            raise WorktreeError(
                f"Path {path} already exists. Inspect it manually; nothing was overwritten."
            )
        if branch_exists(root, branch):
            raise WorktreeError(
                f"Branch {branch} already exists without a worktree. "
                "Inspect it manually or choose a new slug."
            )
        base = git(
            root, "rev-parse", "--verify", "refs/heads/develop^{commit}", check=False
        )
        if base.returncode:
            raise WorktreeError(
                "Local develop is missing or invalid. Provide it explicitly before "
                "creating a task worktree; this helper never fetches."
            )
        commit = base.stdout.strip()
        # Pin the observed local develop commit, even if develop moves concurrently.
        try:
            git(root, "worktree", "add", "-b", branch, str(path), commit)
        except WorktreeError as error:
            raise WorktreeError(
                f"Could not create {branch} at {path}: {error}. "
                f"Inspect status {args.slug} before retrying; "
                "Git may have left a branch or partial worktree."
            ) from error
        print(json.dumps({
            "state": "created", "branch": branch, "path": str(path),
            "base": "develop", "base_commit": commit,
        }, indent=2))
        return 0

    state = inspect(root, records, args.slug)
    if args.command == "status":
        print(json.dumps(state, indent=2))
        return 0 if state["state"] == "ready" else 1

    if state["issues"]:
        raise WorktreeError("Cannot remove task worktree: " + " ".join(state["issues"]))
    if state["locked"]:
        raise WorktreeError(
            f"Worktree {path} is locked. Inspect the lock before explicitly unlocking it."
        )
    if state["dirty"] or state["ignored_files"]:
        raise WorktreeError(
            f"Worktree {path} is dirty or contains ignored files. "
            "Preserve or resolve those files explicitly before removal; no force is used."
        )
    git(root, "worktree", "remove", str(path))
    print(json.dumps({
        "state": "removed", "branch": branch, "path": str(path),
        "branch_preserved": True,
    }, indent=2))
    return 0


def main():
    parser = argparse.ArgumentParser(
        description=__doc__,
        epilog=(
            "Run inside any checkout of this repository. Output is JSON; "
            "exit 0 means success (status: matching worktree), "
            "1 means Git/state failure, and 2 means invalid usage. "
            "No bootstrap, branch deletion, integration, or remote operations."
        ),
    )
    commands = parser.add_subparsers(dest="command", required=True)
    for command, help_text in (
        ("create", "Create agent/<slug> at the primary checkout's .worktrees/<slug> from current local develop; existing state is refused."),
        ("status", "Inspect branch, path, HEAD, dirty/ignored state and mismatches; never change files."),
        ("remove", "Remove only a clean matching task worktree; refuse ignored files, locks and mismatches; always preserve the branch."),
    ):
        command_parser = commands.add_parser(
            command, help=help_text, description=help_text
        )
        command_parser.add_argument(
            "slug", help="Lowercase ASCII letters/digits separated by single hyphens, e.g. bookmark-sort-order"
        )
    args = parser.parse_args()
    if not SLUG_PATTERN.fullmatch(args.slug):
        parser.error("slug must contain lowercase ASCII letters/digits separated by single hyphens")
    try:
        return operate(args)
    except (WorktreeError, OSError) as error:
        print(f"Worktree error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
