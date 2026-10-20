#!/usr/bin/env python3
"""Pack/unpack editable, credential-free .bsexport scenarios (standard library only)."""
from __future__ import annotations

import argparse
from copy import deepcopy
from datetime import datetime
import hashlib
import json
from pathlib import Path
import re
import shutil
import stat
import sys
import tempfile
import zipfile

MAX_BYTES = 64 * 1024 * 1024
MAX_FILES = 512
SECRET_KEYS = {
    'apikey', 'password', 'passhash', 'accesstoken', 'refreshtoken',
    'authorization', 'cookie', 'cookies', 'clientsecret', 'proxypassword',
}


def safe_path(value: object) -> str:
    if not isinstance(value, str) or not value or '\\' in value or ':' in value or '\x00' in value:
        raise ValueError('Invalid export part path')
    if any(p in ('', '.', '..') for p in value.split('/')):
        raise ValueError('Export part paths must be relative without traversal')
    return value


def reject_credentials(value: object) -> None:
    """A conservative check, not a substitute for reviewing an export before commit."""
    if isinstance(value, dict):
        for key, child in value.items():
            normalized = re.sub(r'[^a-z]', '', key.lower())
            if normalized in SECRET_KEYS and child not in (None, '', [], {}):
                raise ValueError('Scenario contains a nonempty credential field')
            reject_credentials(child)
    elif isinstance(value, list):
        for child in value:
            reject_credentials(child)


def manifest_parts(manifest: object) -> list[dict]:
    if not isinstance(manifest, dict):
        raise ValueError('Manifest must be an object')
    if (manifest.get('format') != 'boorusama-export'
            or type(manifest.get('formatVersion')) is not int
            or manifest['formatVersion'] != 1):
        raise ValueError('Only boorusama-export formatVersion 1 is supported')
    if manifest.get('containsCredentials') is not False:
        raise ValueError('Use an explicitly credential-free export for this MVP')
    if any(not isinstance(manifest.get(k), str) or not manifest[k]
           for k in ('appVersion', 'exportId', 'createdAt')):
        raise ValueError('Manifest requires appVersion, exportId and createdAt strings')
    try:
        datetime.fromisoformat(manifest['createdAt'].replace('Z', '+00:00'))
    except ValueError:
        raise ValueError('Manifest createdAt must be an ISO date') from None
    reject_credentials(manifest)
    sources = manifest.get('sources')
    if not isinstance(sources, list) or not sources:
        raise ValueError('Manifest requires at least one source')
    ids, paths, parts = set(), set(), []
    for source in sources:
        if not isinstance(source, dict):
            raise ValueError('Invalid source')
        source_id = source.get('id')
        version = source.get('schemaVersion')
        if not isinstance(source_id, str) or not source_id or source_id in ids:
            raise ValueError('Invalid or repeated source ID')
        ids.add(source_id)
        if type(version) is not int or version < 1:
            raise ValueError('Invalid source schemaVersion')
        source_parts = source.get('parts')
        if not isinstance(source_parts, list) or not source_parts:
            raise ValueError('Each source needs at least one part')
        for part in source_parts:
            if not isinstance(part, dict):
                raise ValueError('Invalid part')
            path = safe_path(part.get('path'))
            if path == 'manifest.json' or path in paths:
                raise ValueError('Reserved or repeated part path')
            paths.add(path)
            parts.append(part)
    if len(parts) + 1 > MAX_FILES:
        raise ValueError('Too many export parts for the MVP')
    return parts


def check_json(path: str, data: bytes) -> None:
    if path.endswith('.json'):
        reject_credentials(json.loads(data))


def encode_manifest(manifest: dict) -> bytes:
    return (json.dumps(manifest, indent=2, ensure_ascii=False) + '\n').encode('utf-8')


