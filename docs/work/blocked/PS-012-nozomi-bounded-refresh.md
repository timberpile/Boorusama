# Investigate bounded Nozomi refresh support

Priority: Low
Affected feature: Pinned-search engine support

## Blocker

Nozomi computes query intersections using complete post indices in the client
and fetches a separate JSON document for every returned post. Limiting the
shared scanner to 50 posts does not bound index processing independently of
the matching population, nor provide a conservative single-request refresh.
Keep the engine unsupported for subscription checks until a bounded newest
index/search path is verified. Ordinary browsing is unaffected.

## Resume criteria

- Identify a newest-window query strategy with bounded client/network work.
- Verify original query semantics and upload ordering without full index scans.
- Add request-budget tests and opt in only after the bounded behavior is proven.

Agent: Codex (/root), 2026-09-17.
