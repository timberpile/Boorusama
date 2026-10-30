# AA01 baseline continuation — 2026-10-30

This resumes report `865dc70accc917e5598689234e65edd36685602e` after a chat interruption. No application change, issue claim, SDK execution, analyzer, test, device operation or workflow launch is included. The eight source audit refs and implementation heads were refreshed and matched the frozen inventory. Current instructions were reread on develop `894ab270693cdb054a5d527c96182e21e2b14ffc`: AGENTS.md, issue/development workflows and repository verify-change/implement-change skills. The report ref was reread before publication.

These checks close the previously explicit AA01 pending-source-check rows. They do not close AA02's independent assessment gate or imply runtime verification. Earlier primary-source decisions remain in the branch records and version history; every original source ID remains in source-map.md.

## AA01-C0021 — withdrawn Search coverage hypothesis

**Assessment: rejected; current claimed absence: absent; remediation: not-needed.** At #116 head `5ac3ad9bc5f852f000012499c19468151c73734b`, inspected `test/core/search/following_topics/search_page_follow_action_test.dart` source lines 190–360. The real SearchPageScaffold suite includes widths 800/320/240, 2x text, count/share/Follow non-overlap, an actual Following destination-picker interaction and manual-only Follow at narrow width. This directly disproves absence of real Search integration coverage. The isolated compact-pill test is not the entire test suite. Execution on this branch remains pending. Preserve the original auditor's withdrawal rather than counting a current defect.

## AA01-C0024 — generic error recovery policy

**Assessment: proposal-only; current behavior: present; remediation: deferred-scope.** At #117 head `e2929259b7725c484d11483d6ea48270079eb2f4`, inspected `lib/core/posts/listing/src/_internal/sliver_post_grid.dart` source lines 1–200. Its retry action calls `postController.refresh()`; retry is offered for the listed retriable AppError/server cases, while UnknownError does not gain a dedicated button. Refreshed issue #117: it requires clear errors and correct cursor pagination, not preservation of scroll/cursor position by this generic Retry action. Restarting a read-only collection is not independently a proven defect. Session retry and shared Grid retry remain distinct. Local acceptance should exercise later-page failures and refresh deliberately; do not redesign generic error recovery without a concrete requirement. The separate initial-page skip defect remains C0020.

## AA01-C0025 — strict payload parsing / live contract

**Assessment: uncertain risk; current functional failure: not established; remediation: needs-local-investigation.** Read the full `packages/booru_clients/lib/src/pixiv/pixiv_client_bookmarks.dart` and `packages/booru_clients/test/pixiv/pixiv_bookmarks_test.dart` at #117's exact head. The parser requires a list of map entries and validates continuation origin, endpoint, account, visibility and cursor progress. Tests deliberately reject malformed scope/cursors and a missing list while preserving an empty continuing page. The supplied audits do not establish a legitimate endpoint payload rejected by these checks. No live endpoint request was made. Keep strict authentication/continuation checks; use a redacted real response or authoritative contract to validate any claimed incompatible artwork entry before relaxing validation. #118's separately inspected strict wrapper remains part of this same contract-risk handoff.

## AA01-C0030 — legacy setting hypothesis

**Assessment: rejected; claimed migration defect: absent; remediation: not-needed.** At #114 head `5bb52794468b172b7d6878fb825b42b00d654675`, read `lib/core/settings/src/types/settings.dart` source lines 1–240 and 620–930. ImageListingSettings preserves `showPostListConfigHeader` and independently reads/writes/copies/compares `keepTimelineToolbarVisible`, defaulting the latter to false. The old flag is explicitly documented as not implying pinning. This agrees with the already-read issue requirement and settings tests. No migration or backup rewrite is warranted.

## AA01-C0031 — captured Pool page-size preference

**Assessment: validated-static inherited defect; current presence: present; severity low; priority P2.** At #113 head `a1bc1d42903861a46e7230349515946bae678357`, read complete `lib/boorus/danbooru/pools/details/src/widgets/danbooru_infinite_post_id_list.dart`, `lib/boorus/szurubooru/pools/src/pool_detail_page.dart`, and `lib/core/posts/listing/src/widgets/post_scope.dart`. Both pool widgets watch postsPerPage and capture it in their fetcher. Their PostScope keys omit it: Danbooru uses order; Szurubooru uses `(pool.postIds, order)`. PostScope initializes a final controller/fetcher in initState and has no didUpdateWidget fetcher replacement; only page mode and blacklist are listened to. Therefore an otherwise retained pool scope keeps the old request stride after the setting changes. This establishes stale preference application, not an assertion that an already-running sequence suddenly uses mixed strides. The smallest candidate is to include perPage in each existing scope key; do not opportunistically redesign all source/account keys. Validate same-pool setting change, next-page and refresh behavior, order changes, filtered/missing IDs and disposal. No application fix has been published yet.

## AA01-C0032 — fork-local localization bridge

**Assessment: proposal-only; current bridge: present; remediation: deferred-scope.** Read full `lib/core/posts/listing/src/timeline_toolbar_l10n.dart` at #114 and `lib/boorus/pixiv/following/l10n.dart` at #118 head `1d02bef637966999fbd0b72ecb9c6f0e1eedce8a`. Both extend Translations, select the current locale language code, provide German and English fallback, and do not modify generated catalogs. Consolidating them into the standard catalog is a maintenance proposal, not a demonstrated functional failure. Do not fabricate generated output or add untranslated generator artifacts during this audit repair.

## Continuation point

AA01's 33 canonical records now all have an initial independent decision. AA02 still needs its own numbered and unnumbered primary-source assessments. Next inspect #68 pool identity/admission/filtering, #95 error handling, #112 menu invalidation, historical #53/#76/#111, and the remaining AA02 observations. Publish the complete cross-batch baseline and issue/coverage matrices before taking any implementation claim. No source-edit gate is opened by this checkpoint.
