# POST-005: Restore Philomena media-quality resolution

Priority: High

Affected feature or branch: `feature/bookmark-post-behavior-parity`

Agent/session: Codex `/root`, 2026-09-23

Work branch: `feature/bookmark-post-behavior-parity`

Dependencies: POST-001 unified post model and mixed-booru presentation

## Problem

The Philomena media resolver still casts the concrete runtime `Post` to the
parser-only record, so configured representation qualities always fall back to
the sample URL.

## Expected behavior

The resolver reads `PhilomenaPostData.representation` and safely falls back for
incompatible payloads.

## Acceptance criteria

- Every configured Philomena representation resolves from a concrete `Post`.
- Missing or incompatible payload data returns the sample URL.
- Focused resolver tests pass.

## Completion evidence

- The resolver reads `PhilomenaPostData.representation` from the concrete
  shared `Post` payload.
- All eight representations, missing data, unset quality, and unknown quality
  fallback behavior are covered by passing tests.
