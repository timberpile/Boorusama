#!/usr/bin/env python3
"""Collect artist-tag fixtures and probe Gelbooru's public OR search pages.

Uses only public read endpoints. Requests are sequential, delayed, and stop on
HTTP errors. The Gelbooru DAPI currently requires credentials in this setting,
so its public tag listing and post search pages are used instead.
"""

import argparse
import csv
import json
import re
import sys
import time
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qs, urlencode, urlparse
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DATA_DIR = ROOT / "docs/superpowers/data"
USER_AGENT = "Boorusama artist-tag scaling research (github.com/timberpile/Boorusama)"
GELBOORU = "https://gelbooru.com/index.php"
DANBOORU = "https://danbooru.donmai.us/tags.json"


class TagPageParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.tags = []
        self.in_table = False
        self.in_row = False
        self.in_count = False
        self.row = {}

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        classes = set(attrs.get("class", "").split())
        if tag == "table" and "highlightable" in classes:
            self.in_table = True
        elif self.in_table and tag == "tr":
            self.in_row = True
            self.row = {}
        elif self.in_row and tag == "span":
            if "tag-type-artist" in classes:
                self.row["artist"] = True
            if "tag-count" in classes:
                self.in_count = True
        elif self.in_row and tag == "a" and self.row.get("artist"):
            query = parse_qs(urlparse(attrs.get("href", "")).query)
            if "tags" in query:
                self.row["tag"] = query["tags"][0]

    def handle_data(self, data):
        if self.in_count and data.strip().replace(",", "").isdigit():
            self.row["post_count"] = int(data.strip().replace(",", ""))

    def handle_endtag(self, tag):
        if tag == "span":
            self.in_count = False
        elif tag == "tr" and self.in_row:
            if self.row.get("artist") and self.row.get("tag") and self.row.get("post_count", 0) > 0:
                self.tags.append((self.row["tag"], self.row["post_count"]))
            self.in_row = False
        elif tag == "table" and self.in_table:
            self.in_table = False


class PostPageParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.posts = []
        self.in_article = False
        self.post = {}

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "article" and "thumbnail-preview" in attrs.get("class", "").split():
            self.in_article = True
            self.post = {}
        elif self.in_article and tag == "a" and re.fullmatch(r"p\d+", attrs.get("id", "")):
            self.post["id"] = int(attrs["id"][1:])
        elif self.in_article and tag == "img":
            self.post["tags"] = set(attrs.get("title", "").split())
            self.post["thumbnail_url"] = attrs.get("src", "")

    def handle_endtag(self, tag):
        if tag == "article" and self.in_article:
            if "id" in self.post and "tags" in self.post:
                self.posts.append(self.post)
            self.in_article = False


class Client:
    def __init__(self, delay, timeout):
        self.delay = delay
        self.timeout = timeout
        self.last_request = None

    def get(self, url):
        if self.last_request is not None:
            time.sleep(max(0, self.delay - (time.monotonic() - self.last_request)))
        self.last_request = time.monotonic()
        start = time.monotonic()
        request = Request(url, headers={"User-Agent": USER_AGENT, "Accept": "text/html, application/json"})
        try:
            with urlopen(request, timeout=self.timeout) as response:
                body = response.read()
                return body.decode("utf-8", "replace"), round(time.monotonic() - start, 3)
        except HTTPError as error:
            raise RuntimeError(f"HTTP {error.code} for {url}") from error
        except URLError as error:
            raise RuntimeError(f"Network error for {url}: {error.reason}") from error


def collect_gelbooru(client, count):
    found = {}
    for page in range(100):
        params = {"page": "tags", "s": "list", "order_by": "type", "sort": "asc", "pid": 50 * page}
        body, _ = client.get(f"{GELBOORU}?{urlencode(params)}")
        parser = TagPageParser()
        parser.feed(body)
        if not parser.tags:
            raise RuntimeError(f"No Gelbooru artist tags on listing page {page}")
        for tag, post_count in parser.tags:
            found.setdefault(tag, post_count)
            if len(found) == count:
                return list(found.items())
        print(f"Gelbooru: {len(found)}/{count}", file=sys.stderr)
    raise RuntimeError(f"Found only {len(found)} distinct Gelbooru artist tags")


def collect_danbooru(client, count):
    found = {}
    for page in range(1, 30):
        params = {"search[category]": 1, "search[order]": "count", "limit": 200, "page": page}
        body, _ = client.get(f"{DANBOORU}?{urlencode(params)}")
        records = json.loads(body)
        if not isinstance(records, list) or not records:
            raise RuntimeError(f"No Danbooru tag records on page {page}")
        for record in records:
            if record.get("category") == 1 and record.get("post_count", 0) > 0 and not record.get("is_deprecated"):
                found.setdefault(record["name"], record["post_count"])
                if len(found) == count:
                    return list(found.items())
        print(f"Danbooru: {len(found)}/{count}", file=sys.stderr)
    raise RuntimeError(f"Found only {len(found)} distinct Danbooru artist tags")


