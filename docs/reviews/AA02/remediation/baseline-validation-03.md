# AA02 independent baseline — Pixiv identity, sharing and selection observations

This checkpoint adds nine initial decisions. No application edit, runtime execution, issue claim or acceptance is included. Original observations retain their identifiers and conclusions in [source-map.md](source-map.md); a stronger independent conclusion does not rewrite an auditor's original confidence.

## Source snapshots

- #117 / T004: `e2929259b7725c484d11483d6ea48270079eb2f4`.
- #118 / T005: `1d02bef637966999fbd0b72ecb9c6f0e1eedce8a`.
- #92 / T006: `e8816c22048b324f00d682b7637c0ab1040147ca`.
- #108 / T018: `c6d3e62ed525d7f3298ddf115b46d5d6c3dd01cd`.
- These independent branches use base `422aeae087c1108e655d85d1a3dac25120456cd6`. They have not been combined by this assignment.

## AA02-C0003 — nullable artwork visibility and mute metadata

**Kind: payload-contract risk. Assessment: uncertain. Current permissive null handling: present; legitimate failing payload: not established. Severity medium / P2. Remediation: needs-local-investigation, not a speculative filtering rewrite.**

Read full #118 `following/presentation.dart` and `packages/booru_clients/lib/src/pixiv/types/pixiv_illust_dto.dart`, alongside the already inspected endpoint/presentation/card tests recorded under AA01 T005. The DTO intentionally represents absent fields as null; its actual JSON field is `visible`. The preview predicate excludes `visible == false` and `isMuted == true`, while null values pass. This is a real permissive branch, but the supplied reports do not establish that an otherwise valid supplied preview lacking these fields must be treated as forbidden. No live private/account payload was fetched here.

Keep this separate from known restrictive `sanityLevel` metadata (AA01-C0003), configured explicit-content cover (AA01-C0002), omitted wrapper-artist mute (AA01-C0012) and local tag-blacklist policy (AA01-C0019). A redacted endpoint fixture and the intended unknown-metadata policy are needed to validate a fail-closed change without silently blanking supported previews. Continue excluding explicitly invisible/muted artwork; do not manufacture undocumented required fields.

## AA02-C0021 — manually replaced refresh token retains the previous account identity

**Kind: inherited defect. Assessment: validated-static for the manual token-edit trigger. Current presence: present in the inspected #117 source. Severity medium / P1. Remediation: focused candidate after the global baseline and ownership; account bootstrap and persistence require regression coverage.**

The original unnumbered report only proposed mismatched stored identity as a hypothetical. Independent source tracing establishes a concrete writer:

1. In `lib/boorus/pixiv/configs/widgets.dart`, OAuth `_store` populates login, refresh token and `PixivExtraData` from the same token response, but `_RefreshTokenField.onChanged` only calls `updateApiKey`.
2. Read full `lib/core/configs/create/src/providers/internal_providers.dart`. `EditBooruConfigNotifier.updateApiKey` is exactly a `state.copyWith(apiKey: apiKey)` assignment; it does not clear or revalidate login/passHash. Clearing credentials through the status card does clear all three, but that path is not invoked by pasting a different token.
3. The #117 page/session uses the positive user ID from stored extra data. Read full `favorites/providers.dart`: the captured `params.userId` is sent as `getUserBookmarks(userId: ...)`, independently of the auth config used by the client.
4. Read `auth/auth_interceptor.dart` source 1–265 and full `client_provider.dart`. The interceptor refreshes the newly entered token. Its callback persists new account metadata through `persistPixivRotatedToken`, but this intentionally updates the repository **without refreshing the active BooruConfigNotifier**. The request's already captured user ID is not rewritten by that storage-only update.

Thus an existing account-A profile can retain A's identity while the user manually replaces its refresh token with B's. Public Favorites can be requested for A under B's credentials; this is wrong account attribution, not proof of access to A's private data. A fresh OAuth login's paired `_store` does not establish that the manual path is safe. No real credentials or network calls were used.