def pack(directory: Path, output: Path) -> None:
    """Preserve source schemas; regenerate only part digests and lengths."""
    directory, output = Path(directory).resolve(), Path(output)
    if output.exists():
        raise FileExistsError(output)
    manifest_path = directory / 'manifest.json'
    if manifest_path.is_symlink() or manifest_path.stat().st_size > MAX_BYTES:
        raise ValueError('Unsafe or oversized manifest')
    manifest = json.loads(manifest_path.read_bytes())
    parts = manifest_parts(manifest)
    payloads = {}
    total = manifest_path.stat().st_size
    for part in parts:
        name = part['path']
        path = directory / name
        if not path.resolve().is_relative_to(directory):
            raise ValueError('Part escapes the scenario directory')
        if any(p.is_symlink() for p in [path, *path.parents] if p != directory):
            raise ValueError('Symlink parts are not supported')
        total += path.stat().st_size
        if total > MAX_BYTES:
            raise ValueError('Scenario exceeds the 64 MiB MVP limit')
        data = path.read_bytes()
        check_json(name, data)
        part['sha256'] = hashlib.sha256(data).hexdigest()
        part['byteLength'] = len(data)
        payloads[name] = data
    payloads['manifest.json'] = encode_manifest(manifest)
    output.parent.mkdir(parents=True, exist_ok=True)
    # Exclusive creation prevents accidentally replacing a manually captured export.
    with output.open('xb') as target:
        try:
            with zipfile.ZipFile(target, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
                for name, data in sorted(payloads.items()):
                    info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
                    info.compress_type = zipfile.ZIP_DEFLATED
                    info.external_attr = 0o100600 << 16
                    archive.writestr(info, data)
        except BaseException:
            output.unlink(missing_ok=True)
            raise


def read_package(package: Path) -> tuple[dict, dict[str, bytes]]:
    """Validate the whole package before extracting or touching the device."""
    with zipfile.ZipFile(package) as archive:
        infos = archive.infolist()
        if len(infos) > MAX_FILES or sum(i.file_size for i in infos) > MAX_BYTES:
            raise ValueError('Export exceeds the MVP size/file limit')
        names = set()
        for info in infos:
            safe_path(info.filename.rstrip('/') if info.is_dir() else info.filename)
            if info.filename in names or stat.S_ISLNK(info.external_attr >> 16):
                raise ValueError('Duplicate member or symlink in export')
            names.add(info.filename)
        manifest = json.loads(archive.read('manifest.json'))
        parts = manifest_parts(manifest)
        expected = {'manifest.json', *(p['path'] for p in parts)}
        if {i.filename for i in infos if not i.is_dir()} != expected:
            raise ValueError('Export has missing or unlisted files')
        payloads = {}
        for part in parts:
            name = part['path']
            data = archive.read(name)
            if len(data) != part.get('byteLength') or hashlib.sha256(data).hexdigest() != part.get('sha256'):
                raise ValueError(f'Export integrity check failed: {name}')
            check_json(name, data)
            payloads[name] = data
    return manifest, payloads


def unpack(package: Path, directory: Path) -> None:
    directory = Path(directory)
    if directory.exists():
        raise FileExistsError(directory)
    manifest, payloads = read_package(package)
    manifest = deepcopy(manifest)
    # Make JSON easy to review/edit, and keep the unpacked manifest consistent.
    for part in manifest_parts(manifest):
        name = part['path']
        data = payloads[name]
        if name.endswith('.json'):
            data = (json.dumps(json.loads(data), indent=2, ensure_ascii=False) + '\n').encode('utf-8')
        payloads[name] = data
        part['sha256'] = hashlib.sha256(data).hexdigest()
        part['byteLength'] = len(data)
    directory.parent.mkdir(parents=True, exist_ok=True)
    temporary = Path(tempfile.mkdtemp(prefix='.ui-export-', dir=directory.parent))
    try:
        for name, data in {**payloads, 'manifest.json': encode_manifest(manifest)}.items():
            target = temporary / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        if directory.exists():
            raise FileExistsError(directory)
        temporary.rename(directory)
    finally:
        if temporary.exists():
            shutil.rmtree(temporary)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    for command in ('pack', 'unpack'):
        child = sub.add_parser(command)
        child.add_argument('source', type=Path)
        child.add_argument('destination', type=Path)
    args = parser.parse_args()
    try:
        {'pack': pack, 'unpack': unpack}[args.command](args.source, args.destination)
    except (OSError, ValueError, KeyError, TypeError, RuntimeError, zipfile.BadZipFile) as error:
        # Do not echo arbitrary malformed JSON or credential-bearing values.
        print(f'Export operation failed ({type(error).__name__}). Check format, paths, size and credentials.', file=sys.stderr)
        return 1
    print(args.destination)
    return 0


if __name__ == '__main__':
    sys.exit(main())
