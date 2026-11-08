# Final rollout: integration, user regressions and feature completion

## Mandate and precedence

The user tested the combined branch, reported the failures below, and requested a complete repair and feature-delivery pass before their next final review. This handoff is the entry point for the local lead agent. It is a plan, not evidence that these new failures are already fixed.

Read current `AGENTS.md` and the applicable repository skills first. This document and its linked plans supersede conflicting older remediation instructions about picker geometry, child-group promotion, cache generations, and stopping after source foundations. Preserve historical evidence rather than rewriting old failures as passes.

Use English for repository content and German for the final user acceptance checklist. GitHub Issues remain the only task tracker; the references below organize this requested plan, not a second task queue.

## Scope and deliverable

Finish the active rollout represented by the current task/test branches: #156 and inherited #132/#154/#155/#158/#142/#143 behavior; #140 and #141 Pixiv production integration; #157 native nhentai; #160/#161/#162 prefetch/pagination; and #144 collection sync, whose included branch is currently design-only. For #136, complete the selected Structure/Unified icon publication and applicable design verification, not an unrelated global UI redesign.

Do not interpret this as permission to implement every unrelated open issue. Do not resurrect #163, #112, the old Maestro experiment, or completed #53/#76 branch histories. Do not add Pixiv Series, a new toolbar editor, destructive server Favorites mirroring, or a different viewer design.

Deliver one runnable, verified combined candidate with the actual production entry points connected. A reviewed DTO/provider foundation, an unregistered engine, or a disabled Work action is not completion. Continue through implementation, corrections and re-review without pausing after each small stage. A genuine external service blocker must be isolated and reported accurately; it must not halt unrelated work or be labelled a successful acceptance test.

Authorization covers consolidating the task/test branches and implementing this scope. It does not authorize a PR, release, merge into `develop`, issue closure, destruction of user data, or deletion of task branches. Preserve any narrower publication restrictions in the local session; otherwise publish the final task/test candidate for the user's review.

## Starting refs and reconciliation

Audited public baseline: `maintenance/combined-testing-2026-11-08` at `4b9e8f6f9fbdd5020e1de87942f4b8a5f683ba5d`. Runtime assembly is `68c4635b9790e73acc01467874fcdac9fb44ac97`; later reporting changes are documentation-only. These plans are added on top. Read [the assembly manifest](combined-testing-2026-11-08.json) and [the previous combined review](combined-testing-2026-11-08.md).

| Owning branch | Audited head |
| --- | --- |
| `maintenance/156-shared-source-groups` | `8672cf2ba235fbc810bbcf3296efef1eb4410a37` |
| `feature/140-pixiv-work-viewer` | `d7298c5a06883977966421aec0d11ecf4d2564e4` |
| `feature/141-pixiv-work-page-bookmarks` | `01fa085840f8442246505b1ad1d883e01a4fecdb` |
| `feature/157-native-nhentai-galleries` | `cf71fb22e142564d96a1f25cce85a48898ec52fc` |
| `feature/160-viewport-thumbnail-prefetch` | `d13e06592cd5d6153d70d672d42fa089071940bb` |
| `bug/161-pixiv-explore-pagination` | `db54e43bb38e3d997136c52c3434c35342737df3` |
| `feature/162-unified-page-prefetch` | `dfe1c4690b1dc91d8bc4dc38321be478fac8fa11` |
| `feature/144-folder-based-collection-sync` | `4dbc9f08adb8bcbce17877d71d80a57ba475243c` |
| `develop` | `266a14c0f87f29213d48696bda7c806dc1d05b6e` |

Before editing, inventory `git status`, `git worktree list`, local/remote branch heads and commit ancestry. Fetch without resetting local work. Local checkpoints may be newer than these public SHAs. Commit or otherwise preserve owned changes before reconciliation. Do not overwrite another agent's worktree.

The remote combined branch already contains actual merges of these published inputs. Do not replay the same patches or the superseded standalone offline-cache commit again. Merge missing local task commits into an isolated continuation of the existing combined branch. Keep useful issue-owned history and `Refs #...` in commits. Use the owning task worktrees for separable changes; serialize edits to common files under the lead. When a task needs the updated common baseline, explicitly reconcile its prerequisite history before further edits rather than copying old files over the final implementation.

No blanket ours/theirs conflict resolution for runtime files. In particular preserve both #156 Group refresh/selection semantics and #162 dispatch-time prefetch guards, plus the Classic-only zoom already in `develop`. Record source SHAs and meaningful resolutions in the normal handoff. Do not merge the historical omnibus branch into `develop` as a shortcut.

Build/analyze and run the affected baseline on the newly reconciled candidate before treating its behavior as known. The earlier 8,414 Flutter/Dart and 76 Python passes apply to the previous #156 candidate, not automatically to this combination or the new changes.

## Execution plans

