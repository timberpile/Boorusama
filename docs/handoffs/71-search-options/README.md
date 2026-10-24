# Local handoff: search options and tag input

Issue: https://github.com/timberpile/Boorusama/issues/71

Branch: `feature/71-search-options`

Base: `fb1a5e3711c81f35a7f308d8f368dcfcfb97a801` (`develop` when work began).

## Local continuation

The original remote draft started at
`a8d4d3780755b64654ac538e1501c76a5b1f1b74`. The local continuation uses the
same branch in its isolated task worktree. See [verification.md](verification.md)
for the checked runtime commit, fixes, commands, complete suite results, device
checks and limits. No PR, code push, develop integration or issue closure is
authorized by this handoff.

## Localization and fresh-checkout setup

The original English/German manifests have been applied to the real locale JSON
files and committed in `714bdf73a`. Those original manifests added 60
`search_options` keys; subsequent follow-ups extend the real locale files. The manifests remain as the original change record;
**do not apply them again**. They are no longer an installation prerequisite.

For a fresh local checkout, initialize the pinned SDK, resolve dependencies and
generate missing ignored outputs:

```bash
fvm install
fvm flutter pub get
(cd packages/boorusama_cli && fvm dart pub get)
./gen.sh
```

Run generation only when outputs are missing or inputs have changed. Commit real
locale JSON changes, not generated translation accessors. Do not introduce
bracket/wildcard locale files: the repository CLI discovers root JSON basenames
as locale identities.

## What changed

An explicit tap on the Home search bar opens the keyboard; other entry points
honor the existing focus setting. A fresh editor keeps the source timeline
visible until the first confirmed search.
Its trailing down/up arrow explicitly toggles advanced options and dismisses the
keyboard on opening; focus alone does not open them. There is no closed-state plus or submit-search button, and
the final suggestion row accepts the active input as raw, with a RAW badge on
the right. Normal API matches precede it, and there is no no-match screen. Confirmed selection closes the
overlay and keyboard and updates results. Confirmed
mutations are coalesced by the post-search scaffold; unconfirmed typing and IME
composition are not committed. A raw chip edits only its own item and restores
the previous input on cancel. Shared non-post-search consumers retain their
explicit confirmation behavior.

Search Options, Favorites, Trending and History are collapsible. Search Options
show all available options in a bounded scrolling list, pins first, with rounded
compact rows, FREE badges, horizontal quick choices, a header-only catalog
and a local-draft graphical sheet with supported exclusions. Danbooru's existing
user pins are reused; other enabled profiles store pins by profile ID. No
bookmark, Topic persistence or favorite-tag redesign is included.

Tag suggestions come from the existing profile API/repository. Exact-query
results replace the global stale fallback; generation/disposal guards protect
pending work. API results appear before optional tag-cache enrichment. Existing
entity suggestions remain available for text options such as user.

Read [the design note](../../designs/2026-10-21-search-options.md) for capability
coverage and state boundaries. Danbooru/Gelbooru have the main graphical subset;
legacy Gelbooru, Moebooru and e621 currently add only verified rating choices.
Pixiv's user endpoint ignores concurrent free text, so it is not advertised as
a new composable GUI filter. Unknown/native input remains available. Separate
API-parameter sorting, exclusive endpoint scopes and a Between/range builder
are intentionally not implemented here.

## Review findings already corrected

- Danbooru newest sorting explicitly uses `order:id_desc`, not ascending `order:id`.
- Excluded duration comparisons retain inclusive boundaries (`NOT <7d` -> `>=7d`).
- Same-key replacement removes duplicate old items before replacement, avoiding
  deletion of an already present target. Opaque raw items are left intact.
- Cancel restores the prior input/raw mode; removed edit targets are not
  resurrected, including across profile snapshots.
- Late autocomplete/cache completion cannot overwrite another active generation;
  cached results no longer leak between profiles or unrelated input strings.
- Known incomplete option prefixes are protected even for engines without a
  metatag extractor; delayed text events cannot reopen a closed editor.
- The result header observes selected-item structure, not only the serialized
  query, so raw/typed conversion is reflected in share/Topic metadata.
- Slang sidecars were replaced with the repository-supported CLI manifests,
  rather than changing translation tooling in this feature.

## Historical remote verification (before the local continuation)

