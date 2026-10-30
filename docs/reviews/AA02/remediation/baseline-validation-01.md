# AA02 independent baseline — Pool, artist sharing and viewer controls

Status: partial independent baseline, not remediation or acceptance. The global source-edit gate remains closed. Original claims and all source audit SHAs are preserved in [source-map.md](source-map.md); target identities are in [audit-inventory.md](audit-inventory.md). AA01's completed initial decisions are pinned at report `896baacf5bb64fba43a355580742e0d821f89d17`. Every test mentioned below was read, not executed.

## Exact inspected implementation revisions

- T008 / #68 / `feature/group-neighboring-series`: `771082d9c58363348d74b97a2da23732cdd921f0`, merge-base `482ae4b1e5fd1e34b344a5c61959a210b8527281`.
- T007 / #95 / `feature/95-artist-links`: `7fa4e4f7fadd28cdf332c6855ac18e4fd28b3e9a`, base `422aeae087c1108e655d85d1a3dac25120456cd6`.
- T009 / #112 / `feature/112-viewer-toolbar-layout`: `8213b6fbb87cb09d30d5056ad6667821371f22f6`, same base.
- T010 / #107 / `feature/107-local-post-sorting`: `7a73544cb79c9f5e3c2337a08140833024a31591`, same base.

The task heads matched the frozen inventories at resumption; they must be refreshed again before any write. The source revisions above are the actual inputs to these decisions, not an assertion of a later moving branch state.

## AA02-C0001 — same-host Pool reference identity

**Kind: risk. Assessment: likely policy-sensitive inconsistency, not an independently established account-isolation defect. Current behavior: present. Severity medium / P2. Remediation: blocked-product/data-model-decision.**

Read current issue #68, its linked agreed-scope record `docs/designs/2026-10-21-issues-and-pool-bookmarks.md` at `0d2cbfc6bd09c0d26789d24552ca496855791b53`, and the branch's `docs/designs/2026-10-21-pool-series-bookmarks.md`. Independently traced full `pool_bookmark.dart`, `pool_bookmark_button.dart`, `pool_bookmark_provider.dart`, and `bookmark_provider.dart` source lines 220–330. Identity is exactly `(sourceTypeId, origin.sourceHost, poolId)`. Button/draft lookup reuses that same-site remote reference; group add/remove acts on its identity. The opener separately preserves the originating profile hint and refuses a different account when that hint no longer resolves. Therefore the auditors' two-profile alias/toggle sequence is reachable, but it is not credential borrowing.

Counter-evidence matters: the agreed design describes a shared mixed bookmark library and a source-aware remote reference with a profile/source **hint**. It does not explicitly require separately saved references for every account at one site. `test/core/bookmarks/pool_bookmark_source_policy_test.dart` explicitly expects profile-hint remapping to preserve Pool identity. Calling this a proven violation assumes a product policy that those requirements do not settle. A source-global reference with a pinned opener is also a coherent interpretation, although its cross-profile picker behavior needs acceptance.

Do not add profile IDs to persisted identity speculatively. Local/product acceptance must decide between site-global references and per-profile references, exercise same-host A/B add/remove/Undo/open/refresh, removed hints and backup remapping, and then update UI semantics or the entire persistence/import identity contract coherently. Preserve all reporting agents' stronger original conclusions and the counterposition; vote totals do not resolve policy.

## AA02-C0002 — Series admission remains a fixed first-40 prefix

**Kind: defect (bounded visual grouping coverage). Assessment: validated-static. Current presence: present. Severity medium / P2. Remediation: needs-local-investigation for a bounded viewport-aware correction.**

Read all of `bookmark_scroll_view.dart` (source 1–end), the relevant Pool design and `pool_bookmark_test.dart` source 1–255. `_synchronizeEntries` schedules `_warmSeries` once after a refresh; `_warmSeries` takes the first `membershipBudget` Post entries before checking cache/source eligibility. No later scroll/builder path admits another window: the item builder only extends `_frozenUntil`. Posts beyond the first 40 cannot acquire membership through this path, even when subsequently visible; refreshing repeats that prefix. Cache hits do not move admission beyond it. This is not a reason to remove the network budget.

The existing frozen-built-entry behavior is intentional and tested; active tag/source filters intentionally avoid new network work. A safe correction must prefetch bounded, newly relevant unseen entries, retain the four-profile and cache limits, invalidate obsolete generations and preserve already-built anchors. A 50+ Post real-widget test must prove later-Series admission and bounded calls, plus selection expansion, sort/profile/filter changes and out-of-order responses. A blanket full-library loop would violate the agreed constraints. No patch has been published.

## AA02-C0004 — More menu dismissed on regenerated button lists

**Kind: UX/state risk. Assessment: likely nuisance path, not a demonstrated invalid safety guard. Current behavior: present. Severity low / P3. Remediation: needs-local-investigation.**

Read full `customizable_post_toolbar.dart`, the actual Danbooru toolbar producer and its watched favorite/vote/profile inputs, `docs/designs/2026-10-29-viewer-toolbar-layout.md`, and `configured_post_toolbar_test.dart` source 180–end. `didUpdateWidget` hides the menu whenever the layout or button-list identity changes. Producers construct fresh lists, so same-post rebuilds can dismiss the overlay.

