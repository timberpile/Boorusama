# Issue #64 — Related Tags sorting and existing API totals

Branch: `feature/64-artist-page`.
Baseline: `ad046a6ea`.
Related Tags offers both By count and A–Z sorting, displaying the tag-wide
post totals already supplied by the Related Tags response. This replaces the
previous fixed alphabetical order and supersedes the intersection-count behavior
described in earlier Issue #64 handoffs.

The sheet uses the existing Kurumi segmented control. By count defaults to
descending tag-wide totals with alphabetical ties; A–Z sorts by tag name. The
chosen order is remembered while the Artist Page remains mounted. Counts use
the nested tag DTO's `postCount` directly, formatted compactly, with a tooltip
describing posts with this tag. Missing/synthetic zero totals remain omitted, as
in the original design. Long labels retain room for their count at enlarged text.

Both sorts run locally on the existing list. Opening, switching sorts and
reopening perform no post-count requests or additional Related Tags lookups.
The dedicated artist/tag count provider remains deleted. The existing Related
Tags lookup and its maximum 30 selected tags remain. Tag actions continue to use
the originating profile.

Verification on the runtime/test state committed alongside this report:

- All three changed Dart files formatted; `git diff --check` passed.
- `./gen.sh i18n` passed validation and regenerated ignored localization output
  after correcting the English count tooltip to describe tag-wide totals.
- Analysis passed with no issues, exit 0:

  ```bash
  fvm dart analyze \
    lib/boorus/danbooru/artists/artist/src/widgets/artist_related_tags_sheet.dart \
    lib/boorus/danbooru/artists/artist/src/widgets/artist_details.dart \
    test/boorus/danbooru_artist_page_test.dart
  ```

- **124 tests passed, no skips, exit 0**, using six physical cores:

  ```bash
  fvm flutter test --no-pub --concurrency="$(python3 scripts/physical_core_count.py)" \
    test/boorus/danbooru_artist_page_test.dart \
    test/boorus/danbooru_artist_follow_test.dart \
    test/boorus/danbooru_artist_identity_test.dart \
    test/boorus/danbooru_artist_socials_test.dart \
    test/boorus/danbooru_artist_banner_test.dart \
    test/boorus/danbooru_artist_url_presentation_test.dart \
    test/boorus/danbooru_secondary_route_scope_test.dart \
    test/boorus/danbooru_post_count_test.dart \
    test/core/posts/details/source_detail_facts_ui_test.dart
  ```

  Updated coverage verifies descending global counts from the existing DTO,
  switching to A–Z and back, remembered order after reopening, correct count
  tooltips, omitted unknown counts, one Related Tags lookup and zero count
  requests throughout. At 320 dp with 2x text, long labels retain a visible
  compact count and both sort controls remain usable. Existing profile-scoped
  tag search, responsive page, follow, banner, Socials and count-repository
  consumers pass. The known native hook `File modified during build` message
  remains nonfatal; no tracked generated output changed.

No APK build or device run was performed for this scoped widget change;
the checks above are automated host/widget verification. The complete local
application/package/CLI/tooling suite remains required on the final combined
candidate before develop integration.

Changes are committed locally with `Refs #64`. No push, PR, merge or issue closure
was performed. The primary checkout remains untouched.
