#!/usr/bin/env python3
"""Reserve one Android emulator serial across Boorusama agent sessions."""

import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import fcntl
import hashlib
import hmac
import json
import os
from pathlib import Path
import re
import secrets
import stat
import sys
import tempfile
import time


TTL_SECONDS = 30 * 60
LEASE_DIR = Path(f"/tmp/boorusama-emulator-leases-{os.getuid()}")
SERIAL_PATTERN = re.compile(r"emulator-[0-9]+\Z")


def expiry_label(timestamp):
    return datetime.fromtimestamp(timestamp, timezone.utc).isoformat(timespec="seconds")


def ensure_directory():
    try:
        LEASE_DIR.mkdir(mode=0o700)
    except FileExistsError:
        pass
    info = LEASE_DIR.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
        raise ValueError(f"Unsafe lease directory: {LEASE_DIR}")


@contextmanager
def locked_serial(serial):
    ensure_directory()
    lock_path = LEASE_DIR / f"{serial}.lock"
    fd = os.open(lock_path, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid():
            raise ValueError(f"Unsafe lock file: {lock_path}")
        fcntl.flock(fd, fcntl.LOCK_EX)
        yield LEASE_DIR / f"{serial}.json"
    finally:
        os.close(fd)


def read_lease(path):
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    except FileNotFoundError:
        return None
    with os.fdopen(fd, "r", encoding="utf-8") as source:
        info = os.fstat(source.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid():
            raise ValueError(f"Unsafe lease file: {path}")
        lease = json.load(source)
    if not isinstance(lease, dict) or not all(
        key in lease for key in ("serial", "owner", "token_hash", "expires_at")
    ):
        raise ValueError(f"Invalid lease file: {path}")
    if lease["serial"] != path.stem:
        raise ValueError(f"Lease serial does not match file: {path}")
    return lease


def write_lease(path, lease):
    fd, temporary_name = tempfile.mkstemp(prefix=f".{path.stem}-", dir=LEASE_DIR)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as target:
            json.dump(lease, target, indent=2, sort_keys=True)
            target.write("\n")
            target.flush()
            os.fsync(target.fileno())
        os.replace(temporary_name, path)
    finally:
        if os.path.exists(temporary_name):
            os.unlink(temporary_name)


def print_lease(prefix, lease):
    print(f"{prefix} serial={lease['serial']}")
    print(f"owner={lease['owner']}")
    print(f"expires={expiry_label(lease['expires_at'])}")


def operate(args):
    with locked_serial(args.serial) as path:
        lease = read_lease(path)
        now = time.time()
        active = lease is not None and lease["expires_at"] > now

        if args.command == "status":
            if lease is None:
                print(f"available serial={args.serial}")
            else:
                print_lease("claimed" if active else "expired", lease)
            return 0

        if args.command == "claim":
            if active:
                print_lease("busy", lease)
                return 2
            token = secrets.token_hex(32)
            lease = {
                "serial": args.serial,
                "owner": args.owner,
                "token_hash": hashlib.sha256(token.encode("ascii")).hexdigest(),
                "expires_at": now + TTL_SECONDS,
                "expires_utc": expiry_label(now + TTL_SECONDS),
            }
            write_lease(path, lease)
            print_lease("claimed", lease)
            print(f"token={token}")
            return 0

        token_hash = hashlib.sha256(args.token.encode("utf-8")).hexdigest()
        if not active or not hmac.compare_digest(lease["token_hash"], token_hash):
            print(f"No matching active lease for {args.serial}", file=sys.stderr)
            return 2

        if args.command == "renew":
            lease["expires_at"] = now + TTL_SECONDS
            lease["expires_utc"] = expiry_label(lease["expires_at"])
            write_lease(path, lease)
            print_lease("renewed", lease)
        else:
            path.unlink()
            print(f"released serial={args.serial}")
        return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for command in ("claim", "renew", "release", "status"):
        command_parser = commands.add_parser(command)
        command_parser.add_argument("serial", help="Exact emulator serial, e.g. emulator-5554")
        if command == "claim":
            command_parser.add_argument("--owner", required=True, help="Session and worktree label")
        if command in ("renew", "release"):
            command_parser.add_argument("--token", required=True, help="Token returned by claim")
    args = parser.parse_args()
    if not SERIAL_PATTERN.fullmatch(args.serial):
        parser.error("serial must be an exact emulator-NNNN serial")
    if args.command == "claim" and (
        not args.owner.strip() or len(args.owner) > 250 or "\n" in args.owner
    ):
        parser.error("owner must be a nonempty, single-line session/worktree label")
    try:
        return operate(args)
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"Lease error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