However, that guard deliberately prevents obsolete callbacks/auth/loading state. An explicit test requires dismissal when callbacks change while action IDs remain the same; the design does not guarantee retaining an open menu through every such update. Do not replace the guard with action-ID equality alone. Local reproduction must distinguish a genuinely benign update from changed action state, then demonstrate an overlay update strategy that preserves fresh callbacks/account scope and nested quality-menu behavior. Keep the auditors who judged this intentional separate from those reporting it as a defect.

## AA02-C0005 — alleged unhandled native share UnimplementedError

**Kind: reported defect. Assessment: rejected. Claimed current path: absent. Severity low / P3. Remediation: not-needed.**

Read current #95 requirements, full `share_artist_link_button.dart`, `boorusama_link_file_share.dart`, `shares/src/share_action_adapter.dart`, `artist_link_share_button_test.dart`, and `share_action_adapter_test.dart` at the exact #95 head. The claim's premise fails: the concrete, final `ShareActionAdapter._share` catches `UnimplementedError` from the native invoker and returns `ShareActionOutcome.unsupported`. Document sharing calls this adapter's `shareFiles`; the Artist button explicitly shows its failure toast for every outcome other than success/dismissed. Its `finally` restores the busy state. The adapter suite already includes an unsupported-invoker test, though not an end-to-end Artist failure assertion.

The sibling Search handler's additional catch is not evidence that this native failure escapes. No speculative filesystem failure should be substituted for the original reported trigger. Preserve original AA02-A03-F0001 and its two review-cycle claims, but do not add a redundant production catch as a purported repair. Local revalidation should inject the unsupported invoker in the actual Artist header and verify toast/re-enable behavior, not merely trust this rejection.

## AA02-C0006 — #68/#107 mixed-grid score ordering

**Kind: integration risk. Assessment: likely, supported by deterministic projected composition. Current presence: no combined candidate. Severity medium / P2. Remediation: blocked-separate-integration.**

Read #68 `bookmark_grid_entry.dart` and `bookmark_group_selectors.dart`, and #107's complete relevant selector implementation (source 1–250). #107 appends scoreAscending/scoreDescending and sorts Posts accordingly. #68's mixed selector re-sorts every non-random, non-upload mode by savedAt when any Pools are present. If those implementations are composed unchanged, the second sort overwrites Post score order; #68 alone has no score enum values, and #107 alone has no mixed Pool selector. Do not claim a reproduced failure on either standalone branch or merge unfinished dependencies here.

At separately authorized integration, define placement of scoreless Pool references, retain deterministic tie behavior and known/unknown upload-date semantics, and test a mixed library where score, upload date and savedAt have different orders. Do not invent aggregate Pool scores or fetch remote scores while sorting.

## AA02-C0007 — source filter uses host substrings

**Kind: defect. Assessment: validated-static. Current presence: present. Severity low / P2. Remediation: focused candidate after baseline and ownership.**

Read full `bookmark_grid_entry.dart`, `bookmark_group_selectors.dart`, `bookmark_booru_type_selector.dart` and `local_providers.dart`. The menu supplies exact `Uri.host` values. The Pool predicate uses `('https://${pool.origin.sourceHost}').contains(selectedBooruUrl)`; the older Post predicate uses `bookmark.sourceUrl.contains(selectedBooruUrl)`. Consequently `booru.example` also admits `notbooru.example` or a matching URL path. This is local filter correctness, not a demonstrated credential leak. The new Pool path reproduces a pre-existing Post predicate problem.

Compare parsed hosts exactly using the existing menu's host-only contract. Do not silently change that UI to profile-, engine- or port-level filtering. Tests should cover both overlapping hosts, subdomains, case normalization, paths containing the selected host, null selection, mixed entries, group/tag constraints and same-host explicit ports. The available Pool selector tests inspected cover tag and date behavior, not this adversarial source pair.

## AA02-C0020 — disabled vote removal hypothesis

**Kind: withdrawn/rejected defect hypothesis. Assessment: rejected. Claimed current enabling defect: absent. Remediation: not-needed.**

Read full `votes/src/vote_post_button.dart` and the actual Danbooru toolbar at the #112 head. When the vote is already active and no removal ID/callback is available, `onPressed`/menu `onTap` are null. The generic descriptor also sets enabled accordingly. The menu presentation does not manufacture an active removal operation. Device semantics and ordinary vote transitions remain acceptance checks, not evidence of this claimed bug.

## AA02-C0032 — import preview versus actual profile-hint mapping

**Kind: rejected hypothesis. Assessment: rejected for the reported discrepancy. Current claimed mismatch: absent. Remediation: not-needed.**

Independently read `import_flow_notifier.dart` source 1000–1445 and `import_planned_change_projector.dart` source 340–590 at #68. Actual `_applyBookmarks` first maps selected incoming Pool hints through approved preflight, applies the group import, and then updates surviving stored Pool hints by identity. The projector likewise preserves existing metadata while applying the mapped hint to the projected Pool. The initial service merge alone is not the full transaction. The post-apply step defeats the hypothesized discrepancy; this is not a universal proof of all import combinations. Source policy tests independently expect hint remapping to preserve identity. Local backup tests still must cover preview/actual equality, merge/update/copy/replace and rollback.

## Scope and continuation

No ownership claim or application edit was made. The #68 identity-policy question does not block independently supported host-filter work once the global baseline is complete. Rejected #95/#112 hypotheses do not authorize unrelated changes. Historical #53/#76/#111, AA02's remaining unnumbered observations, and distinct Pixiv visibility variants still require independent source decisions before the source-edit gate can open. Preserve AA01's prior decisions and do not repeat ingestion of all 168 audit files.