The shared auth-refresh registry also uses the stored user ID as a key when available. Stale identity therefore deserves a concurrent-profile isolation check; **this checkpoint does not claim an executed cross-account refresh collision or token disclosure**.

The smallest source-supported safety direction is to invalidate stale account metadata when a genuinely different manual credential is entered, without changing generic non-Pixiv setters. Do not clear metadata on programmatic updates from successful OAuth login, manufacture a user ID, or initiate a token request on every keystroke. A complete correction must also confirm how an initially unknown account becomes usable for Favorites/Following after a successful refresh, and preserve rotation CAS, imported profiles and credential deletion semantics.

Local acceptance: use distinct fake A/B token responses and inspect actual request user IDs and refresh-registry keys; test manual A→B replacement, unchanged token text, successful OAuth login, blank token, fresh manual token, repository-only rotation and two same-site profiles. Verify no old-account request/result survives and no unrelated stored profile is changed. This concrete trigger is remediation-discovered evidence for the existing original observation, not an additional audit vote.

## AA02-C0022 — selecting the first three supplied artworks before filtering

**Kind: improvement / product choice. Assessment: proposal-only. Current behavior: present. Severity low / P3. Remediation: not-needed for the stated contract.**

`pixivFollowingPreviewUrls` takes three entries before eligibility/URL filtering. It may therefore show fewer than three even when a later eligible entry exists. The inspected #118 requirement promises up to three supplied previews, not a filled three-slot grid, and explicitly avoids per-artist/detail fetching. This is separate from AA01-C0028's preferred-URL fallback within one artwork. Do not turn the bound into a fabricated defect or expand network work. Local presentation checks should preserve the bound and safety filtering during the independently needed cover/rating correction.

## AA02-C0013 — Image fallback prefers a known original over a thumbnail

**Kind: quality/bandwidth policy question. Assessment: proposal-only. Current order: present. Severity low / P3. Remediation: not-needed.**

Read current issue #92, full `shares/src/share_media_url_resolution.dart`, and full `test/core/posts/shares/selection_share_image_test.dart` at the #92 head. The candidate order is viewer, then sample/original/thumbnail for non-video images; each candidate must be a usable web URL and not a recognized video extension. The exact Original/video extraction paths remain separate. A test explicitly expects the known original when viewer/sample are unavailable, and independently checks Original eligibility. No local test was run.

#92 asks for a usable display/sample fallback and separate Original requirements, not a mandatory thumbnail-first policy or the viewer prefetcher's High ceiling. Reordering the fallback without an agreed quality requirement would be discretionary behavior change. Preserve the separate host-blind Pixiv authorization defect AA01-C0011; an acceptable URL fallback does not validate credential scope.

## AA02-C0014 — apparently missing await around ShareService

**Kind: rejected hypothesis. Assessment: rejected. Claimed missing awaited Future: absent. Severity low / P3. Remediation: not-needed.**

Read the complete `shares/src/providers.dart` and `share_post_button.dart` at #92, and complete `listing/src/widgets/post_actions.dart` at #108. `ShareService.sharePost` returns `void` and opens the unified share surface. The surrounding async action has no returned share Future to await. Both task/base comparisons leave that service file unchanged; #108 dispatches the selected source configuration, not an arbitrary Browse account. Adding `await` to a void expression is not a valid correction. Native sharing errors inside the later surface remain separate acceptance work, not evidence for this allegation.

## AA02-C0019 — unresolved-profile local Bookmark operations

**Kind: policy question. Assessment: proposal-only; no credential-borrowing defect established. Current local-operation behavior: present. Severity low / P3. Remediation: not-needed without a contrary product requirement.**