| Order | Plan | Required result |
| --- | --- | --- |
| 1 | [Source access, media and covers](../plans/final-rollout-2026-11-08/01-source-access-media-and-covers.md) | Fix Gelbooru reattachment, Pixiv image loading, source favicons, empty mosaic slots and offline Series covers; retain C1/C2 coverage. |
| 2 | [Favorites Sync and subtree deletion](../plans/final-rollout-2026-11-08/02-favorites-sync-and-subtree-deletion.md) | Save assignments reliably across token rotation; delete the selected local subtree atomically with correct Undo. |
| 3 | [Picker fidelity and diagnostics](../plans/final-rollout-2026-11-08/03-picker-and-debug-console.md) | Restore the old picker design with the precise new hit regions; restore Recent and Group label; newest-first diagnostic UI. |
| 4 | [Responsive import preview](../plans/final-rollout-2026-11-08/04-responsive-import-preview.md) | Remove synchronous full replanning from acknowledgement and repeated unrelated source changes; diagnose freezes/crashes on representative large exports. |
| 5 | [Complete native content and prefetch](../plans/final-rollout-2026-11-08/05-complete-native-content-and-prefetch.md) | Finish #140/#141/#157 production UI and media operations, C3/C4, and combined #160/#161/#162 behavior. |
| 6 | [Collection sync and final acceptance](../plans/final-rollout-2026-11-08/06-collection-sync-and-final-acceptance.md) | Implement the included #144 scope on unified groups, complete combined verification and produce one final user-review build. |

Prioritize the blocking Pixiv images, Favorites settings and import freezes before expanding the production feature surface. Diagnostic improvements and isolated picker work can run in parallel. After these paths stabilize, complete Pixiv then its Bookmark integration; nhentai and collection-sync foundation work may proceed in separate files, but their final integration must use the completed common contracts.

## Binding product decisions

- Persistent media cache identity is the existing URL/custom-key mechanism. No session salt, Auth-Epoch/Policy-Epoch filenames, durable media-generation allocator, permission database or cache-clearing migration.
- Runtime source/action binding and late-result checks remain separate from disk cache identity. A newly opened saved item may resolve a newly available compatible profile; a queued action must not silently change its actor.
- Structure/Unified and SVG family A are final. Retain persisted `allBookmarks` compatibility if useful; do not rename the independent global All destination accidentally.
- The user's first picker screenshot is the old-design reference; the second documents the regression. Reuse old visual proportions, typography, spacing, icons, Recent and `+ Group`, not the second screenshot's layout. Only the trailing chevron placement and split interaction change. No generated mockup replaces this reference.
- Parent deletion now deletes its complete local descendant hierarchy. Previous child promotion is explicitly rejected. Shared records with outside memberships survive; confirmation and Undo cover the subtree.
- Remote Pool/Related presentation stays its existing timeline/grid. Their site outage does not authorize redesign or invention of cached bytes.
- Backup writer remains v10 during this unreleased rollout. Preserve supported historical readers and valid stored identities.
- Pixiv Image View/Overview, image-region Page swipes and details-region Work swipes are already approved. Do not reopen that UX comparison.

## Evidence, delegation and completion

Source investigation supports the mechanisms described in each plan. It does not prove the exact user's data, device build, crash stack or failing HTTP status. Reproduce uncertain cases with distinguishing diagnostics, then fix the actual cause. Do not manufacture a passing test by changing expected behavior or mocking away the failing production boundary.

Lower-cost subagents may handle deterministic fixtures, localization, documented icon/picker geometry and narrow tests after contracts are fixed. The lead owns actor resolution, import/persistence correctness, deletion/Undo, media transport and cross-branch integration. Do not let multiple agents edit the same shared file concurrently. Each issue retains a concise continuation handoff and commits throughout the work.

Use FVM, the pinned toolchain, current regression script and the repository's physical-core concurrency policy. Final automated checks apply to the exact combined runtime candidate, not individual ancestors. Run ordinary-main Android/Maestro tests under a fresh exclusive lease, preserving/restoring the original APK, all app/cache roots, permissions and settings. No user-cache wipe to make offline tests pass. Never commit test credentials, imported private data or the supplied image backgrounds.

An actual independent Sol High agent must review the complete combined runtime/test diff and relevant Android/performance evidence. It must not be the author. Resolve findings, rerun affected checks, and obtain final re-review after corrections. Old stage approvals do not cover new shared changes. Penpot publication and source availability must be reported separately from runtime/test success.

Final handoff must contain: exact branch/build SHA; actual test commands and pass/fail/skip counts; analysis errors/warnings separately from informational findings; per-feature production entry points; before/after import and opening measurements; remaining external limitations with evidence; independent review results; verified emulator restoration; and a short German checklist for the user. Do not report 'everything works' or 'complete' with unregistered engines, failing tests, known regressions or unexercised mandatory feature paths.
