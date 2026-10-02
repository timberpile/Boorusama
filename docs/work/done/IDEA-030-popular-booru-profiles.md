# Add popular-site quick profile setup

Priority: Normal

Affected feature: Profile creation; branch `feature/popular-booru-profiles`

## Problem

Creating a profile currently starts with an empty URL field. New users must
already know a site's address, and the page does not explain whether that site
can be used immediately or requires account credentials.

## Expected behavior

The first profile-creation step offers a lazily rendered list of popular sites
from the registered booru metadata. Each entry has a useful default profile
name and shows a small `Account required` badge on the right of the name only
when credentials are required. Optional and unnecessary account states show no
label or extra row. Site rows have no URL subtitle or descriptions. Choosing
an entry prepopulates its engine, URL, and profile name. The existing custom
URL flow remains available.

The picker reuses the cached website-logo pipeline. It must retain the bundled
Danbooru and Hydrus icons and must not eagerly construct or fetch logos for
off-screen entries.

## Acceptance criteria

- [x] Only complete, explicitly registered quick-setup metadata becomes a
      picker entry; missing or invalid metadata is handled safely.
- [x] Required accounts have a localized badge aligned with the site name;
      optional and unnecessary accounts have no authentication label or row.
- [x] Selecting a known site prepopulates the exact engine, URL, and useful
      profile name.
- [x] Custom URL setup remains reachable and behaves as before.
- [x] Site rows use `ConfigAwareWebsiteLogo` and are built lazily.
- [x] Bundled Danbooru and Hydrus icon behavior remains intact.
- [x] The picker is usable at narrow width, large text scale, and through
      accessibility semantics.
- [x] Focused tests, static analysis at baseline parity, the full test suite,
      and Android Maestro validation are recorded before completion.

## Constraints and dependencies

- Authentication labels come from repository-owned site metadata, not a live
  probe or an inference from whether credentials happen to be present.
- Manual/custom engines and URLs remain supported.
- User-facing strings use the i18n resources.

## Claim

- Agent/session: `/root/implement_30`
- Work branch: `feature/popular-booru-profiles`
- Worktree: `.worktrees/ready-30-popular-booru-profiles`

## Progress

- 2026-10-02: Claimed and inspected the existing URL-first flow, registered
  booru metadata, engine-specific creation builders, and favicon behavior.
- 2026-10-02: RED failed because the quick-site catalog, picker, and profile
  name prepopulation did not exist. Implemented an explicit `quick-profile`
  block in registered site metadata and a catalog that ignores incomplete or
  invalid external metadata.
- 2026-10-02: Authentication classifications follow existing engine behavior:
  Gelbooru, Rule34, and Pixiv require credentials; engines with an optional
  auth tab are labeled optional; engines whose creation flow is anonymous-only
  are labeled no-account-needed. This is static repository metadata, not a
  runtime credential or network guess.
- 2026-10-02: Focused GREEN passed 16 tests covering catalog parsing, every
  auth state, legacy creation links, selection and name prepopulation, custom
  setup, lazy rows, narrow/large-text layout, semantics, and bundled icons.
  `fvm flutter analyze` reports the unchanged baseline of 227 info findings and
  no errors or warnings. Full-suite, Android build, and Maestro verification
  remain for the final serialized verification gate.
- 2026-10-02: User-approved minimal follow-up removes URL subtitles and
  optional/unnecessary authentication labels. Required sites have a small
  badge on the right, vertically centered with the name. Long names use an
  ellipsis while accessibility retains the complete site name and required
  account label; the badge wraps within its constrained width at large text.
  Expected RED observed for residual optional labels, missing inline badges,
  and right alignment. Focused GREEN passed 18 tests, including equal row
  heights without residual auth rows, 240/320px width at 2x text, full semantics,
  selection, custom setup, lazy logos, and bundled icons. Full-suite and Maestro
  verification remain coordinated by the root agent.
- 2026-10-02: Device QA requested a compact-layout correction at 320x640 and
  Android font scale 2.0. The badge had unlimited wrapping and scaled as much
  as the name, yielding four lines. A Roboto-backed regression is RED on the
  previous layout (136px badge height versus the 48px maximum) and GREEN with
  a two-line limit, smaller conditional padding, and badge text scaling capped
  at 1.2. The name retains the full accessibility scale and at least 100px at
  320px width. Added the longer German label `Benutzerkonto erforderlich`;
  English and German labels fit fully within two lines with complete semantics.
  Tests load Roboto from the configured Flutter SDK because Flutter's default
  Ahem font gave unrealistic wrapping and a header-overflow false alarm. The
  full picker now passes at 240/320x640 with 2x text, not just the isolated row.
  Focused GREEN passes 20 tests; repeat device verification remains with root.
- 2026-10-02: Review found the custom URL step's `Create a new profile`
  heading vertically centered under full-height page constraints. The focused
  regression failed at y=190px before removing the inherited centering and
  passes with the heading in the top 100px. The 10 picker widget tests and
  changed-file analysis pass. Full-suite and device checks remain for the
  coordinated final gate.
- 2026-10-02: Integrated verification passed all 21 quick-profile and website
  logo tests. Targeted analysis of the eight touched Dart files reported no
  issues, and `./gen.sh` completed without additional tracked output. The
  isolated branch also passed its full suite and Android/Maestro checks before
  user approval.
