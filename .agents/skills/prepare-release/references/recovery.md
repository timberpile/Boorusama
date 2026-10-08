# Requested recovery

Use only when the user explicitly asks to undo the skill's release work. A failed
release step does not authorize automatic rollback. Use the owned-action record
and current state, not assumptions about what the last run probably did. All
`gh` operations explicitly target `timberpile/Boorusama`.

## Establish what can be undone

Read the record, fetch current branch/tag state, and inspect the PR, draft,
assets, and intervening commits. Compare intended writes with observed results,
including any previously uncertain timeout. Check whether the user published
the draft or other people changed the affected resources. If the record is
missing, reconstruct ownership from Git and GitHub before making changes; stop
any operation whose target or ownership cannot be established.

Prepare the exact reverse diff and resource list before changing shared state.
Identify which effects can be reversed and which will remain: merge/commit
history, downloaded artifacts, and external notifications cannot be reliably
erased. Honor an explicit request scoped to these known actions without asking
for each action again. If reversal would remove pre-existing features, overwrite
later edits, or touch an already public release, present the concrete proposed
diff/resources and obtain that additional scope decision first. Do independent
safe recovery work while that decision is pending.

## Recover according to the observed state

- **Own local uncommitted edits:** reverse only the recorded hunks after checking
  the current content. Preserve unrelated tracked/untracked changes. Do not use
  blanket checkout/restore, `reset --hard`, or `git clean`.
- **Own committed changes:** use a scoped reverse patch or new `git revert`
  commit in an isolated task worktree. Preserve later work. Integrate/push only
  the reviewed recovery scope under the existing workflow. An explicit request
  to undo recorded release changes authorizes the necessary recovery integration
  and normal pushes; it does not authorize history rewriting or public release
  publication. Verify the reverse behavior and final version/changelog.
- **Promotion already merged into `master`:** distinguish reversing the
  preparation metadata from reverting the whole promoted release. The latter
  can remove features that already existed on `develop` before this skill ran.
  Prepare that exact tree diff and resolve its scope before applying it. Never
  blindly run `git revert -m 1` on the release merge. Deliver the agreed reversal
  through `develop` and a `develop` to `master` PR, required checks, and a real
  merge; no direct `master` commit/push. Synchronize the resulting history back
  into `develop` and preserve newer work. Inspect the full recovery PR diff,
  not just the revert commit: newer unrelated `develop` commits could also be
  promoted. Stop that promotion and present its exact extra scope for a decision;
  preserving those commits does not authorize releasing them. Do not reset
  `develop` or bypass the PR policy to avoid this conflict.
- **Draft created by this run:** preserve verified notes/assets in the recovery
  record, confirm the exact recorded release ID/tag and `isDraft=true`, and
  delete only that unchanged, owned draft when the rollback request covers it.
  Coordinate with the user so nobody publishes/edits it during removal;
  `gh release delete` has no draft-only guard. Without that coordination,
  retain it and hand deletion to the user. Recheck its state immediately before
  deletion; an observed publication or unexpected edit stops deletion. Never use
  a delete-and-recreate loop. Do not delete a pre-existing draft or public release
  as part of ordinary recovery.
- **Pre-existing draft modified by this run:** under the same coordination and
  still-draft checks, reverse only recorded metadata edits and remove only assets
  newly uploaded by this run, checking their IDs/hashes against the record.
  Preserve its original assets and later edits. Keep `--draft=true` explicit on
  metadata restoration. Without the original snapshot and confirmed ownership,
  report the gap and leave it intact; never delete the whole pre-existing draft.
- **Tags and artifacts:** preserve pushed tags by default; report them as retained
  historical references. Deleting an exact pushed tag requires a separate
  explicit decision after checking current references; never force-move a tag.
  Remove only recorded, disposable local artifacts after preserving the action
  record and needed evidence. Never touch shared signing material or credentials.

Do not publish a replacement release to perform recovery. A public release
needs a separately scoped correction plan; this draft-only skill does not
publish it. Do not silently reuse a consumed release version/tag or build number
on the next attempt. If the ordinary +1 increment would collide with an abandoned
release, propose a fresh target instead of replacing existing history.

## Verify and report

Run checks appropriate to the reverse diff. Verify the new commits and branch
relationships, unchanged unrelated work, the draft's observed absence when
deleted, and retained tag resolution. Update the record with recovery actions,
results, and any remaining uncertainty. Report exactly what was undone, what
remains, and what could not safely be reversed. Do not claim that the original
history or all external effects disappeared.
