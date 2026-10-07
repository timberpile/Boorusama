---
name: design-change
description: Resolve significant Boorusama architecture, persistence/migration, subsystem, or UX/state decisions, or produce a requested design; skip routine implementation.
---

# Design a change

Inspect relevant code/tests/docs and current boundaries; avoid repository-wide
investigation unless necessary. Prefer the simplest approach extending existing
abstractions, without speculative extensibility.

Capture decisions an implementer cannot infer: goal, relevant current behavior,
chosen approach, data/API/state changes, profile/site boundaries, compatibility
and migration, failure/recovery, and verification. Include only relevant parts;
resolve missing product decisions with the user.

Keep the design concise, without line-by-line implementation instructions or an
automatic separate plan. If a persistent document is requested, use
`docs/designs/<date>-<name>.md`. Preserve historical `docs/superpowers/` material;
existing plans remain usable through `execute-plan`.
