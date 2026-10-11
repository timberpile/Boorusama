#!/usr/bin/env python3
"""Summarize a Boorusama performance JSON export, with conservative overlap hints."""
from __future__ import annotations
import argparse
from collections import Counter
import json
from pathlib import Path
import re
import sys

MAX_BYTES = 10 * 1024 * 1024

def label(value: object) -> str:
    return value if isinstance(value, str) and re.fullmatch(r'[A-Za-z][A-Za-z0-9]{0,63}', value) else 'unknown'

def integer(value: object, default: int = 0) -> int:
    return value if type(value) is int and 0 <= value < 2**63 else default

def overlap(a: dict, b: dict) -> int:
    start_a, start_b = integer(a.get('t_us')), integer(b.get('t_us'))
    return max(0, min(start_a + integer(a.get('duration_us')),
                      start_b + integer(b.get('duration_us'))) - max(start_a, start_b))

def percentile_range(distribution: dict, percentile: float) -> str:
    count = integer(distribution.get('count'))
    bounds = distribution.get('histogram_bounds_us', [])
    counts = distribution.get('histogram_counts', [])
    if not count or not isinstance(bounds, list) or not isinstance(counts, list) or len(counts) != len(bounds) + 1:
        return 'unavailable'
    target, cumulative, lower = count * percentile, 0, 0
    for i, amount in enumerate(counts):
        cumulative += integer(amount)
        if cumulative >= target:
            return (f'>{lower / 1000:g} ms' if i == len(bounds)
                    else f'{lower / 1000:g}–{integer(bounds[i]) / 1000:g} ms')
        if i < len(bounds): lower = integer(bounds[i])
    return 'unavailable'

def summarize(report: dict, limit: int = 12) -> str:
    if report.get('schema_version') != 1:
        raise ValueError('Unsupported performance report schema')
    summary, environment, coverage = (report.get(key, {}) for key in ('summary', 'environment', 'coverage'))
    if not all(isinstance(value, dict) for value in (summary, environment, coverage)):
        raise ValueError('Malformed report metadata')
    events = report.get('events', [])
    if not isinstance(events, list) or len(events) > 10000 or any(not isinstance(e, dict) for e in events):
        raise ValueError('Malformed or oversized event collection')
    revision = environment.get('revision', '')
    revision = revision if isinstance(revision, str) and re.fullmatch(r'[a-fA-F0-9]{7,40}', revision) else 'unspecified'
    lines = [
        f"Build: {label(environment.get('build_mode'))}; platform: {label(environment.get('platform'))}; revision: {revision}",
        f"Captured: {integer(summary.get('frames'))} frames; {integer(summary.get('over_budget_frames'))} over budget; "
        f"{integer(summary.get('high_latency_frames'))} high-latency frames.",
    ]
    for name in ('build', 'raster', 'frame_latency', 'ui_delay'):
        data = summary.get(name, {})
        if not isinstance(data, dict): continue
        lines.append(f"{name}: count={integer(data.get('count'))}, max={integer(data.get('max_us')) / 1000:.2f} ms, "
                     f"p95 histogram interval={percentile_range(data, .95)}")
    lines.append('Coverage: ' + ', '.join(f'{key}={integer(coverage.get(key))}' for key in (
        'evicted_events', 'unrecorded_spans', 'interrupted_spans', 'rejected_frames', 'frames_without_context')))
    operation_stats = summary.get('operations', [])
    if isinstance(operation_stats, list):
        lines.append('\nSlowest instrumented operations (all calls, elapsed time, do not sum nested spans):')
        for operation in sorted((op for op in operation_stats if isinstance(op, dict)),
                                key=lambda op: integer(op.get('max_us')), reverse=True)[:10]:
            lines.append(f"  {label(operation.get('op'))} [{label(operation.get('kind'))}]: "
                         f"count={integer(operation.get('count'))}, "
                         f"max={integer(operation.get('max_us')) / 1000:.2f} ms, "
                         f"total={integer(operation.get('total_us')) / 1000:.2f} ms")
    markers = [e for e in events if e.get('type') == 'marker']
    if markers:
        lines.append('Markers: ' + ', '.join(f"+{integer(e.get('t_us')) / 1e6:.3f}s" for e in markers[-12:]))
    spans = [e for e in events if e.get('type') == 'span']
    stalls = sorted((e for e in events if e.get('type') in ('slow_frame', 'ui_delay')
                     and e.get('screen') != 'diagnostics'), key=lambda e: integer(e.get('duration_us')), reverse=True)
    lines.append('\nLargest retained stalls outside the diagnostics page:')
    if not stalls: lines.append('No retained stall details. Check summary and eviction counters before drawing conclusions.')
    counts: Counter[str] = Counter()
    for stall in stalls[:limit]:
        candidates = [s for s in spans if s.get('kind') == 'sync' and overlap(s, stall) > 0]
        candidates.sort(key=lambda s: overlap(s, stall), reverse=True)
        sync_names = list(dict.fromkeys(label(s.get('op')) for s in candidates))[:5]
        counts.update(sync_names)
        wall_names = list(dict.fromkeys(label(s.get('op')) for s in spans
                                       if s.get('kind') == 'asyncWall' and overlap(s, stall)))[:5]
        lines.append(f"  +{integer(stall.get('t_us')) / 1e6:.3f}s {label(stall.get('screen'))} "
                     f"{stall.get('type')}: {integer(stall.get('duration_us')) / 1000:.2f} ms")
        if stall.get('type') == 'slow_frame':
            lines.append(f"    build={integer(stall.get('build_us')) / 1000:.2f} ms; "
                         f"raster={integer(stall.get('raster_us')) / 1000:.2f} ms; "
                         f"vsync wait={integer(stall.get('vsync_overhead_us')) / 1000:.2f} ms")
        lines.append('    Synchronous overlap: ' + (', '.join(sync_names) or 'none recorded'))
        lines.append('    Async wall-time overlap (includes waiting): ' + (', '.join(wall_names) or 'none recorded'))
    lines.append('\nMost frequent synchronous overlap hints among these stalls:')
    lines.extend(f'  {name}: {count}' for name, count in counts.most_common(10))
    if not counts: lines.append('  None recorded; this does not rule out uninstrumented Dart, native or GPU work.')
    lines.append('\nOverlaps are investigative hints, not causal stack traces. Do not sum nested/parallel span durations.')
    lines.append('Timer delays can include OS scheduling, thermal contention, or debugger pauses. Idle frame gaps are not counted as jank.')
    if environment.get('build_mode') == 'debug':
        lines.append('Debug results include framework overhead; compare the regression using profile/release captures.')
    return '\n'.join(lines)

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report', type=Path)
    parser.add_argument('--limit', type=int, default=12, choices=range(1, 51), metavar='1..50')
    args = parser.parse_args()
    try:
        if args.report.stat().st_size > MAX_BYTES: raise ValueError('Report exceeds 10 MiB')
        report = json.loads(args.report.read_text(encoding='utf-8'))
        if not isinstance(report, dict): raise ValueError('Expected a JSON object')
        print(summarize(report, args.limit))
        return 0
    except (OSError, ValueError) as error:
        print(f'Cannot analyze report: {error}', file=sys.stderr)
        return 1

if __name__ == '__main__':
    raise SystemExit(main())
