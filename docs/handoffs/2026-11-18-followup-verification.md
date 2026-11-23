# Favorites, Pools, viewer, and Following follow-up

The local branch starts at `cec8ed309`, which carries #166 and the Group
display-receipt fix. It includes the completed ASAP bundle through
`83120e31b` and `d354e74b8`. Profile-limit and main-profile work is deferred.
Develop has since advanced through #134.

- Realbooru collects paginated Favorites HTML before saving memberships.
  Preview-only snapshots carry an explicit storage marker. Exact detail
  resolution revalidates the reader and visibility policy, and local upgrades
  preserve the bookmark identity and dates.
- Donmai Safebooru evaluates up to three candidates per Pool and 60 distinct
  IDs per 20-row raw page. Proven-empty Pools are suppressed in discovery.
  Unknown and saved Pools retain navigation, and raw page progress is
  independent of the accessible count.
- The mixed viewer prepares both immediate Group neighbors and shares the
  actual first member batch with the selected gallery. Passive previews have
  no gallery actions or display acknowledgement.
- Following holds an accepted display snapshot until Show Updates. The
  background scheduler and stored read state remain active. Local cache
  generations protect feed destinations from pre-reset refreshes and survive
  transactional rollback.

## Verification

The checked source tree is `11000c6dc0b563df3773d519c0b158fa7fec25fc`.
The final commit also contains this verification record.

- Focused tests passed for 248 Pool, viewer, Following, backup, and bookmark
  cases. The bookmark hydration suite passed all 40 tests.
- Changed Dart files formatted with `fvm dart format`.
  `fvm flutter analyze --no-pub --no-fatal-infos` reported zero errors,
  zero warnings, and 177 informational findings.
- The Realbooru integration fixture recorded one populated listing read,
  one terminal probe, and zero Post detail or media requests during import.
  Public Favorites markup was inspected on 18 November 2026.
- `./scripts/run_regression_tests.sh` passed 7,819 application tests,
  1,727 package and CLI tests, both repository shell suites, and
  76 Python tooling tests. Two package tests were skipped.

Android device behavior, in-place upgrade, and authenticated live services
remain unverified. When exact Realbooru detail HTML omits facts required by
the selected visibility policy, the saved item remains preview-only.
