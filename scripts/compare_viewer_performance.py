#!/usr/bin/env python3
"""Compare two viewerSwipeV1 captures; report measurements, never a pass/fail verdict."""
from __future__ import annotations
import argparse
import json
import re
from pathlib import Path
import sys

from analyze_performance import MAX_BYTES, integer, label, percentile_range


def load(path: Path) -> dict:
    if path.stat().st_size > MAX_BYTES:
        raise ValueError('Report exceeds 10 MiB')
    report = json.loads(path.read_text(encoding='utf-8'))
    validate(report)
    return report


def validate(report: dict) -> None:
    if not isinstance(report, dict) or report.get('schema_version') != 1 or report.get('diagnostic_tool') != 'viewerSwipeV1':
        raise ValueError('Expected a viewerSwipeV1 report with schema 1')
    for key in ('summary', 'environment', 'coverage'):
        if not isinstance(report.get(key), dict):
            raise ValueError(f'Malformed {key}')
    summary = report['summary']
    screens = summary.get('screens')
    if not isinstance(screens, dict) or not isinstance(screens.get('postViewer'), dict):
        raise ValueError('No viewer samples: open a viewer and swipe while recording')
    viewer = screens['postViewer']
    if not integer(viewer.get('frames')):
        raise ValueError('No viewer frames: inspect rejected_frames and screen attribution')
    if not isinstance(summary.get('counters'), dict) or not isinstance(summary.get('operations'), list):
        raise ValueError('Malformed viewer counters or operations')
    for key in ('build', 'raster', 'frame_latency', 'ui_delay'):
        if not isinstance(viewer.get(key), dict):
            raise ValueError(f'Malformed viewer {key}')


def compare(before: dict, after: dict) -> str:
    for report in (before, after):
        validate(report)
    lines = ['Viewer-only measurements (before -> after):']
    for key in ('build_mode', 'platform'):
        a, b = (label(r['environment'].get(key)) for r in (before, after))
        lines.append(f'{key}: {a} -> {b}')
        if a != b or a == 'unknown' or (key == 'build_mode' and a == 'debug'):
            lines.append('  WARNING: use matching native profile/release builds for a meaningful comparison.')
    revisions = [r['environment'].get('revision', '') for r in (before, after)]
    lines.append('Revision: ' + ' -> '.join(v if isinstance(v, str) and re.fullmatch(r'[a-fA-F0-9]{7,40}', v) else 'unspecified' for v in revisions))
    a, b = (r['summary']['screens']['postViewer'] for r in (before, after))
    budgets = [v.get('frame_budgets_us') for v in (a, b)]
    if budgets[0] != budgets[1] or any(not v for v in budgets) or any(integer(v.get('estimated_budget_frames')) for v in (a, b)):
        lines.append('WARNING: nominal frame budgets differ, are missing, or used an estimated fallback. Check refresh rate.')
    lines.append(f"Viewer frames: {integer(a.get('frames'))} -> {integer(b.get('frames'))}")
    for key in ('over_budget_frames', 'high_latency_frames'):
        values = [100 * integer(v.get(key)) / integer(v.get('frames')) for v in (a, b)]
        lines.append(f'{key}: {values[0]:.2f}% -> {values[1]:.2f}% ({values[1] - values[0]:+.2f} percentage points)')
    for key in ('build', 'raster', 'frame_latency', 'ui_delay'):
        left, right = a[key], b[key]
        lines.append(f"{key}: count {integer(left.get('count'))} -> {integer(right.get('count'))}; "
                     f"max {integer(left.get('max_us')) / 1000:.2f} -> {integer(right.get('max_us')) / 1000:.2f} ms; "
                     f"p95 interval {percentile_range(left, .95)} -> {percentile_range(right, .95)}")
    lines.append('\nWork per call (all instrumented calls, including fast calls):')
    for key in ('mixedCollectionSize', 'mixedResolvedPosts', 'preloadMediaBuilds', 'preloadCompletedHistory'):
        values = []
        for report in (before, after):
            counter = report['summary']['counters'].get(key, {})
            if not isinstance(counter, dict): raise ValueError('Malformed counter')
            count = integer(counter.get('samples'))
            values.append(f"{integer(counter.get('total')) / count:.2f} mean, {integer(counter.get('max'))} max, {count} calls" if count else 'unavailable')
        lines.append(f"{key}: {' -> '.join(values)}")
    for key in ('mixedPreloadResolve', 'viewerPreloadDispatch', 'viewerPreloadPlan', 'viewerPrecisePageCallback', 'viewerSettlement', 'viewerItemBuild', 'viewerScaffoldBuild'):
        values = []
        for report in (before, after):
            operation = next((o for o in report['summary']['operations'] if isinstance(o, dict) and o.get('op') == key and o.get('kind') == 'sync'), {})
            count = integer(operation.get('count'))
            values.append(f"{count} calls, {integer(operation.get('total_us')) / count / 1000:.3f} ms mean, {integer(operation.get('max_us')) / 1000:.3f} ms max" if count else 'unavailable')
        lines.append(f"{key}: {' -> '.join(values)}")
    lines.append('\nCoverage (before -> after):')
    for key in ('evicted_events', 'unrecorded_spans', 'interrupted_spans', 'rejected_frames', 'frames_without_context'):
        lines.append(f"{key}: {integer(before['coverage'].get(key))} -> {integer(after['coverage'].get(key))}")
    lines.append('\nUse the same device, refresh rate, collection, swipe sequence, duration, and cache/network conditions.')
    lines.append('Counts include viewer entry; callback/build counts depend on swipe cadence. Rejected/evicted data limit interpretation.')
    lines.append('Preload spans can nest; never add their times. Build spans measure these widget methods, not whole subtree rendering.')
    lines.append('Repeat at least three paired runs. Lower numbers in one run do not establish causation or prove the stutter is fixed.')
    return '\n'.join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('before', type=Path)
    parser.add_argument('after', type=Path)
    args = parser.parse_args()
    try:
        print(compare(load(args.before), load(args.after)))
        return 0
    except (OSError, ValueError, TypeError) as error:
        print(f'Cannot compare reports: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
