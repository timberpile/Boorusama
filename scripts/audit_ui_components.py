#!/usr/bin/env python3
"""Inventory Kurumi and Flutter Material UI calls without modifying app code.

This is a *lexical* audit, not a Dart analyzer. It reports candidates for human
review and does not infer that use of a Material widget is an inconsistency.
"""

from __future__ import annotations

import argparse
from bisect import bisect_right
from collections import Counter, defaultdict
import json
from pathlib import Path
import re
import subprocess


MATERIAL_CONSTRUCTORS = frozenset(
    {
        "ActionChip", "AlertDialog", "AppBar", "BottomNavigationBar",
        "BottomSheet", "Card", "Checkbox", "CheckboxListTile", "Chip",
        "ChoiceChip", "Dialog", "DropdownButton", "DropdownButtonFormField",
        "DropdownMenu", "ElevatedButton", "FilledButton", "FilterChip",
        "FloatingActionButton", "IconButton", "ListTile", "MenuAnchor",
        "NavigationBar", "NavigationRail", "OutlinedButton", "PopupMenuButton",
        "PopupMenuItem", "Radio", "RadioListTile", "Scaffold",
        "SegmentedButton", "SimpleDialog", "Slider", "SnackBar",
        "Switch", "SwitchListTile", "TextButton", "TextField", "TextFormField",
    }
)

MATERIAL_REVIEW = frozenset(
    {
        "AlertDialog", "DropdownButton", "DropdownButtonFormField",
        "DropdownMenu", "PopupMenuButton", "PopupMenuItem", "TextField",
        "TextFormField", "SwitchListTile", "CheckboxListTile",
    }
)

# Keep constructor detection intentionally conservative: avoid matching Dart
# declarations, property references, variable types, and arbitrary method calls.
CONSTRUCTOR_RE = re.compile(
    r"\b(?P<name>Kurumi[A-Z]\w*|" + "|".join(sorted(MATERIAL_CONSTRUCTORS)) + r")"
    r"\s*(?:<[^();\n]{1,120}>)?\s*\("
)
KURUMI_HELPER_RE = re.compile(r"\bKurumi\.(?P<method>[a-zA-Z_]\w*)\s*\(")
DEF_RE = re.compile(
    r"\b(?:class|mixin|enum|extension\s+type|typedef)\s+(?P<name>Kurumi[A-Z]\w*)\b"
)
APP_SHARED_DEF_RE = re.compile(
    r"\b(?:class|mixin|enum)\s+(?P<name>[A-Z]\w*)\b"
)
TOKEN_PATTERNS = {
    "corner radius": re.compile(r"\b(?:BorderRadius\.circular|Radius\.circular)\s*\(\s*\d"),
    "text size": re.compile(r"\bfontSize\s*:\s*\d"),
    "padding": re.compile(r"\bEdgeInsets\.(?:all|only|symmetric|fromLTRB)\s*\("),
    "literal color": re.compile(r"\bColor\s*\(\s*0x[0-9a-fA-F]+\s*\)"),
}

AREA_PREFIXES = (
    ("lib/core/home/", "Home"),
    ("lib/core/navigation/", "Navigation"),
    ("lib/core/search/search/", "Search"),
    ("lib/core/search/following_topics/", "Following Topics"),
    ("lib/core/posts/listing/", "Post grids"),
    ("lib/core/posts/details/", "Post viewer"),
    ("lib/core/bookmarks/", "Bookmarks"),
    ("lib/core/settings/", "Settings"),
    ("lib/core/download_manager/", "Download Manager"),
    ("lib/core/downloads/", "Downloads"),
    ("lib/core/configs/", "Profiles and configuration"),
    ("lib/core/themes/", "Theming"),
    ("lib/boorus/danbooru/artists/", "Danbooru artists"),
    ("lib/boorus/danbooru/posts/details/", "Danbooru details"),
    ("lib/boorus/", "Other engine-specific UI"),
    ("lib/core/", "Other core UI"),
    ("packages/kurumi/", "Kurumi package"),
    ("packages/", "Other packages"),
)


def area_of(path: str) -> str:
    for prefix, name in AREA_PREFIXES:
        if path.startswith(prefix):
            return name
    return "Other"


def mask_dart_trivia(source: str) -> str:
    """Mask comments and string literals, preserving character and line offsets.

    Dart supports nested /* comments */ and raw/triple quoted strings. String
    interpolation expressions are masked too: false negatives are possible.
    """
    out = list(source)
    length = len(source)

    def mask(start: int, end: int) -> None:
        for k in range(start, end):
            if source[k] not in "\r\n":
                out[k] = " "

    i = 0
    while i < length:
        if source.startswith("//", i):
            end = source.find("\n", i + 2)
            end = length if end == -1 else end
            mask(i, end)
            i = end
            continue
        if source.startswith("/*", i):
            start = i
            i += 2
            depth = 1
            while i < length and depth:
                if source.startswith("/*", i):
                    depth += 1
                    i += 2
                elif source.startswith("*/", i):
                    depth -= 1
                    i += 2
                else:
                    i += 1
            mask(start, i)
            continue
        raw = (
            source[i] in "rR"
            and i + 1 < length
            and source[i + 1] in "\"'"
            and (i == 0 or not (source[i - 1].isalnum() or source[i - 1] == "_"))
        )
        quote_index = i + 1 if raw else i
        if quote_index < length and source[quote_index] in "\"'":
            start = i
            quote = source[quote_index]
            triple = source.startswith(quote * 3, quote_index)
            delimiter = quote * (3 if triple else 1)
            i = quote_index + len(delimiter)
            while i < length:
                if source.startswith(delimiter, i):
                    i += len(delimiter)
                    break
                if source[i] == "\\" and not raw:
                    i += 2
                else:
                    i += 1
            mask(start, min(i, length))
            continue
        i += 1
    return "".join(out)


