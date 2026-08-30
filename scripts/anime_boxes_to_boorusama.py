#!/usr/bin/env python3
"""Convert an Anime Boxes CSV export into a BooruSama bookmark backup."""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse


DEFAULT_BOORU_IDS = {
    'danbooru.donmai.us': 20,
    'donmai.moe': 20,
    'gelbooru.com': 21,
    'konachan.com': 24,
    'realbooru.com': 23,
    'rule34.xxx': 23,
}

META_DATE_INDEX = 4
SERVER_ID_INDEX = 1
SERVER_URL_INDEX = 2

FAVORITE_SERVER_ID_INDEX = 0
FAVORITE_POST_ID_INDEX = 1
FAVORITE_SOURCE_URL_INDEX = 2
FAVORITE_SAMPLE_URL_INDEX = 5
FAVORITE_THUMBNAIL_URL_INDEX = 8
FAVORITE_WIDTH_INDEX = 9
FAVORITE_HEIGHT_INDEX = 10
FAVORITE_ORIGINAL_URL_INDEX = 11
FAVORITE_TAGS_START_INDEX = 15
FAVORITE_TAGS_END_INDEX = 18
FAVORITE_MD5_INDEX = 18
FAVORITE_REAL_SOURCE_URL_INDEX = 19

TIMESTAMP_FORMATS = (
    '%m/%d/%y %H:%M',
    '%Y-%m-%d %H:%M:%S',
)


class ConversionError(ValueError):
    """Raised when the CSV cannot be converted safely."""


def convert_csv(
    input_path: Path,
    *,
    group_name: str,
    booru_id_map: dict[str, int] | None = None,
) -> dict[str, object]:
    """Convert an Anime Boxes export into a BooruSama backup payload."""
    group_name = group_name.strip()
    if not group_name:
        raise ConversionError('The group name cannot be empty.')

    meta_date, server_hosts, favorite_rows = _read_export(input_path)
    custom_booru_ids = booru_id_map or {}
    export_date = _parse_timestamp(meta_date) or datetime.now(timezone.utc)
    bookmarks = []
    seen_bookmarks = set()

    for row_number, row in favorite_rows:
        bookmark = _convert_favorite(
            row,
            row_number=row_number,
            server_hosts=server_hosts,
            booru_id_map=custom_booru_ids,
            fallback_date=export_date,
            bookmark_id=len(bookmarks) + 1,
        )
        unique_id = (bookmark['booruId'], bookmark['originalUrl'])
        if unique_id in seen_bookmarks:
            continue
        seen_bookmarks.add(unique_id)
        bookmarks.append(bookmark)

    return {
        'version': 1,
        'date': _format_timestamp(export_date),
        'data': bookmarks,
        'groups': [
            {
                'name': group_name,
                'bookmarkIds': [bookmark['id'] for bookmark in bookmarks],
            },
        ],
    }


def write_json(output_path: Path, payload: dict[str, object]) -> None:
    """Write a formatted UTF-8 JSON backup."""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open('w', encoding='utf-8', newline='\n') as file:
        json.dump(payload, file, ensure_ascii=False, indent=2)
        file.write('\n')


def parse_booru_id_mappings(values: list[str]) -> dict[str, int]:
    mappings = {}
    for value in values:
        host, separator, raw_id = value.partition('=')
        if not separator or not host.strip() or not raw_id.strip():
            raise ConversionError(
                f'Invalid --booru-id-map value {value!r}; expected HOST=ID.'
            )
        try:
            booru_id = int(raw_id)
        except ValueError as error:
            raise ConversionError(
                f'Invalid BooruSama ID in --booru-id-map value {value!r}.'
            ) from error
        if booru_id <= 0:
            raise ConversionError('BooruSama IDs must be positive integers.')
        mappings[_normalize_host(host)] = booru_id
    return mappings


def main(arguments: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            'Convert Anime Boxes favorites into a BooruSama bookmark backup.'
        ),
    )
    parser.add_argument('input', type=Path, help='Anime Boxes CSV export')
    parser.add_argument('output', type=Path, help='BooruSama JSON output')
    parser.add_argument(
        '--group-name',
        required=True,
        help='Name of the BooruSama bookmark group to create',
    )
    parser.add_argument(
        '--booru-id-map',
        action='append',
        default=[],
        metavar='HOST=ID',
        help=(
            'Map an unknown server hostname to a BooruSama ID. Repeat for '
            'multiple hosts.'
        ),
    )
    args = parser.parse_args(arguments)

    try:
        payload = convert_csv(
            args.input,
            group_name=args.group_name,
            booru_id_map=parse_booru_id_mappings(args.booru_id_map),
        )
        write_json(args.output, payload)
    except (ConversionError, OSError, csv.Error) as error:
        print(f'error: {error}', file=sys.stderr)
        return 2

    print(
        f"Wrote {len(payload['data'])} bookmarks to {args.output} "
        f"in group {args.group_name!r}.",
        file=sys.stderr,
    )
    return 0


