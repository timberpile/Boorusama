# Issue #122 full-gate remediation

Refs #122. Extends the drag-handle candidate
`daf43f30c2787f4941459c2d367e8ca8534fdeb5`; its gesture exclusion remains intact.

The first cumulative full gate found a provider ancestry cycle in profile add:
BooruConfigNotifier read orderedProfileConfigsProvider, which depends on the same
notifier. Riverpod rejected the read, so profile persistence succeeded but order,
current selection and success callbacks did not complete. Duplication tests waited
for a settings write that never began. Independent investigation reproduced the
add failures on this original issue branch, excluding a replay regression.

The shared ordering projection is now a pure function. Both the derived provider
and the notifier use it; the notifier passes its own state and stored order.
Early publication, stale-ID fallback, deduplication and stable unordered profiles
retain their existing behavior.

Plain link/import/cross-profile widget fixtures now initialize settings required
by shared presentation ordering. Two fixtures used the same ID for different
accounts/sites; they now use distinct IDs. No assertions or timeouts were weakened.

## Verification

Existing full-gate regressions failed before the correction. Final command:

```sh
fvm flutter test --no-pub --concurrency=6 test/booru_config_notifier_test.dart test/profile_duplication_publication_test.dart test/core/configs/profile_order_test.dart test/core/posts/links/boorusama_artist_link_page_test.dart test/core/posts/links/boorusama_post_link_page_test.dart test/core/posts/links/boorusama_group_link_page_test.dart test/core/posts/links/boorusama_search_link_page_test.dart test/core/backups/export_import/import_flow_page_test.dart test/core/backups/export_import/data013_profile_mapping_layout_test.dart test/core/settings/profiles_entry_test.dart test/application/profile_management_context_menu_flow_test.dart test/cross_profile_lookup
```

**265 passed**, including hold/cancel/drag-handle exclusions. The smaller preceding
consumer run passed 95 tests. Independent review found no remaining defect in the
runtime correction or fixture changes. Logs are in
`.worktrees/_artifacts/pre-release-remediation-20261117/122-*.log` and
`profile-order-owning-branch-diagnosis.log`.

The final cumulative report records complete regression/native results. No device,
emulator, live profile connection or Android acceptance was performed.