def dart_sources(root: Path):
    roots = [root / "lib"]
    package_root = root / "packages"
    if package_root.is_dir():
        roots.extend(sorted(package_root.glob("*/lib")))
    seen: set[Path] = set()
    for source_root in roots:
        if not source_root.is_dir():
            continue
        for path in sorted(source_root.rglob("*.dart")):
            if path.is_symlink() or path in seen:
                continue
            if path.name.endswith((".g.dart", ".freezed.dart", ".gr.dart", ".gen.dart")):
                continue
            seen.add(path)
            yield path


def scan(root: Path) -> dict:
    records: list[dict] = []
    definitions: list[dict] = []
    usages: list[dict] = []
    token_candidates: list[dict] = []
    read_errors: list[dict] = []
    for path in dart_sources(root):
        relative = path.relative_to(root).as_posix()
        try:
            source = path.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as error:
            read_errors.append({"path": relative, "error": str(error)})
            continue
        clean = mask_dart_trivia(source)
        newlines = [i for i, character in enumerate(source) if character == "\n"]
        line = lambda at: bisect_right(newlines, at) + 1
        local_usages: list[dict] = []
        local_defs: list[dict] = []
        for match in DEF_RE.finditer(clean):
            local_defs.append({
                "symbol": match.group("name"), "path": relative,
                "line": line(match.start()), "area": area_of(relative),
            })
        if relative.startswith("lib/core/widgets/"):
            for match in APP_SHARED_DEF_RE.finditer(clean):
                local_defs.append({
                    "symbol": match.group("name"), "path": relative,
                    "line": line(match.start()), "area": area_of(relative),
                })
        for match in CONSTRUCTOR_RE.finditer(clean):
            symbol = match.group("name")
            local_usages.append({
                "symbol": symbol, "kind": "kurumi" if symbol.startswith("Kurumi") else "material",
                "path": relative, "line": line(match.start()), "area": area_of(relative),
            })
        for match in KURUMI_HELPER_RE.finditer(clean):
            local_usages.append({
                "symbol": "Kurumi." + match.group("method"), "kind": "kurumi-helper",
                "path": relative, "line": line(match.start()), "area": area_of(relative),
            })
        if relative.startswith("packages/kurumi/lib/src/components/"):
            for token_name, pattern in TOKEN_PATTERNS.items():
                for match in pattern.finditer(clean):
                    token_candidates.append({
                        "kind": token_name, "path": relative, "line": line(match.start()),
                    })
        local_counter = Counter((usage["kind"], usage["symbol"]) for usage in local_usages)
        records.append({
            "path": relative, "area": area_of(relative),
            "definitions": sorted(d["symbol"] for d in local_defs),
            "kurumi_calls": sum(n for (k, _), n in local_counter.items() if k != "material"),
            "material_calls": sum(n for (k, _), n in local_counter.items() if k == "material"),
            "material_review_calls": sum(
                n for (k, symbol), n in local_counter.items()
                if k == "material" and symbol in MATERIAL_REVIEW
            ),
            "symbols": {symbol: n for (_, symbol), n in sorted(local_counter.items())},
        })
        definitions.extend(local_defs)
        usages.extend(local_usages)
    source_commit = "unknown"
    try:
        result = subprocess.run(
            ["git", "-C", str(root), "rev-parse", "HEAD"],
            capture_output=True, text=True, check=False, timeout=3,
        )
        if result.returncode == 0:
            source_commit = result.stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        pass
    return {
        "schema_version": 1, "source_revision": source_commit,
        "method": "static lexical approximation; not screenshot or runtime verification",
        "files": records,
        "definitions": sorted(definitions, key=lambda d: (d["symbol"], d["path"], d["line"])),
        "usages": sorted(usages, key=lambda d: (d["symbol"], d["path"], d["line"])),
        "token_candidates": sorted(token_candidates, key=lambda d: (d["path"], d["line"])),
        "read_errors": read_errors,
    }


