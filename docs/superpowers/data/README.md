# Artist tags and Gelbooru OR probe

Generated on 2026-09-19 with [`scripts/booru_artist_or_probe.py`](../../../scripts/booru_artist_or_probe.py).

- `gelbooru-artists-1000.txt` and `.csv`: 1,000 distinct, nonempty tags shown as **artist** in [Gelbooru's public tag listing](https://gelbooru.com/index.php?page=tags&s=list&order_by=type&sort=asc). The script reads successive 50-tag pages and removes duplicates.
- `danbooru-artists-1000.txt` and `.csv`: 1,000 distinct, nonempty, nondeprecated category-1 tags from [Danbooru's tag API](https://safebooru.donmai.us/wiki_pages/api:tags), ordered by post count.
- `gelbooru-or-probe.json`: measured first-page results for 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, and 1,000 Gelbooru artist tags joined with `{tag1 ~ tag2 ~ …}`. The query syntax follows [Gelbooru's cheatsheet](https://gelbooru.com/index.php?id=26263&page=wiki&s=view).

The `.txt` files contain one tag per line; the `.csv` files also retain the reported post count. Run `python3 scripts/booru_artist_or_probe.py all` from the repository root to regenerate both lists and the probe. `collect` or `probe` runs only the named stage. Requests are sequential with at least 1.25 seconds between starts; HTTP errors stop the run. The script uses Python's standard library.

In this run, every tested OR size returned 42 visible posts, all carrying at least one requested tag. The 1,000-tag URL was 11,140 characters long and returned in 2.015 seconds. Sixteen distinct artist tags were represented on its first page; the latest tag position observed there was 853. A separate exact-MD5 control found a post by tag position 1,000 both alone and with the full 1,000-tag OR group.

This verifies the sampled first page and the final operand of this particular 1,000-tag query. It does not establish Gelbooru's maximum OR size, correctness of every operand on every page, or performance under repeated/concurrent requests. Long URLs may also behave differently through other clients or proxies. The CSV post counts are snapshots and can change.