Relevant current source, caller APIs and repository guidelines were inspected.
The changed files underwent repeated manual reviews. Python checks validated
JSON parsing, English/German key parity and direct localization references,
trailing whitespace/final newlines, and lexical bracket/string/comment balance
for the changed Dart files. These checks are **not** a Dart parser, analyzer,
formatter, build or runtime test.

An attempt to run
`fvm flutter test --no-pub test/core/search/options` failed with
`fvm: command not found`. No Flutter/Dart tests passed or failed at runtime:
they did not start. No generated i18n outputs, device execution, CI verification
or complete regression run was available. Do not reuse this handoff as evidence
of a successful test gate.

## Required local checks

After localization/generation, format the changed Dart paths and inspect the
resulting diff. Run analysis and the focused tests, then the complete required
suite because shared search/controller/suggestion behavior changed:

```bash
base=fb1a5e3711c81f35a7f308d8f368dcfcfb97a801
git diff --name-only -z "$base" -- '*.dart' | xargs -0 fvm dart format
fvm flutter analyze
test_workers="$(python3 scripts/physical_core_count.py)"
fvm flutter test --no-pub "--concurrency=$test_workers" \
  test/core/search/options \
  test/core/search/search_profile_switch_test.dart \
  test/core/search/navigation_search_profile_test.dart \
  test/core/search/search_history_profile_test.dart \
  test/metatag_regex_test.dart
./scripts/run_regression_tests.sh
git diff --check
```

Five new test files cover option serialization/negation, mutation coalescing,
raw-item lifecycle/profile snapshots, collapsible/sheet behavior and exact
profile/query suggestion scope. The original draft had not compiled them; the
local results are recorded above. Fix real defects;
do not weaken assertions simply to obtain a pass. Add integration tests for the
actual request lifecycle and async ordering if the existing test harness does
not already cover them. The seeded suggestion test alone does not exercise
network/cache completion races.

Pay particular attention to first-query creation, rapid consecutive changes,
pagination reset, old request cancellation, applying an empty search after the
last removal, and explicit refresh paths. `SearchAutoCommit` coalesces one
logical frame's changes. Each applied query now owns a distinct post scope,
so old responses cannot enter the new query and pagination restarts at page one.
Ensure completed input of each origin causes one appropriate
refresh and never displays late results from a previous query/profile.

Exercise the existing non-post-search tag pickers and Topic editor as consumers
of shared components. Their data and confirmation semantics must not regress.
Check saved searches, favorite tag insertion, share links, Follow Topic,
profile switching with a pending raw edit, and removal of the item being edited.

## UI and live-site acceptance

Read `docs/android_emulator.md` and acquire the exclusive lease before using an
emulator. Use Maestro MCP as instructed. Test credentials are already local;
never expose them in logs, screenshots, commits or issue comments.

Check narrow widths (including 320 px), enlarged text (at least 2x), keyboard
open/closed, and both top/bottom search bar settings. Reopening each collapsed
section must preserve its management action. Dialog Apply/Cancel and the
catalog must remain reachable without overflow. The raw suggestion must follow normal matches, carry a right-aligned badge and
remain available for pending, failed and empty autocomplete responses. There
must be no raw toggle beside the input. Confirm that accepting
a tag keeps the intended input workflow usable with both touch and keyboard.

On Danbooru: normal tag autocomplete (including `one piece`), `age:` presets,
exclude last seven days, exclude Questionable, score comparison, and newest/
highest-score sorting. On Gelbooru: native rating/sort syntax, with no fabricated
Danbooru age options. Check configured legacy rating sites without assuming all
engine clones share the same feature set. FREE reflects existing repo metadata;
do not reinterpret the badge as an account entitlement or fabricate tag counts.
Use actual site data for the device acceptance checks and deterministic external
fakes for isolated unit/widget tests.

## Completion/reporting

Commit local fixes and the applied translations on the same task branch. Run the
appropriate checks again after changes; run the full final integration candidate
before calling it ready. Inspect the full base-to-head diff, not just the latest
fix. Record the checked commit, commands, results, skipped tests, device checks
and remaining scope limits in the issue/handoff. Keep #71 open until publication
is authorized, and explicitly blocked while required checks are incomplete.
Record any concrete blocker on the issue. No PR or develop merge is authorized
by this handoff.
