#!/usr/bin/env python3
"""Apply diagnostics to a clean, isolated task worktree based on f4972eb.

No network access, branch creation, commits or pushes. All transformations are
validated before writing. --check previews changes without modifying the tree.
"""
from __future__ import annotations
import argparse
import difflib
import json
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent

def matching(text: str, start: int) -> int:
    """Match Dart ()/{} including quoted/raw/triple strings and nested comments."""
    pairs = {'(': ')', '{': '}', '[': ']'}
    stack = [pairs[text[start]]]
    i = start + 1
    while i < len(text):
        if text.startswith('//', i):
            end = text.find('\n', i)
            i = len(text) if end < 0 else end + 1
            continue
        if text.startswith('/*', i):
            level = 1
            i += 2
            while i < len(text) and level:
                if text.startswith('/*', i): level += 1; i += 2
                elif text.startswith('*/', i): level -= 1; i += 2
                else: i += 1
            continue
        if text[i] in "\"'":
            quote = text[i]
            raw = i > 0 and text[i - 1] == 'r' and (i < 2 or not text[i - 2].isalnum())
            delim = quote * 3 if text.startswith(quote * 3, i) else quote
            i += len(delim)
            while i < len(text):
                if not raw and text[i] == '\\': i += 2
                elif text.startswith(delim, i): i += len(delim); break
                else: i += 1
            continue
        char = text[i]
        if char in pairs: stack.append(pairs[char])
        elif char in ')}]':
            if not stack or stack.pop() != char:
                raise ValueError(f'Unbalanced Dart delimiter at offset {i}')
            if not stack: return i
        i += 1
    raise ValueError('Unterminated Dart expression')

def transform(text: str, operations: list[dict]) -> str:
    imports = []
    for op in operations:
        kind = op['kind']
        if kind == 'import':
            line = f"import '{op['library']}';"
            if line not in text and line not in imports: imports.append(line)
        elif kind == 'replace':
            count = text.count(op['old'])
            if count != 1:
                raise ValueError(f"Expected one source anchor, found {count}: {op['old'][:100]!r}")
            text = text.replace(op['old'], op['new'], 1)
        elif kind == 'body':
            if text.count(op['anchor']) != 1:
                raise ValueError(f"Method anchor is missing or ambiguous: {op['anchor']}")
            start = text.index(op['anchor']) + len(op['anchor']) - 1
            end = matching(text, start)
            original = text[start + 1:end]
            indent = op['anchor'][:len(op['anchor']) - len(op['anchor'].lstrip())]
            inner = indent + '  '
            items = '' if not op.get('items') else f", items: {op['items']}"
            instrument = (
                '\n' + inner + 'final performanceSpan = performanceRecorder.begin(\n' +
                inner + f"  PerfOperation.{op['operation']}, PerfSpanKind.{op['span_kind']}{items},\n" +
                inner + ');\n' + inner + 'var performanceFailed = false;\n' + inner + 'try {\n' +
                '\n'.join('  ' + line if line.strip() else '' for line in original.strip('\n').rstrip().splitlines()) +
                '\n' + inner + '} catch (_) {\n' + inner + '  performanceFailed = true;\n' +
                inner + '  rethrow;\n' + inner + '} finally {\n' +
                inner + '  performanceSpan.finish(failed: performanceFailed);\n' + inner + '}\n' + indent
            )
            text = text[:start + 1] + instrument + text[end:]
        elif kind == 'expression':
            after = text.index(op['after']) if op.get('after') else 0
            location = text.index(op['target'], after)
            start = location + op['expression_offset']
            opening = text.index('(', start)
            end = matching(text, opening) + 1
            text = text[:start] + op['prefix'] + text[start:end] + op['suffix'] + text[end:]
        elif kind == 'locale':
            parsed = json.loads(text)
            if 'performance_diagnostics' in parsed:
                raise ValueError('Performance translations already exist')
            if not text.startswith('{\n'):
                raise ValueError('Unexpected locale formatting')
            field = json.dumps({'performance_diagnostics': op['data']}, ensure_ascii=False, indent=2)[2:-2]
            text = '{\n' + field + ',\n' + text[2:]
            json.loads(text)  # Validate without rewriting existing translations.
        else:
            raise ValueError(f'Unknown integration operation: {kind}')
    return ('\n'.join(imports) + '\n\n' if imports else '') + text