def markdown_report(result: dict) -> str:
    files = result["files"]
    usages = result["usages"]
    definitions = result["definitions"]
    app_usages = [u for u in usages if u["path"].startswith("lib/")]
    kurumi_defs = [d for d in definitions if d["path"].startswith("packages/kurumi/")]
    app_ku = [u for u in app_usages if u["kind"] != "material"]
    app_ma = [u for u in app_usages if u["kind"] == "material"]
    by_symbol = defaultdict(list)
    for usage in app_usages:
        by_symbol[usage["symbol"]].append(usage)
    lines = [
        "# UI component static inventory",
        "",
        f"Source revision: `{result['source_revision']}`.",
        f"Scanned Dart files: **{len(files)}**; Kurumi-package declarations: **{len(kurumi_defs)}**; "
        f"app Kurumi constructor/helper calls: **{len(app_ku)}**; "
        f"app Material constructor candidates: **{len(app_ma)}**.",
        "",
        "This is a source-level inventory, **not proof of rendered visual behavior**. "
        "The counts indicate call sites, not instantiated widget counts. "
        "A Material call is **not automatically a violation**. Generated Dart files are excluded. "
        "Dynamic construction, code generated elsewhere, and strings with interpolation "
        "may not be detected. Review concrete widget trees and screenshots before acting.",
        "",
        "## Kurumi-named declarations defined in package",
        "",
        "| Declaration | Defined at | App call sites | App files |",
        "| --- | --- | ---: | ---: |",
    ]
    for definition in kurumi_defs:
        use = by_symbol.get(definition["symbol"], [])
        distinct = {item["path"] for item in use}
        lines.append(
            f"| `{definition['symbol']}` | `{definition['path']}:{definition['line']}` "
            f"| {len(use)} | {len(distinct)} |"
        )
    lines.extend(["", "## Direct call counts by area", "", "| Area | Dart files | Kurumi calls | Material calls | Review candidates |", "| --- | ---: | ---: | ---: | ---: |"])
    groups = defaultdict(list)
    for record in files:
        if record["path"].startswith("lib/"):
            groups[record["area"]].append(record)
    for area, members in sorted(groups.items(), key=lambda pair: -sum(i["material_review_calls"] for i in pair[1])):
        lines.append(
            f"| {area} | {len(members)} | {sum(m['kurumi_calls'] for m in members)} "
            f"| {sum(m['material_calls'] for m in members)} | {sum(m['material_review_calls'] for m in members)} |"
        )
    lines.extend(["", "## High-value Material usages to inspect", "", "| Material symbol | App calls | First source locations |", "| --- | ---: | --- |"])
    for name in sorted(MATERIAL_REVIEW):
        use = by_symbol.get(name, [])
        if not use:
            continue
        examples = ", ".join(f"`{u['path']}:{u['line']}`" for u in use[:5])
        lines.append(f"| `{name}` | {len(use)} | {examples} |")
    lines.extend([
        "", "## Files worth inspecting first", "",
        "By count of Material menu, dialog, and input candidates; counts are triage signals only.", "",
        "| File | Review candidates | Kurumi calls |", "| --- | ---: | ---: |",
    ])
    for record in sorted(
        (r for r in files if r["path"].startswith("lib/") and r["material_review_calls"]),
        key=lambda r: (-r["material_review_calls"], r["path"]),
    )[:45]:
        lines.append(f"| `{record['path']}` | {record['material_review_calls']} | {record['kurumi_calls']} |")
    lines.extend([
        "", "## Token centralization candidates in Kurumi", "",
        "Counts are evidence of numeric or color literals, **not** automatically bad styles.",
        "", "| Pattern | Matches | Example locations |", "| --- | ---: | --- |",
    ])
    tokens = defaultdict(list)
    for item in result["token_candidates"]:
        tokens[item["kind"]].append(item)
    for name, items in sorted(tokens.items()):
        examples = ", ".join(f"`{x['path']}:{x['line']}`" for x in items[:5])
        lines.append(f"| {name} | {len(items)} | {examples} |")
    if result["read_errors"]:
        lines.extend(["", "## Read errors", ""])
        lines.extend(f"- `{x['path']}`: {x['error']}" for x in result["read_errors"])
    lines.extend([
        "", "## Verification before refactoring", "",
        "For each candidate, inspect its complete widget tree and purpose, compare the same "
        "interaction on other screens, capture a real device screenshot, and test keyboard, "
        "touch, accessibility text scale, and responsive layout. Existing Material usage "
        "may be intentional. Preserve profile/engine-specific behavior.", "",
    ])
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd(), help="Repository root")
    parser.add_argument(
        "--output-dir", type=Path, default=Path(".worktrees/_artifacts/ui-component-audit"),
        help="Report destination (relative to root unless absolute)",
    )
    args = parser.parse_args()
    root = args.root.resolve()
    if not (root / "lib").is_dir() or not (root / "packages" / "kurumi" / "lib").is_dir():
        parser.error("Expected a Boorusama root containing lib/ and packages/kurumi/lib/")
    destination = args.output_dir
    if not destination.is_absolute():
        destination = root / destination
    destination.mkdir(parents=True, exist_ok=True)
    result = scan(root)
    (destination / "ui_component_inventory.json").write_text(
        json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    (destination / "ui_component_inventory.md").write_text(
        markdown_report(result), encoding="utf-8"
    )
    print(f"Scanned {len(result['files'])} Dart files; reports: {destination}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
