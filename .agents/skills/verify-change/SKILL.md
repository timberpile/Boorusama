---
name: verify-change
description: Review a Boorusama change when requested, for independent confidence, or for justified additional validation of a large cross-cutting change.
---

# Verify a change

Use the request and existing work item/design/plan as acceptance criteria; do not
create missing artifacts. Inspect the diff and enough surrounding code to assess
correctness, without reconstructing development history or auditing unrelated style.

Check requested behavior, scope, async/lifecycle, nullable external data,
cache/state invalidation, persistence/backup compatibility, localization,
meaningful coverage, and likely regressions. Use the smallest credible checks
under `AGENTS.md`; broader suites or device validation need a concrete reason.

For your own implementation, fix straightforward confirmed defects when fixes
are allowed and rerun affected checks. For review-only requests, report findings
without changes unless authorized. Distinguish defects from speculation; report
verification and limits without inventing findings.

Ordinary implementation already verifies its changes; this is not an automatic
second workflow.
