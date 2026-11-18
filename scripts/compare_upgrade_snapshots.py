#!/usr/bin/env python3
"""Compare complete logical state after upgrade and after a cold restart.

This read-only helper does not capture state, execute a migration, verify build
provenance, or replace repository/device upgrade tests. See
``docs/testing/released_upgrade_verification.md`` for the capture contract.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import sys
from typing import Any

MAX_BYTES = 16 * 1024 * 1024
MAX_DEPTH = 64
DOMAINS = frozenset({
    'profiles', 'settings', 'bookmarks', 'following_topics', 'topic_feeds',
    'favorite_tags', 'blacklisted_tags', 'downloads', 'search_history',
})


class SnapshotError(ValueError):
    """Invalid or incomplete capture; never include captured values in errors."""


def _object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise SnapshotError('Duplicate JSON object key')
        result[key] = value
    return result


def _invalid_constant(_: str) -> None:
    raise SnapshotError('Non-finite number in JSON')


def load_snapshot(path: Path) -> dict[str, Any]:
    try:
        with path.open('rb') as source:
            raw = source.read(MAX_BYTES + 1)
        if len(raw) > MAX_BYTES:
            raise SnapshotError('Capture exceeds the 16 MiB input limit')
        data = json.loads(raw.decode('utf-8'), object_pairs_hook=_object,
                          parse_constant=_invalid_constant)
    except (OSError, UnicodeError, json.JSONDecodeError, RecursionError) as error:
        raise SnapshotError('Unreadable or invalid JSON capture') from error
    except ValueError as error:
        if isinstance(error, SnapshotError):
            raise
        raise SnapshotError('Invalid JSON value') from error
    if not isinstance(data, dict) or not DOMAINS.issubset(data):
        raise SnapshotError('Capture must contain every required domain')
    if any(not isinstance(data[name], (dict, list)) for name in DOMAINS):
        raise SnapshotError('Domains must contain records, not counts or scalars')
    pending = [(data, 0)]
    while pending:
        value, depth = pending.pop()
        if depth > MAX_DEPTH:
            raise SnapshotError('Capture nesting exceeds the supported limit')
        if isinstance(value, float) and not math.isfinite(value):
            raise SnapshotError('Non-finite number in JSON')
        if isinstance(value, dict):
            pending.extend((child, depth + 1) for child in value.values())
        elif isinstance(value, list):
            pending.extend((child, depth + 1) for child in value)
    return data


def differences(expected: Any, actual: Any) -> list[str]:
    """Return at most 20 JSON-pointer differences; never print field values.

    Dictionary key order is irrelevant. List order, missing fields, JSON types
    and every additional field are significant. No ignore-field switch exists.
    """
    result: list[str] = []
    pending = [('', expected, actual)]
    while pending and len(result) < 20:
        path, left, right = pending.pop()
        reason = None
        if type(left) is not type(right):
            reason = 'type differs'
        elif isinstance(left, dict):
            for key in reversed(sorted(left.keys() | right.keys())):
                pointer = path + '/' + key.replace('~', '~0').replace('/', '~1')
                if key not in left or key not in right:
                    # A sentinel distinguishes a missing value from JSON null.
                    pending.append((pointer, left.get(key, _MISSING), right.get(key, _MISSING)))
                else:
                    pending.append((pointer, left[key], right[key]))
        elif isinstance(left, list):
            if len(left) != len(right):
                reason = 'list length differs'
            else:
                pending.extend((path + '/' + str(index), left[index], right[index])
                               for index in range(len(left) - 1, -1, -1))
        elif left != right:
            reason = 'value differs'
        if reason:
            result.append(f'{path or "/"}: {reason}')
    return result


_MISSING = object()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('expected', type=Path, help='Reviewed expected logical state from the released fixture')
    parser.add_argument('first_start', type=Path, help='Fresh capture after candidate first start')
    parser.add_argument('reopened', type=Path, help='Independent capture after candidate cold reopen')
    args = parser.parse_args(argv)
    paths = (args.expected, args.first_start, args.reopened)
    try:
        if len({path.resolve() for path in paths}) != 3:
            raise SnapshotError('Provide three distinct capture files')
        expected, first, reopened = [load_snapshot(path) for path in paths]
    except (SnapshotError, OSError) as error:
        print(f'Invalid upgrade observation: {error}', file=sys.stderr)
        return 2
    failures = []
    for label, observed in (('first start', first), ('cold reopen', reopened)):
        for difference in differences(expected, observed):
            failures.append(f'{label}: {difference}')
    if failures:
        print('\n'.join(failures), file=sys.stderr)
        return 1
    print('Persisted-state observations match at first start and cold reopen.\n'
          'This is not proof of capture provenance or of an executed release upgrade.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
