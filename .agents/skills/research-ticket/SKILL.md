---
name: research-ticket
description: Use when researching Boorusama BUG, FEAT, CHANGE, or UI reports; comparing existing GitHub issues; drafting issues; or preparing implementation guidance for a separate coding agent.
---

# Research a ticket

Research and draft; do not treat a reported ticket as permission to implement it or publish an issue. GitHub Issues remain the only task tracker. Follow `docs/issue_workflow.md`.

1. **Set scope and authority.** Split independent reports. Respect explicit deferrals: do not draft, publish, or queue them. Unless the user approves publication, keep new issue drafts and implementation notes in the conversation.
2. **Check existing work.** Search open *and closed* issues, relevant branches, tests, code paths, and subsystem docs. Identify duplicates, regressions, adjacent issues, and already implemented behavior; cite issue numbers and file/function paths.
3. **Investigate bugs.** Establish reported vs reproduced behavior; trace the relevant execution/state path and compare working equivalents. Distinguish **confirmed root cause**, **supported hypothesis**, and **unknown**. Suggest a minimal fix and a focused regression test only as specifically as the evidence allows. Do not claim to have run code or a device test when only inspecting source.
4. **Design features and UX changes.** Inspect existing conventions and data models. For clear requests, outline the smallest compatible change and give short, implementer-oriented code sketches when useful. For consequential ambiguity, present a recommendation, tradeoffs, and targeted questions before finalizing the issue.
5. **Present for owner review.** Summarize findings and relevant existing issues; provide short English GitHub issue drafts with **Problem** and **Expected behavior** and proposed labels. Keep diagnosis, file-by-file details, code sketches, and test suggestions separate from issue descriptions. **Do not create/update GitHub issues or commit research documents without the user's authorization.**
6. **Publish technical handoffs when approved.** After an issue has a real GitHub number and the user has approved sharing its implementation guidance, put nontrivial details in `docs/handoffs/<issue-number>-<slug>.md` on a branch accessible to the implementer. Link it from the issue (brief comment or description reference). Include:
   - Issue URL, examined branch/commit, reproduction or observed behavior.
   - Evidence and confidence (confirmed vs hypothesis); relevant paths/functions.
   - Minimal implementation approach, optional code sketches, invariants/edge cases.
   - Focused test cases, risks, and unresolved owner decisions.
   Use `docs/designs/` for enduring architectural/product specifications. Skip a handoff when the issue is self-contained. Neither file is a task queue, status tracker, or substitute for the issue.
7. **Hand off accurately.** The local coding agent reads the issue plus linked handoff, rechecks proposals against its current source commit, implements/tests only when separately authorized, and reports deviations. Treat unexecuted code sketches as proposals, not verified patches.

## Common mistakes

- Creating a detailed issue body instead of a concise user-visible outcome.
- Committing a `pending-` research backlog before issue approval.
- Treating suspicious code as a proven cause or stale line numbers as current.
- Losing implementation research in chat after approving an issue: publish and link the handoff before handing it to the local agent.
