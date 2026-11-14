---
name: web-context
description: Compatibility redirect to the dedicated remote web-agent context repository.
---

# Web-agent context workflow moved

**As of 2026-11-14, this file is a legacy entry point only. Do not manage or store web-agent contexts in `timberpile/Boorusama`.**

The **canonical current instructions** are:

- [`timberpile/agent-web-contexts@main/AGENTS.md`](https://github.com/timberpile/agent-web-contexts/blob/main/AGENTS.md)
- [`timberpile/agent-web-contexts@main/.agents/skills/web-context/SKILL.md`](https://github.com/timberpile/agent-web-contexts/blob/main/.agents/skills/web-context/SKILL.md)

At the beginning of a Boorusama web-agent conversation:

1. Read both canonical files from **`timberpile/agent-web-contexts@main`** using the GitHub connector, plus the current Boorusama `AGENTS.md` for code-related work.
2. Discover `maintenance/web-context-*` refs in **`timberpile/agent-web-contexts`**, not here.
3. If no context is specified, show names from those refs and ask which to resume or what to name a new one. If a context is specified, restore that branch's `docs/web-agent-context.md`.
4. Maintain only the selected context on its **new-repository** branch and follow the canonical skill for SHA checks, conflict handling, and saved checkpoints.
5. Never fall back to creating/updating old context branches in Boorusama merely because the private context repository is unavailable. Report the access blocker instead.

The old `maintenance/web-context-*` branches here are historical migration sources, **not writable context storage**. Their preserved source commits are documented in the [migration record](https://github.com/timberpile/agent-web-contexts/blob/main/docs/migration-2026-11-14.md).

Boorusama `develop`, its Issues, feature branches, approved specifications, and current source code remain authoritative for all application work. The separate context repository stores continuity only. Nothing here changes the repository's development or local-agent workflows.
