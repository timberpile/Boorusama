# Pixiv Explore pagination — issue #161

Historical qualification checkpoint. The final combined review, owner acceptance
and integration are recorded in the [P7 qualification handoff](p7-pixiv-qualification-2026-11-11.md).
Outstanding gates below describe this earlier checkpoint.

## Candidate and authorization

- Branch: `bug/161-pixiv-explore-pagination`.
- Runtime/test candidate: `e9a2a2e06e987173f40f84fad14b73084a4207f5`.
- Develop prerequisite: `2e2ea428ba323706e37a65e45903d3959df439d4`.

The original implementation is `6c26e5cabc8723049bda8f6cf1121694fb8adb5a`, followed by handoff `db54e43bb38e3d997136c52c3434c35342737df3`. This preparation preserves that history, reconciles only the pinned develop prerequisite into the existing task branch and formats the task files with FVM. The delta against develop is exactly the Explore repository, its regression test and this handoff. Subsequent documentation-only commits do not change the checked runtime or tests.

This is a standalone pagination component of P8, not the Work/Page viewer cutover. Neither #165 nor #140/#141/#164 is included. It still inherits develop's independent Pixiv image regression until that separately approved correction is reconciled. No PR, release, merge, issue closure or APK delivery is authorized.

## Behavior and review focus

Use the existing `pixivIllustListResultToPostResult` conversion so Ranking, Following and Recommended retain the API's explicit continuation/end signal after filtering. Remove repository-level exhaustion caching: the grid controller owns the feed session, and refresh or a late response must not poison a new session. Preserve Post origin and existing error/cooldown mapping.

The regression fixture exercises the actual Pixiv client, Explore repository and shared PostGridController. It covers empty/hidden-only pages with continuation, nonempty terminal pages, refresh after exhaustion, retry at the same offset, independent feeds and late terminal responses. Adjacent listing tests cover the surrounding pagination machinery. No new automatic polling or unbounded pagination loop is introduced.

## Actual verification

Toolchain: FVM 4.3.1, Flutter 3.47.2 and Dart 3.13.2 on hosted Linux.

| Check | Recorded result |
| --- | --- |
| New tests against the unchanged develop implementation | **Three passed; 14 failed on intended assertions** in [run 42927539360](https://github.com/timberpile/Boorusama/actions/runs/42927539360). The exact candidate implementation was restored before positive tests. |
| Pixiv and adjacent shared listing tests on the candidate | **257 passed** in the same run. |
| FVM formatting and patch whitespace | Passed. |
| Scoped analyzer | **No issues found**. |
| Application suite in the first full-run attempt | **6,791 passed; ten FFmpeg-dependent tests skipped** because FFmpeg was absent. The runner then stopped on missing `rg`, before package/tooling execution. This is not a complete regression pass. |
| Supplemental native media suite on the same candidate | **16 passed, zero skipped**, including all ten previously skipped cases, with real FFmpeg/FFprobe in [run 42931390172](https://github.com/timberpile/Boorusama/actions/runs/42931390172). |
| Fresh complete runner with `ripgrep` installed | [Run 42930406283, issue 161 job](https://github.com/timberpile/Boorusama/actions/runs/42930406283/job/130227416688). At this checkpoint its final result has not been established; inspect the final outcome/artifact before claiming complete qualification. |
| Additional local tooling checks | Both repository shell suites passed in an isolated checkout of this candidate. Local Python attempts were interrupted by execution-tool timeouts and are not counted as passes or confirmed application defects. |

The original `pixiv-pagination-evidence` artifact records the immutable candidate, red/positive output and analyzer result. Its SHA-256 is `da6a3e0d9258b22cabccb1e0f101a1a53441c2a9b05b2c5f7f96c2e8062a86ba`. The supplemental native artifact SHA-256 is `236c0022e6c15bfcf1a1f50a1a601f44379a7233fa533d4db5888d6f64f91a44`. Downloaded archives were verified against their published digests; raw local evidence is retained under `.worktrees/_artifacts/161-verification/`.

## Review and acceptance still required

The author inspected the final delta and its consumers; this is not an independent reviewer pass. No independent Astra XHigh interface was available or invoked. Android/real-account verification was not performed. Inspect profile/account, Following privacy, ranking mode/date and refresh isolation in the independent review.

After the separately approved #165 correction is available in the prerequisite, reconcile this branch without expanding its pagination scope. On Android, use the exclusive emulator lease, restore the original environment and exercise Ranking, Following and Recommended: filtered/empty pages, terminal feeds, refresh, retry and scope switches. Confirm bounded automatic loading and correct profile isolation; do not change the only copy of user data.

Before any approved integration, establish the complete gate on the final combination with current develop. Reuse valid unchanged-candidate evidence across handoff/status-only updates; runtime/test/dependency changes or a changed develop combination require the full regression again. Automated checks, independent review, Android acceptance and integration approval remain separate facts.

Keep #161 separate from the image-loading fix and retain its issue ID in the eventual approved integration commit. GitHub Issues remain the only task tracker.
