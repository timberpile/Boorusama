# Stage 00: prerequisite and environment verification

**Owner issue:** #132. **Existing branch:** `feature/132-preserve-favorites-sync-group-contents`.
**Purpose:** remove the existing destructive first-binding behavior before carrying Bookmark writers into the architecture refactor, and establish an honest verified local base.
**Final reviewer:** independent Sol High, or Astra High if new storage/recovery complexity is discovered.

## 1. Resume the prepared prerequisite, do not reimplement it

Read the [published #132 handoff](https://github.com/timberpile/Boorusama/blob/2d468355406b92448d52f1b2a4914d058c6d5a1b/docs/handoffs/132-preserve-favorites-sync-group-contents.md). The recorded branch head with that handoff is `2d468355406b92448d52f1b2a4914d058c6d5a1b`; runtime/test changes end at `b4995fd3248b9431730378772f82329d7e9c6ba2`, based on develop `e306ff5338a2255a89731c61bd0672336a933344`.

The source patch removes destructive target assignment, clear confirmation/helper and obsolete runtime problem state. It includes preservation tests for global/profile/editor entry points, Post/Pool/Related memberships and dates, no fetch on ordinary Save, settings failure, concurrent content changes and UI behavior. The existing explicit Save & Fetch UI remains, as #133 is a separate redesign.

**Not yet executed:** FVM format/analyzer, Dart/Flutter RED/GREEN, full local regression, Android acceptance, independent Sol High/Astra High review. Source inspection and GitHub commit publication are not substitutes. Do not start dependent runtime work with an unverified prerequisite.

## 2. Local environment preflight

Read current AGENTS.md and relevant repository skills, fetch refs, inspect all worktrees and check for concurrent claims. Preserve user changes and existing task branches. Reuse the #132 worktree or deliberately attach its existing branch. Do not rename or reset a running task.

Confirm pinned FVM SDK, package resolution/generated outputs, available physical-core test concurrency, durable artifact directory and independent reviewer availability. Use `.worktrees/_artifacts/content-architecture/132/` for logs. Missing tooling is an explicit blocker; do not silently run another Flutter/Dart version.

Inspect #132's complete diff, constructors/interfaces used by the new mixed fixture, and every old helper/argument callsite. Search for `confirmedClears`, `serverFavoriteGroupsToClear`, `ServerFavoriteProblem.confirmationRequired`, and imports of the deleted binding helper. Unreachable old translation entries alone do not require generating unrelated locale changes.

## 3. Verification and correction sequence

1. Run formatting on changed Dart files and relevant analysis. Fix actual compile/analyzer errors on this branch, including stale tests/callers.
2. Run `test/core/bookmarks/server_favorites`, then all `test/core/bookmarks`, with FVM and normal physical-core concurrency. Existing tests still cover direct confirmed favorite/unfavorite projection, cancellation and stale accounts/targets.
3. Check ordinary Save of a populated mixed group changes only target settings; before/after snapshots, group IDs, memberships and timestamps remain equal, including after cold reload. Failed settings persistence retains old assignment and content. Explicit fetch adds missing Posts; it never clears existing Group/Related entries.
4. Inspect old versus new regression behavior. The preparation session did not run RED; do not invent it. A disposable isolated old-code comparison is useful if the new tests do not clearly prove the old bug.
5. Perform the small leased-Android check for no destructive prompt, normal Save without fetch, narrow/large-text picker usability and preserved data. Use disposable local fixtures, not the real user library/server favorites.
6. Run the full local runner on the final candidate as required for integration; record actual output and limits. No failed/skipped required suite is a pass.
7. Commit fixes with `Refs #132`, obtain the independent final review, remediate and repeat affected verification/review. Record final tested/reviewed SHA in its own handoff.
8. The next architecture task can use that verified commit as a local dependency base. No merge into develop or closure is implied; await explicit integration permission before those operations.

## 4. Other issues are not a reason for unrelated pre-work

The complete dependency audit is in [README](README.md). #142/#143 are sequential architecture stages after unified storage. #43 aliases remain separate because identity reconciliation is not required to introduce Groups and must not be guessed. Existing #137/#138/#139/#145 behavior is reused, not reopened. Deferred UI/toolbar/headers, broad Undo, sync and extra Pixiv features stay excluded.

The existing #153 zoom branch can be verified independently using its handoff, without rewriting it or blocking Group/storage foundations. Its approved behavior must be preserved when the user authorizes a combined viewer candidate; that combination needs its own fresh full regression and independent review. Do not merge or cherry-pick it into another task without the required integration authorization.

## Exit

A concrete verified #132 commit, its independent review record and an inspected current runtime base are available. The branch remains open with accurate status until authorized publication. Proceed to [stage 01](01-foundation.md) only after this gate. No new architectural product decision is required from Timber to start the already approved work.