Read issue #108, complete `default_multi_selection_actions.dart`, `post_action_snapshot.dart`, and `post_actions.dart`. Snapshot identity is origin-based and checks account resolution again at execution. A still-unresolved snapshot can pass that consistency check, while a newly different resolution cannot. For a single local bookmark, the builder explicitly uses `BooruConfig.empty.auth` when no source config resolves. Remote favorite/share actions require resolved configs; the local-library operation is intentionally distinct. This code is counter-evidence to silently borrowing current Browse credentials.

The stated #108 parity/capability requirement does not forbid editing a retained local bookmark after its account disappears. Keep the original policy question and test deleted/recreated profiles, but do not disable useful local-library operations merely because authentication is unavailable. The mixed Pool/selection interaction remains a separately assessed combined-candidate concern.

## AA02-C0029 — historical native VM callback/finalizer diagnostic

**Kind: diagnostic risk / missing independent runtime evidence. Assessment: uncertain; feature attribution not established. Current runtime presence: not-inspectable in web-only work. Severity medium / P2. Remediation: needs-local-investigation.**

Read the actual #108 `docs/handoffs/108-final-review.md` and the relevant source/action/widget tests. The handoff states that its application suite exited zero with passing assertions while emitting the same native callback/finalizer diagnostic previously seen during #106. Its log paths are local `/tmp/boorusama-review-2026-10-29/...` paths belonging to that author's environment, not accessible artifacts in this session. This is evidence that the author recorded a diagnostic, not proof of its cause, a clean native log, or this remediation session passing 1,414/7 tests.

The local agent must reproduce/capture the diagnostic with the exact final branch SHA, compare the relevant base and affected consumer suite, and determine whether it is a pre-existing dependency/runtime issue or a changed lifecycle problem before making a speculative fix. Do not suppress the warning or weaken assertions to claim acceptance.

## AA02-C0035 — extremely small keyboard viewport for the batch dialog

**Kind: layout risk. Assessment: uncertain for the extreme reported scenario. Current overflow: not reproduced. Severity low / P2. Remediation: needs-local-investigation only at a concrete supported viewport.**

Read full `bookmark_batch_dialog.dart` and `bookmark_batch_dialog_layout_test.dart`. The dialog uses bounded width/height and a Flexible scrollable body; title, padding and Cancel still consume nonflexible vertical space. The actual suite already includes 320×640, 2x text and a 220px bottom keyboard inset, with bounded geometry, hit-testable Cancel and no-framework-exception assertions. It is not an untested generic desktop shell, but reading that test is not executing it.

A much smaller residual height could exceed the fixed chrome's minimum. No precise failing supported geometry or executed error was supplied. Reproduce with a real relevant small/landscape/IME constraint before redesigning the entire dialog; retain group creation, folder navigation and cancellation accessibility. Do not classify arbitrary zero-height constraints as a demonstrated regression.

## AA02-C0036 — #92/#108 combined selection-sharing acceptance

**Kind: integration coverage gap. Assessment: validated-static as an unverified composition, not a proven source conflict. Current combined candidate: absent. Severity medium / P2. Remediation: blocked-separate-integration.**

Compared both branch changed-file inventories and traced the actual #108 action → ShareService → unified sheet path against #92's resolution change. The substantive changed source paths do not overlap; #108 delegates to the shared service rather than copying the Image resolver. Existing #92 tests cover fallback/eligibility, and #108's actual-grid `selection_action_parity_test.dart` covers single→batch→single presentation, download and the real single BookmarkGroupPicker. Neither independently establishes a native Share journey on a merged candidate.

During separately authorized integration, test a selected unhydrated image through actual Share, cache preparation/cancel/unsupported result and source-account changes, plus video posters and exact Original behavior. Do not merge branches or call an unbuilt projected composition verified merely to close this coverage item.

## Continuation

The strong new conclusion is the concrete manual-token writer for C0021; the remaining entries above are rejected hypotheses, policy choices, risks or integration evidence. Complete the remaining #97/#99/#106/#107 state and historical-correction counterchecks, Maestro provenance/privacy and coordination/integration observations before opening the all-claims source-edit gate. No source correction was published here.
