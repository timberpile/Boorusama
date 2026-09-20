# PS-021: Artist tag fixtures and Gelbooru OR scaling probe

- Priority: Normal
- Affected feature/branch: Following-feed architecture; `feature/chronological-pinned-search-support`
- Agent/session: Codex, 2026-09-19
- Dependencies: None

## Problem

Feed design needs realistic 1,000-artist fixtures for Gelbooru and Danbooru, plus evidence of how Gelbooru handles a large OR group of artist tags.

## Expected behavior and acceptance criteria

- Provide 1,000 distinct, real, nonempty artist tags for each site.
- Provide a reproducible Python probe using a bounded, sequential set of public requests.
- Record response validity, timing, first-page tag matches, and an explicit control for a late OR operand.
- State what the probe does and does not establish for feed architecture.

## Completion evidence

- Generated and checked both 1,000-row CSV fixtures for uniqueness and nonzero counts.
- Ran OR queries with 1 through 1,000 operands; all tested first pages had 42 visible posts and all 42 matched a requested tag.
- A separate exact-MD5 control found a post for the 1,000th operand in the 1,000-tag OR query.
- Recorded the requests and measurements in [the data README](../../superpowers/data/README.md) and `gelbooru-or-probe.json`.
- `python3 -m py_compile scripts/booru_artist_or_probe.py` passed.
