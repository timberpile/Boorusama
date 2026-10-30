# AA02 independent baseline — historical Realbooru and Android update claims

These are source-based decisions, not executed reproductions. No application branch or issue was changed. The historical #53/#76 branches and deleted #111 branch are **not implementation write targets**; current develop is inspected read-only. Do not recreate #111, patch develop, or replay old branches as if they were current candidates. Original provenance remains in [source-map.md](source-map.md).

## Inspected revisions

- #53 / T019 / `bug/53-realbooru-prefetch-refresh`: `f7eba53fec0bc0369a9c3e84a8931353c0a8a3cf`, base `6875e0ce778aecfb2b83780c2185ce9273a9b2cc`.
- #76 / T020 / `bug/76-realbooru-original-metadata`: `b8895d1e142c6b0e86b4a1f7359e7288ecc6fee5`, same base.
- #111 / T021 / deleted `feature/111-android-update-flow`: historical `9ac4dd73b4c505c9c300a0e5fe43bf1ba0d06d07`, base `422aeae087c1108e655d85d1a3dac25120456cd6`.
- Current-instruction/develop comparison snapshot: `894ab270693cdb054a5d527c96182e21e2b14ffc`.

Current #53, #76 and #111 issue requirements were read. All three issues are closed; closure was not used to infer that any reported edge case was fixed. Source revision differences are stated below.

## AA02-C0008 — append does not invalidate the mixed-viewer preloader

**Kind: defect. Historical assessment: validated-static. Current presence: present in inspected develop. Severity medium / P2. Remediation: deferred-scope; a separately authorized current repair branch is required.**

At the historical #53 head, independently inspected `post_details_image_preloader.dart` source 1–225, `mixed_post_details_page.dart` source 40–220 and `post_details_scope.dart` source 100–205 under `lib/core/posts/details/src/widgets/`. The live source appends to its final mutable `_posts` list, retaining both the list object and the page index. The preloader's `didUpdateWidget` only calls `_scheduleRefresh` if list identity changes. Its existing-controller dependency path returns unless navigation has just resumed. Updating the details scope's total-page count is not an explicit refresh request. Consequently an append while stationary need not admit the new neighbor metadata.

Read the exact current-develop preloader source 1–180 and mixed-page source 85–170. The identity-only guard remains; the mixed-page blob is identical (`f52e76cad3e930afb9dc52762f2d5dfeb251fcc1`). Current ordinary-engine metadata optimization does not repair Realbooru append invalidation. A pending earlier metadata completion can dispatch some images, and a later page move can recover; neither guarantees admission of the appended neighbor. Do not describe this as permanent image loss or original-file permission failure.

Read the full queue and `test/core/posts/media_preload/preload_metadata_queue_test.dart`, and compared the #53 changed-file inventory. Those unit tests cover serial replacement, cached attempts and cancellation, not the live-viewer's mutable-list trigger. The original audit's inherited-origin distinction is retained: the branch adds an insufficient identity guard to a pre-existing refresh omission, rather than proving the entire omission originated there.

Local acceptance: mount the actual mixed viewer at a live-list end, append a distinct eligible neighbor without changing current page or navigation activity, and observe exactly one bounded admission for the new neighbor. Check append during an earlier in-flight resolution, inactive-route suppression, cross-profile grouping and the High/original-only ceiling. A saved prior length, bounded neighbor identity revision, or explicit content revision must not compare two references to the same already-mutated list. Revalidate current code before choosing the smallest fix.

## AA02-C0009 — unknown original plus explicit Original quality

**Kind: defect. Historical assessment: validated-static. Current presence: partly corrected; explicit profile-quality path remains. Severity medium / P2. Remediation: deferred-scope / local current-path verification.**

At the #76 head read the Realbooru HTML parser (`rb_parsers.dart`, source 45–160), the full `rb_image_metadata.dart`, full `lib/boorus/gelbooru_v2/posts/parser.dart` and `types.dart`, full shared `media_url_resolver.dart`, `RawPostDetailsImage` source 110–185, the default repository resolver selection and the absent-original parser test. A known sample without a trusted original produces `fileUrl == ''` and a nonempty sample. The engine URL resolver preserves that empty original. The historical default media resolver chooses it for explicit Original, and `RawPostDetailsImage` returns a placeholder for an empty selected URL. This contradicts #76's graceful-missing-rendition requirement without making the parser's honest unknown value wrong.

**Important current-source difference:** develop's resolver blob is `fd47ff7ac3bd9a02cc41cd89d7afa650c2f19132`, not the historical `d32aaad0de468dc050dc1ab264786494c946f470`. It now has `originalViewerImageUrl` and matching aspect-ratio fallback for global `PostQuality.original` when `config.imageDetaisQuality == null`. That common global-quality path is already corrected. However, the explicit `GeneralPostQualityType.original` switch arm still returns `post.originalImageUrl` directly. Current Realbooru parser source 65–112 still preserves an unknown original as empty; current GelbooruV2Repository does not introduce a media-resolver override.