def _read_export(
    input_path: Path,
) -> tuple[str | None, dict[str, str], list[tuple[int, list[str]]]]:
    section = None
    meta_date = None
    server_hosts = {}
    favorite_rows = []

    with input_path.open('r', encoding='utf-8-sig', newline='') as file:
        reader = csv.reader(file)
        for row_number, row in enumerate(reader, start=1):
            if not row or not any(cell.strip() for cell in row):
                continue

            marker = row[0].strip()
            if marker.startswith('#'):
                section = marker.removeprefix('#').strip().lower()
                continue

            if section == 'meta':
                meta_date = _field(row, META_DATE_INDEX) or _field(row, -1)
            elif section == 'servers':
                server_id = _field(row, SERVER_ID_INDEX)
                server_url = _field(row, SERVER_URL_INDEX)
                if server_id and server_url:
                    server_hosts[server_id] = server_url
            elif section == 'favorites':
                favorite_rows.append((row_number, row))

    if not favorite_rows:
        raise ConversionError('The export does not contain any favorites.')
    return meta_date, server_hosts, favorite_rows


def _convert_favorite(
    row: list[str],
    *,
    row_number: int,
    server_hosts: dict[str, str],
    booru_id_map: dict[str, int],
    fallback_date: datetime,
    bookmark_id: int,
) -> dict[str, object]:
    if len(row) <= FAVORITE_ORIGINAL_URL_INDEX:
        raise ConversionError(
            f'Favorite row {row_number} has too few columns '
            f'({len(row)}).'
        )

    server_id = _field(row, FAVORITE_SERVER_ID_INDEX)
    source_url = _field(row, FAVORITE_SOURCE_URL_INDEX)
    server_url = server_hosts.get(server_id, '')
    booru_id = _resolve_booru_id(
        source_url=source_url,
        server_url=server_url,
        booru_id_map=booru_id_map,
        row_number=row_number,
    )

    original_url = (
        _field(row, FAVORITE_ORIGINAL_URL_INDEX)
        or _field(row, FAVORITE_SAMPLE_URL_INDEX)
        or _field(row, FAVORITE_THUMBNAIL_URL_INDEX)
    )
    if not original_url:
        raise ConversionError(f'Favorite row {row_number} has no image URL.')

    sample_url = _field(row, FAVORITE_SAMPLE_URL_INDEX) or original_url
    thumbnail_url = _field(row, FAVORITE_THUMBNAIL_URL_INDEX) or sample_url
    width = _number_or_fallback(
        _field(row, FAVORITE_WIDTH_INDEX),
        _field(row, 3),
    )
    height = _number_or_fallback(
        _field(row, FAVORITE_HEIGHT_INDEX),
        _field(row, 4),
    )
    favorite_date = _parse_timestamp(_field(row, -1)) or fallback_date

    return {
        'id': bookmark_id,
        'booruId': booru_id,
        'createdAt': _format_timestamp(favorite_date),
        'updatedAt': _format_timestamp(favorite_date),
        'thumbnailUrl': thumbnail_url,
        'sampleUrl': sample_url,
        'originalUrl': original_url,
        'sourceUrl': source_url or original_url,
        'width': width,
        'height': height,
        'md5': _field(row, FAVORITE_MD5_INDEX),
        'tags': _parse_tags(row[FAVORITE_TAGS_START_INDEX:FAVORITE_TAGS_END_INDEX]),
        'realSourceUrl': _field(row, FAVORITE_REAL_SOURCE_URL_INDEX) or None,
        'format': _file_format(original_url),
        'postId': _integer_or_none(_field(row, FAVORITE_POST_ID_INDEX)),
        'metadata': {},
    }


def _resolve_booru_id(
    *,
    source_url: str,
    server_url: str,
    booru_id_map: dict[str, int],
    row_number: int,
) -> int:
    hosts = [_normalize_host(source_url), _normalize_host(server_url)]
    for host in hosts:
        if not host:
            continue
        if host in booru_id_map:
            return booru_id_map[host]
        if host in DEFAULT_BOORU_IDS:
            return DEFAULT_BOORU_IDS[host]

    displayed_host = next((host for host in hosts if host), '<missing host>')
    raise ConversionError(
        f'Favorite row {row_number} uses unsupported host {displayed_host!r}; '
        'provide --booru-id-map HOST=ID.'
    )


def _normalize_host(value: str) -> str:
    value = value.strip()
    if not value:
        return ''
    parsed = urlparse(value if '://' in value else f'https://{value}')
    host = parsed.hostname or value.split('/')[0]
    host = host.lower().rstrip('.')
    return host.removeprefix('www.')


def _parse_tags(values: list[str]) -> list[str]:
    return sorted(
        {
            tag
            for value in values
            for tag in re.split(r'[\s,]+', value.strip())
            if tag
        }
    )


def _parse_timestamp(value: str | None) -> datetime | None:
    if not value:
        return None
    for timestamp_format in TIMESTAMP_FORMATS:
        try:
            return datetime.strptime(value.strip(), timestamp_format)
        except ValueError:
            continue
    try:
        return datetime.fromisoformat(value.strip().replace('Z', '+00:00'))
    except ValueError:
        return None


def _format_timestamp(value: datetime) -> str:
    return value.isoformat(timespec='seconds')


def _field(row: list[str], index: int) -> str:
    try:
        return row[index].strip()
    except IndexError:
        return ''


def _integer_or_none(value: str) -> int | None:
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _number_or_fallback(value: str, fallback: str) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        try:
            return float(fallback)
        except (TypeError, ValueError):
            return 0.0


def _file_format(url: str) -> str | None:
    suffix = Path(urlparse(url).path).suffix.removeprefix('.').lower()
    return suffix or None


if __name__ == '__main__':
    raise SystemExit(main())
