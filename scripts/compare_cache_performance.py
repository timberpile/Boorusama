#!/usr/bin/env python3
"""Compare cache captures using complete aggregates, including fast operations."""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import re
import sys

from analyze_performance import (MAX_BYTES, CACHE_OPERATIONS, CACHE_COUNTERS,
                                 FRAME_METRICS, above_threshold, counter_text, distribution_text,
                                 integer, label, operation_text)


def validate(report: object) -> None:
    if not isinstance(report, dict) or report.get('schema_version') != 1:
        raise ValueError('Expected a schema 1 performance report')
    for key in ('environment', 'summary', 'coverage'):
        if not isinstance(report.get(key), dict):
            raise ValueError(f'Malformed {key}')
    summary = report['summary']
    if not integer(summary.get('frames')):
        raise ValueError('No accepted frames: record while scrolling and inspect coverage')
    operations = summary.get('operations')
    if not isinstance(operations, list) or any(not isinstance(op, dict) for op in operations):
        raise ValueError('Malformed operations')
    if not any(op.get('op') in CACHE_OPERATIONS and integer(op.get('count')) for op in operations):
        raise ValueError('No cache operation samples: use an instrumented build and exercise the cache')
    for op in operations:
        if not isinstance(op.get('op'), str) or not isinstance(op.get('kind'), str):
            raise ValueError('Malformed operation label or kind')
    for key in FRAME_METRICS:
        if key in summary and not isinstance(summary[key], dict):
            raise ValueError(f'Malformed {key}')
    for key in ('screens', 'counters'):
        data = summary.get(key, {})
        if not isinstance(data, dict) or any(not isinstance(v, dict) for v in data.values()):
            raise ValueError(f'Malformed {key}')


def load(path: Path) -> dict:
    if path.stat().st_size > MAX_BYTES:
        raise ValueError('Report exceeds 10 MiB')
    report = json.loads(path.read_text(encoding='utf-8'))
    validate(report)
    return report


def compare(before: dict, after: dict) -> str:
    for report in (before, after):
        validate(report)
    reports = before, after
    summaries = [r['summary'] for r in reports]
    lines = ['Cache performance measurements (before -> after):']
    variants = [label(r['environment'].get('variant')) for r in reports]
    lines.append(f'variant: {" -> ".join(variants)}')
    if variants != ['baseline', 'fixed']:
        lines.append('WARNING: expected baseline -> fixed diagnostic variants.')
    for key in ('build_mode', 'platform', 'flavor'):
        values = [label(r['environment'].get(key)) for r in reports]
        lines.append(f'{key}: {" -> ".join(values)}')
        if values[0] != values[1] or 'unknown' in values or (key == 'build_mode' and 'debug' in values):
            lines.append('WARNING: use matching native profile/release builds and dev flavor; metadata is missing or differs.')
    revisions = [r['environment'].get('revision', '') for r in reports]
    lines.append('Revision: ' + ' -> '.join(v if isinstance(v, str) and re.fullmatch(r'[a-fA-F0-9]{7,40}', v) else 'unspecified' for v in revisions))
    for key in ('elapsed_us', 'foreground_us'):
        values = [f'{integer(r[key]) / 1e6:.3f}s' if key in r else 'unavailable' for r in reports]
        lines.append(f'{key}: {" -> ".join(values)}')
    rates = []
    for r in reports:
        duration = integer(r.get('foreground_us'))
        count = integer(r['summary'].get('ui_delay', {}).get('count'))
        rates.append(f'{count * 60000000 / duration:.2f}/foreground minute' if duration else 'unavailable')
    lines.append('UI delays >=50 ms: ' + ' -> '.join(rates))
    for name in ('allScreens', *sorted(set().union(*(s.get('screens', {}).keys() for s in summaries)))):
        scopes = summaries if name == 'allScreens' else [s.get('screens', {}).get(name, {}) for s in summaries]
        lines.append(f'\n{label(name)} frames: ' + ' -> '.join(str(integer(s.get('frames'))) if s else 'unavailable' for s in scopes))
        for key in ('over_budget_frames', 'high_latency_frames'):
            values = [f"{100 * integer(s.get(key)) / integer(s['frames']):.2f}%" if integer(s.get('frames')) else 'unavailable' for s in scopes]
            lines.append(f'{key}: {" -> ".join(values)}')
        if name != 'allScreens':
            budgets = [s.get('frame_budgets_us') for s in scopes]
            if budgets[0] != budgets[1] or any(not v for v in budgets) or any(integer(s.get('estimated_budget_frames')) for s in scopes):
                lines.append('WARNING: screen frame budgets differ, are missing, or use an estimated fallback.')
        for metric in FRAME_METRICS:
            lines.append(f'{metric}: ' + ' -> '.join(distribution_text(s.get(metric)) for s in scopes))
        for threshold in (50, 100, 250, 500):
            lines.append(f'frame_latency >{threshold} ms: ' + ' -> '.join(above_threshold(s.get('frame_latency'), threshold * 1000) for s in scopes))
    lines.append('\nCache operations (sync elapsed and async wall time are separate; never sum):')
    maps = [{(op.get('op'), op.get('kind')): op for op in s['operations']} for s in summaries]
    for op in CACHE_OPERATIONS:
        kinds = sorted({kind for data in maps for name, kind in data if name == op and kind in ('sync', 'asyncWall')})
        if not kinds:
            lines.append(f'{op}: unavailable -> unavailable')
        for kind in kinds:
            lines.append(f'{op} [{kind}]: ' + ' -> '.join(operation_text(data.get((op, kind))) for data in maps))
    lines.append('\nCache state/work and decoded-image cache:')
    for counter in CACHE_COUNTERS:
        lines.append(f'{counter}: ' + ' -> '.join(counter_text(s.get('counters', {}).get(counter)) for s in summaries))
    lines.append('\nCoverage (before -> after):')
    for key in ('evicted_events', 'unrecorded_spans', 'interrupted_spans', 'rejected_frames', 'frames_without_context'):
        lines.append(f'{key}: ' + ' -> '.join(str(integer(r['coverage'].get(key))) if key in r['coverage'] else 'unavailable' for r in reports))
    lines.append('\nA missing operation may be unexercised or uninstrumented; it is not zero cost.')
    lines.append('Global frame counts include the diagnostics page; compare the target screen summaries separately.')
    lines.append('Worker wall time includes isolate scheduling, encoding and I/O; it is not UI blocking or sampled CPU time.')
    lines.append('Cache lookup counts include internal validation, not network requests. Cache state samples may combine managers.')
    lines.append('Use matching device, refresh rate, cache entries/bytes, workload, duration and settings; repeat at least three paired runs.')
    lines.append('Retain populated cache and app data. Do not infer FPS or dropped frames from idle gaps, or causation from overlap.')
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
        print(f'Cannot compare cache reports: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