def write_tags(path, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(("tag", "post_count"))
        writer.writerows(rows)
    path.with_suffix(".txt").write_text(
        "".join(f"{tag}\n" for tag, _ in rows), encoding="utf-8"
    )


def read_tags(path):
    with path.open(encoding="utf-8", newline="") as stream:
        rows = list(csv.DictReader(stream))
    tags = [row["tag"] for row in rows]
    if len(tags) != len(set(tags)) or len(tags) < 1000:
        raise RuntimeError(f"Expected at least 1000 distinct tags in {path}")
    return rows


def probe(client, rows, sizes):
    # Small and medium artist tags distribute the first page across more
    # operands than a single dominant artist would.
    candidates = [row["tag"] for row in rows if 5 <= int(row["post_count"]) <= 1000]
    if len(candidates) < max(sizes):
        candidates = [row["tag"] for row in rows]
    results = []
    for size in sizes:
        tags = candidates[:size]
        if len(tags) != size:
            raise RuntimeError(f"Only {len(tags)} tags available for a {size}-tag probe")
        query = tags[0] if size == 1 else "{" + " ~ ".join(tags) + "}"
        url = f"{GELBOORU}?{urlencode({'page': 'post', 's': 'list', 'tags': query})}"
        result = {"tag_count": size, "url_length": len(url), "query": query}
        try:
            body, elapsed = client.get(url)
            parser = PostPageParser()
            parser.feed(body)
            tag_indices = {tag: index + 1 for index, tag in enumerate(tags)}
            matched_indices = {
                tag_indices[tag]
                for post in parser.posts
                for tag in post["tags"]
                if tag in tag_indices
            }
            result.update({
                "status": "ok" if parser.posts else "no_visible_posts",
                "seconds": elapsed,
                "visible_posts": len(parser.posts),
                "matching_posts": sum(bool(post["tags"] & set(tags)) for post in parser.posts),
                "distinct_sources_in_first_page": len(matched_indices),
                "highest_source_index_in_first_page": max(matched_indices, default=None),
                "sample_post_ids": [post["id"] for post in parser.posts[:3]],
            })
        except RuntimeError as error:
            result.update({"status": "error", "error": str(error)})
            results.append(result)
            break
        results.append(result)
        print(f"OR {size:4}: {result['status']}, {result['visible_posts']} visible, "
              f"{result['matching_posts']} matched, {elapsed}s", file=sys.stderr)
    return results


def probe_tail_operand(client, rows):
    tags = [row["tag"] for row in rows]
    tail_tag = tags[-1]

    def search(query):
        url = f"{GELBOORU}?{urlencode({'page': 'post', 's': 'list', 'tags': query})}"
        body, elapsed = client.get(url)
        parser = PostPageParser()
        parser.feed(body)
        return parser.posts, elapsed

    tail_posts, _ = search(tail_tag)
    if not tail_posts:
        raise RuntimeError(f"No post found for tail artist {tail_tag}")
    tail_post = tail_posts[0]
    md5_match = re.search(r"thumbnail_([0-9a-f]{32})", tail_post["thumbnail_url"])
    if md5_match is None:
        raise RuntimeError(f"No MD5 found in thumbnail URL for {tail_tag}")
    md5_query = f"md5:{md5_match.group(1)}"
    baseline, baseline_seconds = search(md5_query)
    combined, combined_seconds = search(md5_query + " {" + " ~ ".join(tags) + "}")
    post_id = tail_post["id"]
    return {
        "tail_tag": tail_tag,
        "tail_position": len(tags),
        "post_id": post_id,
        "baseline_found": any(post["id"] == post_id for post in baseline),
        "or_found": any(post["id"] == post_id for post in combined),
        "baseline_seconds": baseline_seconds,
        "or_seconds": combined_seconds,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("collect", "probe", "all"))
    parser.add_argument("--data-dir", type=Path, default=DEFAULT_DATA_DIR)
    parser.add_argument("--delay", type=float, default=1.25, help="Minimum seconds between requests")
    parser.add_argument("--timeout", type=float, default=20)
    parser.add_argument("--sizes", default="1,2,4,8,16,32,64,128,256,512,1000")
    args = parser.parse_args()
    sizes = [int(value) for value in args.sizes.split(",")]
    if any(size < 1 or size > 1000 for size in sizes):
        parser.error("Probe sizes must be between 1 and 1000")
    client = Client(args.delay, args.timeout)
    data_dir = args.data_dir
    if args.action in ("collect", "all"):
        for name, collect in (("gelbooru", collect_gelbooru), ("danbooru", collect_danbooru)):
            rows = collect(client, 1000)
            path = data_dir / f"{name}-artists-1000.csv"
            write_tags(path, rows)
            print(f"Wrote {len(rows)} artist tags: {path}")
    if args.action in ("probe", "all"):
        rows = read_tags(data_dir / "gelbooru-artists-1000.csv")
        results = probe(client, rows, sizes)
        tail_control = probe_tail_operand(client, rows) if 1000 in sizes and results[-1]["status"] == "ok" else None
        report = {
            "checked_at_utc": datetime.now(timezone.utc).isoformat(),
            "site": "https://gelbooru.com",
            "method": "public HTML search; first visible page only",
            "tag_fixture": "gelbooru-artists-1000.csv",
            "results": results,
            "tail_operand_control": tail_control,
        }
        path = data_dir / "gelbooru-or-probe.json"
        path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"Wrote probe results: {path}")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, OSError) as error:
        print(f"Error: {error}", file=sys.stderr)
        sys.exit(1)