Do not report all current Original-quality viewing as broken. Reproduce separately with global Original/default profile and with a retained/imported explicit profile Original value. The latter input's current settings/migration reachability needs local confirmation before prioritizing a current patch. Preserve empty/unknown metadata in stored Posts; any correction belongs in rendition selection and its aspect ratio, not fabricated original metadata. Test known original, sample-only, thumbnail-only, no URLs, GIF/video behavior and shared/download/prefetch consumers without raising the High network ceiling.

## AA02-C0010 — verified APK reference lost while a Flutter route covers the dialog

**Kind: defect. Historical assessment: validated-static. Current presence: present. Severity low / P2. Remediation: deferred-scope; #111 is integrated and its remote branch is deleted.**

Read `lib/foundation/app_update/src/widgets/app_update_dialog.dart` source 1–300 at the historical head and source 120–170 on current develop. Both return the same full-file blob `3f4cafc55fd1a5f3ef2ec96581b31bd92da65b56`. `_download` stores its verified result only if `_isCurrent && !token.isCancelled`. A second Flutter route can make `_isCurrent` false without disposing the dialog. The completed file is then unreferenced by `_apk`; after uncovering the dialog the primary action downloads again. `_downloadAndInstall` and `_install` legitimately require current/foreground state before Android UI, but retaining verified bytes has no equivalent UI side effect.

Read the full downloader and foreground test. The downloader uses a unique private directory and only deletes it when publication fails; a returned verified APK is retained. Its hash/size/cancellation checks do not restore the dialog's lost reference. Existing foreground tests explicitly pause/resume lifecycle and hold permission/settings Futures; those are not a second covering Flutter route. No real device, channel or downloader was executed here.

Local acceptance: delay download with a completion signal, push a second in-app route, complete verification, and assert no permission or installer UI while covered. Pop that route and use the original action; it must reuse the APK without a second download. Also test cancellation/disposal, denied/granted permissions, failed integrity and repeated background transitions. Retain result only for the still-valid mounted/cancellation lifetime, while keeping all installation launch guards. Review private-cache cleanup separately rather than deleting a file another native consumer may use.

### Signing-failure counter-evidence retained under C0010

Read current `android/app/src/main/kotlin/com/timberpile/boorusama/GitHubApkInstallPolicy.kt` in full and `GitHubApkInstallChannel.kt` source 70–185. The native channel actually invokes the policy before constructing the installer intent. The policy requires private-cache containment, exact package and expected version/build, a newer build, and equal nonempty signer sets. A debug/release certificate mismatch is therefore an expected rejection, not justification to weaken security. The auditor's reported historical device failure is not independently reproduced by this session and is separate from the verified-reference lifetime defect.

## AA02-C0011 — obsolete speculative work delays the next serial window

**Kind: risk / possible optimization. Assessment: likely latency trade-off; no additional correctness defect established. Current historical behavior: present by design. Severity low / P3. Remediation: not-needed without measured acceptance failure.**

Read full `PreloadMetadataQueue`, its queue test, `GelbooruV2Builder`, `GelbooruV2FullPostLoader`, and `gelbooruV2PostProvider` at the historical #53 head. Replacing the pending window does not cancel an already-running shared Future, so a later speculative request waits for it. The test explicitly requires this serialization. The visible full-post loader independently reads `gelbooruV2PostProvider(...).future`; it does not wait for admission through this speculative queue. Cancellation generation prevents publication of invalid old results.

This is not evidence that foreground details are deadlocked. Local measurements may justify changing speculative scheduling, but cancellation must not abort a Future the visible loader shares. Keep this separate from C0008, whose missing invalidation is a functional scheduling defect.

## AA02-C0012 — general HTML Size/Resolution label meaning

**Kind: external payload-contract risk. Assessment: uncertain. Current failing payload: not established. Severity low / P3. Remediation: needs-local-investigation only with representative evidence.**

The #76 metadata parser requires an identified original before returning dimensions/bytes, prefers explicit original attributes, ignores rendered image dimensions and rounded file sizes, and searches selected metadata containers for Size/Resolution/Dimensions labels. The original-metadata tests exercise that intended contract, including empty-original and ambiguous-link cases. They do not prove what every live site's generic label denotes. No contradictory valid Realbooru response was supplied or requested live during this session. Preserve the uncertainty; do not remove supported metadata or invent an alternate schema merely from an ambiguous label name. A redacted real fixture showing sample dimensions under those containers would support a targeted correction.

## Continuation

Five additional AA02 canonical records now have initial independent decisions. Source edits remain gated until C0003 and the remaining nonhistorical observations/integration claims are independently assessed. No fix, runtime pass or acceptance is claimed by this checkpoint. Preserve the current-versus-historical fallback distinction in all later matrices and handoffs.
