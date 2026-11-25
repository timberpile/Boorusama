#!/usr/bin/env python3
"""Read-only released-to-candidate schema audit; never executes app code.

The reviewed locators are not a Dart parser or migration proof. --inventory
also reports changed version-bearing source lines for manual coverage review.
Exit codes: 0 registered contracts pass; 1 policy violations; 2 incomplete/error.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path, PurePosixPath
from typing import Callable

MAX_SOURCE_BYTES = 8 * 1024 * 1024
VERSION_MARKER = re.compile(r'version|schema|protocol|\bv[0-9]+\b|[._]v[0-9]+\b', re.IGNORECASE)
SOURCE_ROOTS = ('lib', 'android/app/src/main', 'packages/boorusama_cli/lib/src/migrations')
TOKENS = re.compile(r"'''[\s\S]*?'''|\"\"\"[\s\S]*?\"\"\"|'(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\"|//[^\n]*|/\*[\s\S]*?\*/")


class AuditError(ValueError):
    """Missing/ambiguous evidence must not be interpreted as compatibility."""


def without_comments(source: str) -> str:
    def replace(match: re.Match[str]) -> str:
        token = match.group()
        return re.sub(r'[^\n]', ' ', token) if token.startswith(('//', '/*')) else token
    return TOKENS.sub(replace, source)


def valid_path(value: object) -> str:
    if not isinstance(value, str) or not value or any(ord(c) < 32 for c in value):
        raise AuditError('Invalid source path')
    path = PurePosixPath(value)
    if path.is_absolute() or '..' in path.parts or str(path) != value or '\\' in value:
        raise AuditError(f'Non-canonical source path: {value!r}')
    return value


def validate_rules(rules: object) -> list[dict]:
    if not isinstance(rules, list) or not rules:
        raise AuditError('Expected a nonempty contracts list')
    ids: set[str] = set()
    for rule in rules:
        if not isinstance(rule, dict) or not isinstance(rule.get('id'), str):
            raise AuditError('Contract needs an ID')
        if not re.fullmatch(r'[a-z0-9][a-z0-9-]*', rule['id']) or rule['id'] in ids:
            raise AuditError('Invalid or duplicate contract ID')
        ids.add(rule['id'])
        valid_path(rule.get('path'))
        if 'baseline_path' in rule:
            valid_path(rule['baseline_path'])
        additional_paths = rule.get('additional_paths', [])
        if not isinstance(additional_paths, list):
            raise AuditError('Additional source paths must be a list')
        for path in additional_paths:
            valid_path(path)
        for field in ('pattern', 'baseline_pattern'):
            if field == 'baseline_pattern' and field not in rule:
                continue
            try:
                compiled = re.compile(rule[field], re.MULTILINE)
            except (KeyError, TypeError, re.error) as error:
                raise AuditError(f"{rule['id']}: invalid {field}") from error
            if 'version' not in compiled.groupindex:
                raise AuditError(f"{rule['id']}: pattern needs named version capture")
        for field in ('shared_symbol', 'baseline_shared_symbol'):
            if field in rule and (
                not (rule.get('same_as') or rule.get('reader_for'))
                or not isinstance(rule[field], str)
                or not re.fullmatch(r'[A-Za-z_]\w*', rule[field])
            ):
                raise AuditError('A shared version symbol requires a contract relation and valid identifier')
        if rule.get('same_as') and rule.get('reader_for'):
            raise AuditError('A contract cannot be both an alias and a reader')
        if 'baseline_absent' in rule and type(rule['baseline_absent']) is not bool:
            raise AuditError('baseline_absent must be a boolean assertion')
    for rule in rules:
        ref = rule.get('same_as') or rule.get('reader_for')
        if ref and ref not in ids:
            raise AuditError(f"{rule['id']}: unknown referenced contract {ref}")
    return rules


def versions(
    source: str | None,
    pattern: str,
    ternary: bool = False,
    shared: tuple[str, list[int]] | None = None,
) -> list[int] | None:
    if source is None:
        return None
    matches = [m.group('version') for m in re.finditer(pattern, without_comments(source), re.MULTILINE)]
    if shared is not None and matches.count(shared[0]) != 1:
        raise AuditError('Shared version symbol missing or ambiguous')
    values: set[int] = set()
    for expression in matches:
        if shared is not None and expression == shared[0]:
            values.update(shared[1])
        elif re.fullmatch(r'[0-9]{1,9}', expression or ''):
            values.add(int(expression))
        elif ternary and re.fullmatch(r'(?:[A-Za-z_]\w*(?:\s*(?:==|!=)\s*(?:null|true|false))?\s*\?\s*[0-9]{1,9}\s*:\s*)+[0-9]{1,9}', expression.strip()):
            values.update(int(v) for v in re.findall(r'[?:]\s*([0-9]+)', expression))
        else:
            raise AuditError('Locator no longer identifies literal version(s); review the source, not the ceiling')
    if not values:
        raise AuditError('Version marker missing; review renamed/dynamic source before proceeding')
    return sorted(values)


def audit_contracts(rules: list[dict], before: Callable[[str], str | None], after: Callable[[str], str | None]) -> list[dict]:
    validate_rules(rules)
    by_id = {r['id']: r for r in rules}
    rows: dict[str, dict] = {}
    visiting: set[str] = set()

    def evaluate(name: str) -> dict:
        if name in rows:
            return rows[name]
        if name in visiting:
            raise AuditError('Cyclic contract relationship')
        visiting.add(name)
        rule = by_id[name]
        relation = rule.get('same_as') or rule.get('reader_for')
        parent = evaluate(relation) if relation else None
        row = {'id': name, 'path': rule['path'], 'released': None, 'current': None, 'allowed': [], 'status': 'error', 'detail': ''}
        try:
            old_source = before(rule.get('baseline_path', rule['path']))
            old_pattern = rule.get('baseline_pattern', rule['pattern'])
            if rule.get('baseline_absent'):
                if old_source is not None and list(re.finditer(old_pattern, without_comments(old_source), re.MULTILINE)):
                    raise AuditError('Contract asserted unreleased, but baseline contains its marker')
                old = None
            else:
                released_shared = None
                if 'baseline_shared_symbol' in rule:
                    if not parent['released']:
                        raise AuditError('Referenced contract has no published version')
                    released_shared = (rule['baseline_shared_symbol'], parent['released'])
                old = versions(old_source, old_pattern, rule.get('literal_ternary', False), released_shared)
            shared = None
            if 'shared_symbol' in rule:
                if not parent['current']:
                    raise AuditError('Referenced contract has incomplete evidence')
                shared = (rule['shared_symbol'], parent['current'])
            new_source = after(rule['path'])
            for path in rule.get('additional_paths', []):
                source = after(path)
                if new_source is None or source is None:
                    raise AuditError('Candidate contract source is missing')
                new_source += '\n' + source
            new = versions(new_source, rule['pattern'], rule.get('literal_ternary', False), shared)
            row.update(released=old, current=new)
            if new is None:
                raise AuditError('Candidate contract is missing; removal needs an explicit review')
            if parent:
                if parent['status'] == 'error':
                    raise AuditError('Referenced contract has incomplete evidence')
                if rule.get('same_as'):
                    allowed = parent['current']
                    ok = new == allowed and parent['status'] == 'ok'
                    detail = f"Shares {relation}; this is not a separate protocol version"
                else:
                    allowed = sorted(set(old or []) | set(parent['current'] or []))
                    ok = set(new) == set(allowed) and parent['status'] == 'ok'
                    detail = f"Keep released reader versions and the single final {relation} shape"
            else:
                if old is not None and len(old) != 1:
                    raise AuditError('Baseline writer has multiple versions; classify separately')
                allowed = [1] if old is None else [old[0], old[0] + 1]
                ok = len(new) == 1 and new[0] in allowed
                detail = 'New independent contract starts at 1' if old is None else 'At most one final schema increment since the published baseline'
            row.update(allowed=allowed, status='ok' if ok else 'violation', detail=detail)
        except AuditError as error:
            row['detail'] = str(error)
        visiting.remove(name)
        rows[name] = row
        return row

    return [evaluate(r['id']) for r in rules]


class GitTree:
    def __init__(self, repo: Path, revision: str):
        self.repo = repo
        if not revision or revision.startswith('-') or any(ord(c) < 32 for c in revision):
            raise AuditError('Invalid Git revision')
        self.commit = self.git('rev-parse', '--verify', '--end-of-options', revision + '^{commit}').decode().strip()
        if not re.fullmatch(r'[a-f0-9]{40,64}', self.commit):
            raise AuditError('Revision did not resolve to a commit')
        self.cache: dict[str, str | None] = {}

    def git(self, *args: str) -> bytes:
        try:
            result = subprocess.run(['git', '-C', str(self.repo), *args], capture_output=True, timeout=30, check=True)
        except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
            raise AuditError(f'Git read failed ({args[0]}); fetch the baseline and candidate refs') from error
        return result.stdout

    def read(self, path: str) -> str | None:
        valid_path(path)
        if path in self.cache:
            return self.cache[path]
        listing = self.git('ls-tree', '-z', self.commit, '--', path)
        if not listing:
            self.cache[path] = None
            return None
        records = listing.rstrip(b'\0').split(b'\0')
        if len(records) != 1:
            raise AuditError(f'Ambiguous Git path: {path}')
        metadata, found = records[0].split(b'\t', 1)
        mode, kind, sha = metadata.split()
        if found.decode() != path or mode not in (b'100644', b'100755') or kind != b'blob':
            raise AuditError(f'Not a regular source blob: {path}')
        size = int(self.git('cat-file', '-s', sha.decode()))
        if size > MAX_SOURCE_BYTES:
            raise AuditError(f'Source exceeds audit size bound: {path}')
        try:
            text = self.git('cat-file', 'blob', sha.decode()).decode('utf-8')
        except UnicodeDecodeError as error:
            raise AuditError(f'Non-UTF-8 source: {path}') from error
        self.cache[path] = text
        return text


def inventory(before: GitTree, after: GitTree, rules: list[dict]) -> list[dict]:
    """Supplementary review queue; not a promise to parse every persistence API."""
    registered = {path for rule in rules for path in [rule['path'], *rule.get('additional_paths', [])]}
    rows = []
    changed = after.git('diff', '--name-only', '-z', before.commit, after.commit, '--', *SOURCE_ROOTS)
    for path in sorted(p.decode() for p in changed.split(b'\0') if p):
        if not path.endswith(('.dart', '.kt', '.java')) or path.endswith(('.g.dart', '.freezed.dart')):
            continue
        old, new = before.read(path), after.read(path)
        if old == new:
            continue
        old_lines = [] if old is None else [line.strip() for line in without_comments(old).splitlines() if VERSION_MARKER.search(line)]
        new_lines = [] if new is None else [line.strip() for line in without_comments(new).splitlines() if VERSION_MARKER.search(line)]
        if old_lines != new_lines:
            rows.append({'path': path, 'registered_path': path in registered, 'released_markers': old_lines, 'candidate_markers': new_lines})
    return rows


def no_duplicates(pairs: list[tuple]) -> dict:
    result = {}
    for key, value in pairs:
        if key in result:
            raise AuditError(f'Duplicate JSON key: {key}')
        result[key] = value
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, default=Path.cwd())
    parser.add_argument('--contracts', type=Path, default=Path(__file__).with_name('schema_contracts.json'))
    parser.add_argument('--baseline', required=True, help='Actual published tag/resolved commit; never pubspec version')
    parser.add_argument('--candidate', default='HEAD', help='Committed candidate; dirty files intentionally excluded')
    parser.add_argument('--inventory', action='store_true', help='Also list changed version-bearing app source for manual review')
    parser.add_argument('--json', action='store_true')
    args = parser.parse_args(argv)
    try:
        if args.contracts.stat().st_size > 1024 * 1024:
            raise AuditError('Contract catalog exceeds size bound')
        data = json.loads(args.contracts.read_text(encoding='utf-8'), object_pairs_hook=no_duplicates)
        rules = validate_rules(data['contracts'])
        before, after = GitTree(args.repo, args.baseline), GitTree(args.repo, args.candidate)
        if data.get('baseline_commit') != before.commit:
            raise AuditError('Catalog baseline differs from the published commit; refresh evidence and locators, not just version ceilings')
        rows = audit_contracts(rules, before.read, after.read)
        result = {'baseline': before.commit, 'candidate': after.commit, 'scope': 'registered source markers; not a semantic or migration proof', 'contracts': rows}
        if args.inventory:
            result['review_candidates'] = inventory(before, after, rules)
        if args.json:
            print(json.dumps(result, indent=2, ensure_ascii=True))
        else:
            print(f'Published: {before.commit}\nCandidate: {after.commit}')
            for row in rows:
                print(f"{row['status'].upper():9} {row['id']}: {row['released']} -> {row['current']}; allowed {row['allowed']}; {row['detail']}")
            print('Numeric source check only; perform released-data migration/import/reopen tests separately.')
            if args.inventory:
                for entry in result['review_candidates']:
                    print('REVIEW ' + entry['path'] + (' (registered path; review other markers)' if entry['registered_path'] else ' (unregistered path)'))
        return 2 if any(r['status'] == 'error' for r in rows) else int(any(r['status'] == 'violation' for r in rows))
    except (AuditError, OSError, KeyError, TypeError, UnicodeError, json.JSONDecodeError, RecursionError) as error:
        print(f'Schema audit incomplete: {error}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