def git(root: Path, *args: str) -> str:
    return subprocess.check_output(['git', '-C', str(root), *args], text=True).strip()

def validate_base_inputs(root: Path, manifest: dict) -> None:
    """Allow preparation commits, never silently accept changed app inputs."""
    base = manifest['base_commit']
    subprocess.run(
        ['git', '-C', str(root), 'merge-base', '--is-ancestor', base, 'HEAD'],
        check=True,
    )
    for relative in manifest['edits']:
        path = Path(relative)
        if path.is_absolute() or '..' in path.parts or '\\' in relative:
            raise ValueError(f'Unsafe repository path: {relative}')
        original = git(root, 'rev-parse', f'{base}:{relative}')
        current = git(root, 'rev-parse', f'HEAD:{relative}')
        if original != current:
            raise ValueError(
                f'Instrumentation input changed since {base[:7]}: {relative}. '
                'Port the change explicitly; do not disable this check.'
            )

def prepare(root: Path, manifest: dict) -> dict[str, tuple[bytes | None, bytes]]:
    result = {}
    for relative, operations in manifest['edits'].items():
        target = root / relative
        if target.is_symlink() or not target.is_file() or not target.resolve().is_relative_to(root.resolve()):
            raise ValueError(f'Expected a regular repository file: {relative}')
        before = target.read_bytes()
        after = transform(before.decode('utf-8'), operations).encode('utf-8')
        result[relative] = (before, after)
    for source in sorted((HERE / 'files').rglob('*')):
        if not source.is_file() or '__pycache__' in source.parts or source.suffix == '.pyc': continue
        relative = source.relative_to(HERE / 'files').as_posix()
        target = root / relative
        if target.exists() or target.is_symlink():
            raise ValueError(f'Refusing to overwrite new-file destination: {relative}')
        if not target.resolve().is_relative_to(root.resolve()):
            raise ValueError('Destination escapes repository')
        result[relative] = (None, source.read_bytes())
    return result

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('worktree', type=Path)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--patch-output', type=Path, help='Write a standard unified diff; do not apply')
    args = parser.parse_args()
    root = args.worktree.resolve()
    manifest = json.loads((HERE / 'integration.json').read_text())
    try:
        if git(root, 'rev-parse', '--show-toplevel') != str(root):
            raise ValueError('Pass the root of the task worktree')
        validate_base_inputs(root, manifest)
        branch = git(root, 'branch', '--show-current')
        if branch in {'', 'develop', 'master', 'main'}:
            raise ValueError('Use a dedicated task branch, not a shared or detached checkout')
        worktrees = git(root, 'worktree', 'list', '--porcelain').splitlines()
        primary = next((line[9:] for line in worktrees if line.startswith('worktree ')), '')
        if Path(primary).resolve() == root:
            raise ValueError('Use an isolated linked worktree, not the primary checkout')
        if git(root, 'status', '--porcelain'):
            raise ValueError('Task worktree must be clean')
        changes = prepare(root, manifest)
        if args.patch_output:
            patch = ''.join(''.join(difflib.unified_diff(
                (before or b'').decode().splitlines(keepends=True),
                after.decode().splitlines(keepends=True),
                fromfile=f'a/{name}' if before is not None else '/dev/null',
                tofile=f'b/{name}',
            )) for name, (before, after) in changes.items())
            args.patch_output.write_text(patch)
            print(f'Wrote {args.patch_output}; no repository files changed.')
            return 0
        if args.check:
            print(f'Validated all anchors and {len(changes)} file changes; no files changed.')
            return 0
        written = []
        try:
            for name, (before, after) in changes.items():
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                written.append((target, before))
                target.write_bytes(after)
        except BaseException:
            for target, before in reversed(written):
                if before is None: target.unlink(missing_ok=True)
                else: target.write_bytes(before)
            raise
        print(f'Applied {len(changes)} file changes to {branch}. No commit or push was made.')
        print('Next: run dependency resolution, ./gen.sh, formatting, analysis and the complete local suite described in docs/performance_diagnostics.md.')
        return 0
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f'Not applied: {error}', file=sys.stderr)
        return 1

if __name__ == '__main__':
    raise SystemExit(main())
