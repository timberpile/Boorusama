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
meaningful coverage, and likely regressions. Use focused checks to investigate
findings and apply scope-appropriate verification from `AGENTS.md`; broad/unclear
scope needs the full suite. Before develop integration, require a complete pass
on the final candidate. Reuse an existing pass on that same candidate across
handoffs and report-only edits; relevant changes require re-verification. Device
validation still needs a concrete reason. Review timing-sensitive tests for
controlled clocks, explicit completion boundaries and sensible hang guards;
fixed sleeps and tight wall-clock caps need justification. Check relevant async
changes under parallel execution without weakening meaningful timing contracts.

For your own implementation, fix straightforward confirmed defects when fixes
are allowed and rerun affected checks. For review-only requests, report findings
without changes unless authorized. Distinguish defects from speculation; report
verification and limits without inventing findings.

Ordinary implementation already verifies its changes; this is not an automatic
second workflow.
