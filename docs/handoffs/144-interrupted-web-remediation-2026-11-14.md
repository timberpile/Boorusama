# #144 — Local continuation after interrupted web remediation

## Latest delivery — complete MiteMite naming (2026-11-17)

Pushed runtime **`8b840e9706d610028952e834cbd540bbffc17c89`** on `feature/144-folder-based-collection-sync`. The owner confirmed that the feature is unshipped and requested a complete rename without a naming migration, compatibility aliases or previous-name fallback. Existing development state in the former namespace is not imported. No installation or device data operation was performed.

Source/test directories, feature-specific types/providers/constants, translation namespaces, native Kotlin classes and channel, notification payload prefixes, persisted preference keys and private-directory names now use MiteMite consistently. The naming conventions are `mitemite` for paths/keys, `MiteMite` for types and `miteMite` for lower-camel symbols. Imports, fixtures, documentation paths and links were updated; conflicting naming instructions are superseded in the canonical specification and module README. Existing protocol versions, serialization structure, journal/safety mechanisms, source ownership and reading behavior are otherwise unchanged. The existing private-store migration mechanism is retained; no migration between naming schemes was added.

### Verification of the current runtime

- `./gen.sh i18n`: validation and generation passed. Changed Dart files were formatted. Tracked filename/content and generated-localization audits found no previous feature-name variants. A comparison of 112 runtime/test/resource files confirmed mechanical renaming plus formatting; the additional native instrumentation assertion checks the new channel name. Documentation checks examined 65 links with no newly missing targets; mockup JavaScript syntax and `git diff --check` passed.
- Focused MiteMite and Following presentation tests: **344 passed**, exit 0.
- `./scripts/run_regression_tests.sh`: **7,574 application tests + 1,711 package/CLI tests across all 13 suites passed**, both shell suites and **76 Python tests passed**, **exit 0**. The **two existing Go Router skips** remain. No interrupted or partial run is used as final evidence.
- `fvm flutter analyze --no-pub`: **0 errors, 0 warnings, 4,270 informational findings**, **exit 1**; not a clean analyzer pass.
- Java 17 `./gradlew -I <artifact>/force_native_unit.gradle :app:testProdDebugUnitTest :app:assembleProdDebugAndroidTest --console=plain`: **exit 0**. The init script forces fresh JVM test execution rather than reusing cached test results: **52 tests / 9 suites, zero failures/errors/skips**. The renamed native channel and `MiteMiteDocumentsProviderTest` compiled; instrumentation tests were **not executed** on Android.
- `fvm flutter build apk --debug --flavor prod --target-platform android-x64 --no-pub`: **exit 0**. APK SHA-256: **`88ff97d3d3e6edff7d4ddb151d8a35d7b5951d99a257c3d7be4ff42d5d42683f`**. An APK DEX/kernel audit found no previous-name variants and confirmed the new native class, MethodChannel and identity namespace. The APK was built from the candidate subsequently committed above, with identical runtime/test inputs.

Runtime/test-input SHA-256 stayed **`db0f4c77026bfba83f9ad1af20a21275ef8de7fb51e52f051e72f9ea36911aab`** across build, complete regression and the committed state (**5,352 inputs**, including generated localization). Subsequent handoff/specification edits are documentation only. The complete runner used the detected **6 physical cores** with no concurrency override.

Durable evidence: `.worktrees/_artifacts/144-mitemite-rename-2026-11-17/`, including `rename-manifest.json`, `rename-audit.json`, `documentation-links.json`, `generation.log`, `format.log`, `focused.log`/`.exit`, `regression.log`/`.exit`, `verification-results.json`, `analyze.log`/`.exit`, `native.log`/`.exit`, `native-results.json`, `force_native_unit.gradle`, `android-build.log`/`.exit`, `apk-audit.json` and matching `inputs-*.json`. Existing VM/locale and Gradle diagnostics do not replace the recorded command/assertion results.

**Limits:** Host tests, native compilation and the APK audit do not establish native SAF/system-UI behavior, two-device delivery, live-service acceptance or owner live-device performance. No emulator or protected-device operations were performed. No merge, PR, release or issue closure was performed.

> Naming normalization (2026-11-17): Historical paths and symbol references below use current MiteMite names. Recorded commit IDs and verification results are unchanged; consult the original commits for exact historical commands and artifact locations. These reference edits do not requalify earlier evidence.

## Final verified owner follow-ups — 2026-11-16

**Implementation and authorized host/emulator acceptance are complete.** Qualified runtime: **`d8ee9a269e50183d52c3052a48b84e4d3b82e35a`**, pushed on `feature/144-folder-based-collection-sync`. Subsequent edits in this delivery are documentation only. No PR, merge into develop, release or issue closure is authorized or performed. Owner live-device performance acceptance remains the owner's task, as requested; it was not substituted with profiling or benchmarks.

The final notification copy is implemented (`b5ce432f5`), receiver-private Group/Following-folder aliases are implemented (`974684295`), and native enlarged-text QA led to the shared-popup placement/lifecycle corrections (`08d62766c`, completed by `d8ee9a269`). The two tasks formerly listed as OPEN below are now complete. Existing source ownership, canonical names, identities, subscription coverage, journals, anti-rollback, read/arrival state and source definition integrity are preserved. Following Topics have no new alias capability.

### Final frozen-candidate verification

| Check | Actual result on `d8ee9a269` |
| --- | --- |
| Complete local runner | `./scripts/run_regression_tests.sh`, detected concurrency **6**, exit **0**; clean unchanged runtime before/after. **7,540 application + 1,711 package/CLI tests across 13 suites**, both shell suites and **76 Python tests** passed. |
| Analysis | `fvm flutter analyze --no-pub --no-fatal-infos`, exit **0**: **0 errors, 0 warnings, 4,225 infos**. |
| Native unit tests | Fresh forced execution of `:app:testProdDebugUnitTest` with the ignored `force_native_unit.gradle` init script: **52 tests / 0 failures / 0 errors / 0 skipped**, exit **0**. Only documentation differed from the frozen runtime before/after. |
| Real Android SAF/provider tests | Final APK and current instrumentation harness on leased emulator-5556: **14 passed**; task test harness removed afterward. |
| Source-corresponding APK | `fvm flutter build apk --debug --flavor prod --target-platform android-arm64,android-x64 --no-pub`, exit **0**. Both independent prod installs match SHA-256 **`d32531eabeceea9762e27f49577624b68fcce211d6c105cdd5ad4eecc0762457`**. |

The APK/harness build invocations reported the native unit target `UP-TO-DATE` against unchanged native inputs. Those invocations reused its stored results. The separate final host run disabled up-to-date/cache reuse for **only that test task**, actually executed it, and passed all 52 tests (`native-unit-final-fresh.{json,log}`); dependency tasks kept their normal caching.

The complete runner retains two pre-existing go_router skips and **59 native Dart VM callback/finalizer diagnostics**, with no failed-test markers. The popup lifecycle correction separately passed all **227 Kurumi tests**, **80 affected real-provider/Feed tests**, and changed-file analysis with **no findings** before this final full pass. Earlier failed/stopped runs are explicitly excluded below; they are not reused as final-candidate evidence. i18n validation/generation and Dart formatting were completed during implementation.

### Independent Android and two-device results

Only leased **emulator-5554** (receiver D) and **emulator-5556** (publisher C) were operated on. Their independent prod identities remain `99c6fc2f-d8a3-4f77-a394-e500c02f67bf` / fingerprint `747fd81c4fa32d77d2603dbed1dadf79d1cb38f7ea5fb5d07dd1fa16c9c01a07`, and `ea999d83-8ef6-4ea1-b184-e4cc61195b0e` / fingerprint `028ab5cdf1e5a352add3bae0919c395d0f2a0681fe04cf10abb8926c462a18ce`. Every upgrade was in place from a complete app/cache/no-backup authority checkpoint. All private values matched immediately across each upgrade; final serialized signing identity and settings match the initial baseline on both devices. Original dev APKs, their public identities and notification permission flags are unchanged. Protected physical devices were untouched.

- Root/nested Group cards, opened titles and ancestor aliases were exercised on the initial alias runtime `974684295` (Maestro flows **20/22**), and Following folder aliasing on **24**. Their code is retained in the final runtime; its complete widget/provider suite covers these paths. Final-runtime cold restart retains all three private aliases and both Group Unseen counts (**50**). A verified source rename keeps the Group alias, updates the editor's original name, and leaves all member/read/arrival sets and canonical/local IDs unchanged (**65**, independent database copies). Subscription discovery remains canonical (**71/72**).
- On the final runtime, the Following folder and its actual owning Feed use the same alias; clearing it reveals the newly verified **144 Native Following Updated**, including when the Feed cache has its older title (**67**). Received Topics expose no alias, Settings, Delete or Publish action, and Group alias removal reveals the latest canonical name with its Unseen count intact (**69**).
- **320dp / 200% text**, on the exact final APK: every received alias-menu action is within the safe viewport, Edit Alias taps normally, the full original name is visible in the scrollable editor, and the actual visible IME leaves Cancel/Save reachable. Cancel preserves the alias (**92**); the original size/density/font settings were restored and audited. The initial alias runtime also saved a real alias while the task transport was unavailable, with the IME visible (**38**); private persistence survived both later upgrades exactly.
- The offline directory test revoked Android's SAF grant. The directory was restored, then the **normal picker** reselected the same transport root and restored access (**61**, subsequent healthy state **65/114**). The exact opaque URI and serialized settings did not change; all three aliases and original rules survived. Maintenance recovered automatically. No identity or data reset was used.
- Actual final-runtime Android records match **all three approved title/body pairs**, including emojis. The Post case is **2 new posts / Come take a peek! 👀**, with no Group/device diagnostics; discovery and a genuinely new offer use their exact generic copy. Singular and greater-count formatting is additionally covered by the focused actual-formatter tests. Initial manual subscription correctly establishes a baseline without a Post alert. A newly created future child under that subscribed Group is then received automatically and produces one aggregated two-Post notification (**80/86**, signed catalog **34**).
- All three actual OS notification categories open **Bookmarks Home** (**86/108**). Post tap and subsequent Group navigation leave all **seven** received owners' complete read/arrival values and subscription sets unchanged in independent database copies; the `2` badge remains. A same-named cloned child uses its distinct source identity and does not inherit another Group's alias.
- Confirmed ancestor Unsubscribe removes only uncovered mirrors; the separately subscribed child retains the **same local UUID, entire owner/reading value and private alias** (**96**, database audit). The parent rule was restored and the additional test subscription removed, returning to the original **two Bookmark + one Following** rules (**98**).
- The publisher's temporary Group/folder names and Feed flag were restored. All four task publications were stopped through normal UI (**94/100**), and only the task-created four-Group local copy was deleted after its preview showed no orphan Bookmark deletion (**102/104**). Original source collections remain. Signed withdrawal catalog **40**, followed by final empty catalog **41** after fixture cleanup, independently verifies with the original key. The receiver's source high-water mark advances **27 → 41**, and its stored digest matches the **canonical signed content**. Both domains have no remaining mirror owners; all collection aliases and pending Post intents are empty; the original three rules remain (**106**, final audit).
- Final genuine cold restarts retain the restored source state and healthy receiver permission/details state (**112/114**); there is **no historical MiteMite notification replay**. Both final app checkpoints include cache and no-backup signing authority. Both prod apps and identified task Maestro drivers are stopped, the SAF harness is absent, all task-created discovery identity namespaces are removed, and both exact leases are released.

These are two independent Android installations using **controlled, hash-checked immutable-file propagation between their separate SAF roots**, not a live Syncthing/SMB session. The native Feed check used an empty Post cache; it is not authenticated live-site/media or physical ARM64 acceptance. Remote reparent/cross-publisher isolation, cache-loss and interrupted-write cleanup cases are covered by automated tests. The owner will perform live physical-device performance acceptance; no performance measurement is claimed here. Prior Viewer, durability, broader UI and live-service limitations below retain their exact original runtime attribution.

Failed flow/setup evidence is retained and excluded: redundant Back (**26**), the original clipped menu (**28**), remembered Settings navigation (**56**), an already recovered Retry row (**63**), unsupported notification-shade YAML rejected before actions (**73**), an unsaved caret-position edit caught by its assertion (**88**, corrected with Select All), and cold Settings navigation (**110**, corrected from the inspected state in **114**). These did not overwrite source data. The intermediate popup runtime's two actual Feed-sort failures and intentional stopped run are described below; the final complete runner passes both corrected cases.

### Evidence and final action

Durable evidence is under ignored **`.worktrees/_artifacts/144-final-followups-2026-11-16/`**: exact-SHA regression/analysis/build/native records, `regression-counts-d8ee9a269.json`, focused logs, actual Maestro requests/results/screenshots, verified catalogs and immutable-file hashes, private/mirror audits, full before/final checkpoints, `native-final-acceptance.json`, `native-final-device-audit.json`, `native-final-cleanup.json` and final documentation checks. The APK is archived as `app-prod-d8ee9a269e50-d32531eabeceea97.apk`.

The owner's final requested action is Windows host hibernation **after** this evidence is committed/pushed and the clean remote delivery is verified. `hibernate_after_completion.py` checks those completed gates, then schedules `shutdown.exe /h` with a 30-second delay and no forced app closure. Its actual scheduling receipt is recorded separately as `hibernate-final-request.json` and the Windows invocation result as `hibernation-windows-result.json`; this paragraph does not claim the computer is already asleep. No further agent implementation/verification task remains. Owner performance review and any develop integration/PR/closure require the owner's subsequent decision.


## Earlier implementation checkpoint — superseded by final verification above

The two latest approved tasks are implemented on the existing feature branch:

- **Notification copy:** committed/pushed as `b5ce432f5`. The production formatter uses the exact approved Post singular/plural titles and body emojis, the same offer title for one/many offers, and generic device discovery wording. Focused copy/delivery/discovery/outbox tests passed **31**, and the real-provider native notification/navigation checks passed **2**. Generated i18n validation passed. Delivery, trust privacy, aggregation, receipts and Home-only tap behavior are unchanged.
- **Receiver-local collection aliases:** implemented for received root/nested Bookmark Groups and Following folders, including the owning Feed. Set/Edit/Remove Alias is available in received menus; the editor shows the original publisher name. Empty/whitespace clears to the latest canonical name. Private preferences use `(publisher, kind, source UUID)`, survive restart/cache loss/offline/verified rename/reparent/overlap, and prune only committed orphan ownership or Forget. Source model names, shared packages, read state and Following NEW remain unchanged. Following Topics have no alias actions; source editing remains blocked.

The detailed [alias contract](144-mitemite-received-local-aliases-2026-11-15.md) and [notification copy contract](144-mitemite-notifications-ui-brand-2026-11-15.md#owner-approved-follow-up-task--mitemite-notification-copy-implemented-2026-11-16) remain authoritative. Final focused aliases/sync, Bookmark and Following regressions passed **2070 tests**; the separate long-source-name alias dialog passed **1** at 320dp / 200% text with keyboard. Scoped analysis: **0 errors, 0 warnings, 285 infos**, exit 0. i18n generation/validation and Dart formatting passed. Initial compile/selector failures are excluded from verification. Frozen-candidate full/native results are now recorded above. Do not reuse earlier green runs as evidence for these new runtime changes. **No merge, PR, release or #144 closure is authorized.**

## Intermediate native QA findings — resolved by final verification above

The first alias runtime `9746842954a7e7311558c275f19367d5eb306c1d` passed the complete runner: **7,540 application + 1,708 package/CLI tests across 13 suites**, both shell suites and **76 Python tests**, exit 0 on the clean unchanged candidate. Full analysis: **0 errors, 0 warnings, 4,225 infos**. Its exact ARM64/x64 APK SHA-256 is `47b6dcdc6910fc5faef930a81dfab877fa4d7f9ba59a65e484fc4c3b9517a03d`. The native build reused **52 passing unit results** (`UP-TO-DATE`) against unchanged native inputs; **14 real SAF/provider instrumentation** cases passed. Both independent emulator installations were upgraded in place from complete app/cache/no-backup checkpoints; every serialized private value matched immediately after upgrade.

Native alias acceptance then found a real shared-popup boundary bug at **320dp / 200% text**: Flip selected the space above an anchor when neither side fit; Shift adjusted only the cross axis, leaving Edit Alias partly under the status bar. The follow-up correction opts popup menus into viewport constraints and measured placement clamping, and makes long menu content scroll independently. Other KurumiAnchor surfaces retain their existing behavior. Regression tests cover safe insets, enlarged text with/without keyboard, first/last action taps and preservation of the underlying page scroll position. This runtime correction requires a new full pass and source-corresponding APK; the earlier green suite is not final-candidate evidence.

On the first APK, actual root/nested Group aliases, opened title and ancestor path, Following folder card/title, source read-only menus, and exact generic Android discovery copy passed. An independent mirror snapshot confirms Group ownership, revisions, subscriptions and reading are unchanged by alias editing/navigation. At narrow/enlarged layout, an alias was saved with the actual IME visible while the task transport directory was temporarily unavailable. The exact directory and display settings were restored afterward. The clipped menu required an inspected partial-row tap to reach that editor; this workaround does **not** qualify corrected menu placement. One redundant Back selector and the clipped-menu tap/assertion are retained as failed flow evidence, not passes.

The first popup correction `08d62766c073b81949c38fe80e838535da17d3d5` passed all 227 Kurumi and 77 management/provider tests, full analysis (0 errors/warnings, 4,225 infos), a fresh APK build, 52 retained passing native unit results (`UP-TO-DATE`) and 14 real SAF tests. Native cold restart retained all three aliases and Unseen counts; all private values survived upgrade exactly. At 320dp / 200% text, all four menu actions were inside the safe area, ordinary Edit Alias tapped successfully, and the visible IME left Cancel/Save available. Cancel preserved the alias and display settings were restored.

Its full regression exposed **two actual failures**, both cached Feed sort/history tests at 1x/2x. Emitting SizeData caused the anchor dependency to read the opener's global transform during overlay build while the Feed toolbar was being rebuilt during dismissal. The runner was intentionally stopped after these failures (SIGTERM / -15); its record is complete as a stopped failed candidate, not a green run. No interrupted-run inference is needed. The lifecycle correction moves size bounds into the popup widget and leaves the positioning middleware free of that build-time measurement callback. The actual failing Feed cases, all management consumers (**80 tests**), the complete Kurumi suite (**227**) and changed-file analysis (**no findings**) pass after correction. At that intermediate checkpoint, final full/native qualification was still required; the completed results are recorded above.

Durable evidence for these increments and the correction is in ignored `.worktrees/_artifacts/144-final-followups-2026-11-16/`. Final correction SHA/full/native acceptance and cleanup results are recorded above. Protected physical devices remain untouched; no owner live-device performance acceptance is claimed. No PR, merge, release or #144 closure was performed.

## Owner follow-up: relative dates and device layout (2026-11-15/16)

The local device has the fixed **This Device** title and its editable
**Device Alias** property. **Update Now** and its progress indicator are in the
MiteMite header. Ready/Updating text is removed from the identity row; failures,
partial results and existing repair actions remain separate and visible.
**Device Details** always includes **Last Updated** (last success) and **Last
Attempt**, with **Never** for absent values, followed by ID/fingerprint copying.

Activity and device timing use the existing localized relative-date wording,
minute text pulses and exact-date tooltip. Date refresh is local widget state;
it does not scan transport, reload libraries or write timestamps/events.
UTC storage, source identity, trust, reading and mirror ownership are unchanged.
The canonical specification and earlier owner UX handoff follow this correction.

### Final verification of the device-layout correction

Runtime: `ca99534312b101594218f19e06057fb8ee8c4066`.

| Check on the unchanged candidate | Exact result |
| --- | --- |
| Complete local suite coverage | **7,523 app + 1,708 package/CLI tests across 13 suites**, both shell suites and **76 Python tests** passed, with detected concurrency 6. See the interrupted-wrapper qualification below. |
| Full analysis | `fvm flutter analyze --no-pub --no-fatal-infos`: **0 errors, 0 warnings, 4,213 infos**, exit 0; clean unchanged runtime before/after. |
| Current APK | `fvm flutter build apk --debug --flavor prod --target-platform android-arm64,android-x64 --no-pub`: exit 0; clean unchanged runtime; installed hash matches below. |

`./scripts/run_regression_tests.sh` completed the app stage (7,523) and began
packages, then its wrapper/runner disappeared with observed **SIGTERM / exit 143**
during cache_manager. No failed-test marker was recorded; the signal's origin
was not established. Its durable wrapper record remains incomplete and is **not**
reported as a complete runner pass. All 13 package/CLI suites, both shell scripts
and Python tooling were then rerun separately using the runner's same commands
on the still-clean, unchanged candidate. Every remaining command and their
wrapper exited **0**. Their durable records prove complete required coverage in
two stages; no app/runtime changes occurred between them. Two existing go_router
tests remain skipped. The completed app stage plus final package/tooling run
emitted **59 Dart VM callback/finalizer diagnostics** and existing hit-test
warnings; those are retained in the logs.

The focused real-provider management file passed **54 tests** and the relative
date file passed **4**. The final post-save rendered-alias assertion passed after
pumping its pending UI frame. Scoped analysis has no errors or warnings; the
complete analysis above records informational findings separately. `./gen.sh i18n`
completed validation and regeneration for the localized Never fallback. Initial
RawTooltip/IconButton selector failures and an earlier pre-frame rename assertion
are excluded from success evidence; the final complete suite covers the corrected
assertions on the committed candidate.

Native acceptance used only leased **emulator-5556** and the exact current APK,
installed in place from a complete app/cache/no-backup authority checkpoint.
Normal-width UI shows This Device / Device Alias, no Ready label, and the header
Update Now action. Expanding Device Details shows both relative timestamps;
Activity shows relative event dates. At **320dp / 200% text**, the header and
identity/details remain reachable, and the actual visible IME leaves Cancel/Save
accessible. Cancel preserves the alias. Exact original display settings were
restored. A genuine cold restart revalidated
the fixed title/alias, header action and both relative date fields. Final audit
matches the original serialized signing identity, settings, trust and every
private preference value except normal local event/attempt/success state. The
original dev APK/public identity/notification permission flags remain unchanged.
A complete final checkpoint includes app data, cache and no-backup authority.
The prod app and identified Maestro driver are stopped, and the exact used lease
is released. Protected physical devices were untouched.

Maestro call 4 assumed a standalone Device Details label; inspected recovery used
its combined expansion semantics in call 6. It is excluded from passed evidence.
The initial keyboard screenshot preceded settled IME layout; the verified capture
follows explicit IME Done visibility and separately recorded input-method flags.
No timing/performance conclusion is drawn from Maestro execution.

The APK supports both ARM64 and x64 Flutter engines. Its exact SHA-256 is
`3780ae12d2356dc958893b20c7d0634233e4fdaba75b83a7bb42ee07f927d421`.
It is archived as `app-prod-ca99534312b1-3780ae12d2356dc9.apk` under the evidence
root below. The physical ARM64 device was not operated on; owner live performance
acceptance remains pending. No profiling or benchmark was performed.

This increment changes presentation/localization only. Prior two-device transport,
Viewer, notification delivery, native SAF and durability evidence below retains
its exact runtime attribution; no extra native SAF/JVM suite was claimed here.
The notification-copy and received-collection-alias tasks were subsequently implemented; see the current checkpoint above.
No PR, develop merge or issue closure was performed.

Durable evidence: ignored `.worktrees/_artifacts/144-device-layout-2026-11-15/`,
including `regression-ca99534312b101594218f19e06057fb8ee8c4066.{json,log}`,
`regression-counts-ca9953431.json`, full analysis/build records,
`management-final.log`, `relative-date-second.log`, `rename-rendered.log`,
`apk-abi-verification.json`, native UI screenshots and Maestro request/results,
private-authority audit and complete before/final app checkpoints.

Native evidence includes Maestro calls **2–21**, `normal-device-layout.png`,
`normal-activity-relative-dates.png`, `narrow-large-device-layout.png`,
`narrow-large-device-details.png`, `narrow-large-alias-keyboard-verified.png`,
`visible-keyboard-flags.json`, `display-restored.json`,
`native-device-layout-final-audit.json`, `maestro-driver-cleanup.json` and
`emulator-final-cleanup.json`. The unused emulator-5554 claim lost its token due to
parsing claim text as JSON; it was never operated on. Its normal TTL is respected
(expiry `2026-11-15T23:30:06Z`), without bypassing token-based release. Its ordinary
expiry and inactive reservation were confirmed before final handoff. Only
emulator-5556 was used for this acceptance.

Split regression evidence: the interrupted `regression-...` logs/record,
`regression-interruption-ca9953431.json`, complete
`remaining-regression-ca99534312b101594218f19e06057fb8ee8c4066.{json,log}`,
and `regression-counts-ca9953431.json`. Build output retains the existing SDK
`File modified during build. Build must be rerun.` diagnostic separately from
successful exit and clean source/APK correspondence.

## Incremental synchronization and one-minute polling (2026-11-15)

The owner approved lightweight Update Now, full shared-payload audits at startup
and every **15 foreground minutes**, and changed routine polling to **one minute**.
The 500ms local-change debounce remains. Performance acceptance will be performed
live by the owner; no benchmark, profile capture or measured device responsiveness
is claimed by the automated correctness checks.

Verified increment `e059f6c80` moved POSIX durability off the UI isolate and skips
only identical private values confirmed by a successful barrier. Its focused
durability run passed **18 tests**, including failed cached writes and reopening.
The final candidate also moves atomic native publication, package preparation,
validation/materialization, semantic hashes and cryptographic work to detached
tasks. Only snapshots/codecs or path/byte values cross isolate boundaries.

Quiet checks avoid outgoing snapshots, archive reads/builds and retention.
Required source snapshots read only covered local members, indexed once, with
bounded yielding; source revision, Following structure, profile references and
location are revalidated after preparation. Current catalog bytes are still read.
Verification reuse requires exact bytes and current trust/checkpoint admission;
automatic receive reuses discovery's verified ticket. New catalog publication
still validates all referenced payloads before advertising them. Audit collection
checks yield between serialized units; retention admits each checked deletion
through serialization. Audit time is monotonic and excludes background time.

Committed mirror epochs drive domain-specific projection, including partial
success and reload retry. Outbox acknowledgements do not reload libraries.
Management/Following lists ignore operational timestamps. Folder display-path
lookup follows location/access changes. Startup/resume recover missed dirty
signals; desktop watcher events remain lightweight.

The affected mitemite run passed **296 tests** (`final-scope.log`); a preceding
run including detached Bookmark backup consumers passed **299**. The final
real-provider run passed **68**. Tests prove no poll at 59 seconds and one at 60,
no Published-list rebuild from status timestamps, quiet source/receiver checks
with no payload reads/shared writes/presentation reloads, foreground audit repair,
concurrent resume, stale source rejection and changed-byte/same-sequence attacks.
Development failures included nullable capture, missing scoped-provider
dependencies and a missing injected test clock; these were corrected. Mutation
fixtures now signal local changes explicitly; retention tests await audits, and
the old cross-domain reload expectation now enforces domain isolation.

### Qualification of the one-minute implementation

Final runtime and regression candidate: `d6ec7bb738b681a5af25dc88815c9e1509b217f2`.
Verified changes were committed and pushed incrementally (`e059f6c80`,
`50ba9dd72`, test correction `e5dd095a2`, final payload worker `d6ec7bb73`).
The final review found and detached the remaining outgoing payload SHA-256 hash;
a known-vector/frozen-input test covers asynchronous admission. All **297**
mitemite tests passed after that correction.

| Final candidate check | Exact result |
| --- | --- |
| Complete local suite | `./scripts/run_regression_tests.sh`: **7,516 app + 1,708 package/CLI tests across 13 suites**, both shell suites and **76 Python tests**, exit 0; clean unchanged `d6ec7bb73` before/after; default detected concurrency 6. |
| Full analysis | `fvm flutter analyze --no-pub --no-fatal-infos`: **0 errors, 0 warnings, 4,211 infos**, exit 0; clean unchanged `d6ec7bb73`. |
| Final affected scope | `fvm flutter test test/core/backups/mitemite --no-pub --concurrency 8 --reporter expanded`: **297 passed**. |
| Final x64 APK | `fvm flutter build apk --debug --flavor prod --target-platform android-x64 --no-pub`: exit 0; exact installed SHA-256 below. |
| Owner ARM64 APK | Same clean runtime with `--target-platform android-arm64`: exit 0; built only, physical-device acceptance remains with owner. |

Two existing go_router tests remain skipped. The full run emitted **60 Dart VM
callback/finalizer diagnostics** and existing hit-test warnings, with no failed
test or runner hang. These diagnostics are retained in the log. Earlier CI and
complete-suite results qualify their recorded commits and executed steps only.

The first complete run on `50ba9dd72` passed 7,503 app tests and failed exactly
12 obsolete Auto Backup layout assertions for helper text removed by the owner
in `861d2786a`. The removal is preserved. Tests now verify the current enabled,
reachable Select/Change control within 320px at both text scales. All 12 pass;
focused analysis reports no errors/warnings and one pre-existing informational
finding. The `e5dd095a2` full run was deliberately stopped when final review found
the remaining synchronous outgoing digest; it is excluded from success evidence.

Both leased emulators were cold-booted from persisted AVD data without loading an
older snapshot or wiping data. Complete app/cache/no-backup authority checkpoints
preceded each in-place prod upgrade. Original serialized C/D signing identities,
settings, approved trust and monotonic high-water state are preserved. Original
dev installs and protected physical devices were not used for these tests.

Actual two-device Bookmark acceptance on `50ba9dd72` published only the existing
empty task Group `144 Final Summary QA` as independently verified catalog **24**.
Receiver D subscribed, materialized its real archive, exposed source read-only
controls and then normally unsubscribed only that added rule. Source C normally
withdrew it as signed catalog **25**. The pre-existing two Bookmark rules and one
Following rule remain.

On the final `d6ec7bb73` APK, C normally published its existing task Following
folder and Topic as independently verified catalog **26**. D received them through
its retained folder subscription. Offline ownership metadata records both typed
source owners at revision 2; UI shows the folder/Topic and excludes source Edit,
Delete and Publish actions. Normal Stop Publishing produced catalog **27** with
no active roots. After genuine cold restarts D reached Ready with the original
friendly SAF location and three subscriptions. Offline metadata has no remaining Bookmark or
Following owners and no pending Post intents; C's original local folder/Topic
remain. D's approved C fingerprint and persisted high-water **27** survive. Final
checkpoints include app data, legacy cache and no-backup authority. Installed APK
hashes, original dev APKs/public identities/permission flags and display settings
match their recorded baselines. Task drivers/harnesses are stopped/removed and
both exact emulator leases are released. The console stop command returned zero
but the AVDs remain discoverable; app/driver shutdown is verified, AVD power-off
is not claimed.

Native JVM and Android SAF results are **52 tests / 9 suites** and **14 provider
tests** respectively on `50ba9dd72`; Android and filesystem source are identical
at `d6ec7bb73` (`git diff --exit-code 50ba9dd72 HEAD -- android lib/foundation`).
The task-only instrumentation harness was removed. Dart worker paths were then
exercised with the rebuilt final APK on both independent prod installs. Historical
notification, Viewer, keyboard, theme and narrow/enlarged native acceptance below
retains its original commit attribution; those native steps were not all repeated.

Transport between the independent real SAF folders uses controlled hash-checked
immutable-file propagation, not a live Syncthing/SMB session. No benchmark,
profiling or device responsiveness measurement was performed. Owner live-device
performance acceptance remains pending. The later notification-copy and received
collection-alias tasks are outside this performance
increment; #144 remains open, with no PR or merge.

The final x64 APK SHA-256 is
`758ae1d2cceebb5b638679162d4e16410bf793347179481aa107b17ac93afb08`,
matching both installed prod apps. The separate owner-review ARM64 APK is
`app-prod-arm64-d6ec7bb738b6-a13f649233158326.apk`, SHA-256
`a13f649233158326350307b609f1b597ff1f8f893e2ae8e915287bfcff836a1d`.
Its Flutter engine targets ARM64; bundled plugins include additional ABIs.
It was built and archived from the clean candidate, without physical-device
installation or performance acceptance. Successful builds retain the SDK's
existing `File modified during build. Build must be rerun.` diagnostic.

Evidence is under ignored `.worktrees/_artifacts/144-incremental-sync-2026-11-15/`:
`regression-d6ec7bb738b681a5af25dc88815c9e1509b217f2.{json,log}`,
`regression-counts-d6ec7bb73.json`, `analyze-d6ec7bb738b681a5af25dc88815c9e1509b217f2.{json,log}`,
`prod-build-d6ec7bb738b681a5af25dc88815c9e1509b217f2.{json,log}`,
`prod-arm64-build-d6ec7bb738b681a5af25dc88815c9e1509b217f2.{json,log}`,
`native-build-50ba9dd72ca9e0f6abc0c83ebbfe41c999bcfa31.{json,log}`,
`native-saf-50ba9dd72.{json,log}`, `native-incremental-catalog-{24,25}.json`,
`native-final-catalog-{26,27}.json`, `final-native-device-audit-d6ec7bb73.json`,
`maestro-driver-cleanup.json`, `emulator-final-cleanup.json`, private authority and
mirror snapshots, and Maestro calls **2–44**. Call 8's selector assumed a standalone
Subscriptions label; inspected recovery in call 10 used its combined semantics.
An early Following snapshot preceded asynchronous apply and is explicitly excluded;
`after-confirmed-catalog26` records the committed folder/Topic owners. Neither is
relabeled as a passed final-state assertion.

## Owner follow-up: minimum circular counter width (2026-11-15)

The Bookmark Group Unseen counter now has a minimum width equal to its
rendered text height plus vertical padding, with a stadium outline and centered
text. Single digits remain circular at enlarged text sizes; longer counts widen
the badge. Count semantics and persisted reading state are unchanged.
`bookmark_mirror_engine_test.dart`: **50 passed**; affected-file analysis:
**no issues**; Dart format and diff checks pass. No new Android UI run or complete
regression was performed for this scoped visual correction; the runtime
qualification below remains evidence for its exact earlier commit. An unrelated
`en-US.json` edit was preserved and excluded from this change.

## Final verified runtime and owner-review handoff (2026-11-15)

**Qualified runtime: `86e2210831b2dc3d9eb8fef8abc81be25f2cca56`**, on
`feature/144-folder-based-collection-sync`. Implementation is complete for the
approved v5 and subsequent owner UX/notification contracts. The recovered
management patch is integrated, not left encoded. Earlier timer/Hive teardown
failures, Following descendants/definition activity, persistent Unseen badges,
real full-media reading, source-owned mirrors, responsive management and the
later notification corrections are covered by the current regression. Canonical
specification and tests follow the latest combined-subtree reading decision,
fixed outlined Eye, global Notifications flag and Home-only notification taps.
The original owner SVG remains byte-identical.

| Final check | Command and exact result |
| --- | --- |
| Complete local suite | `./scripts/run_regression_tests.sh`: **7,508 app + 1,708 package/CLI tests across 13 suites**, both shell suites, **76 Python tests**, exit 0; clean unchanged runtime before/after. |
| Full analysis | `fvm flutter analyze --no-pub --no-fatal-infos`: **0 errors, 0 warnings, 4,177 infos**, exit 0; clean unchanged runtime. |
| Migration/location focus | `fvm flutter test test/core/backups/mitemite/persistent_preferences_test.dart test/core/backups/mitemite/android_storage_test.dart --no-pub`: **22 passed**, including actual host cache-directory loss, stale cache, partial authority and failed durability barriers. |
| Native JVM/build | Java 17 `./gradlew :app:testProdDebugUnitTest :app:assembleProdDebugAndroidTest --console=plain`: **52 tests / 9 suites**, zero failures/errors/skips, exit 0. |
| Real Android provider tests | `am instrument -w -e class com.timberpile.boorusama.MiteMiteDocumentsProviderTest,com.timberpile.boorusama.AutoBackupDocumentsProviderTest com.timberpile.boorusama.test/androidx.test.runner.AndroidJUnitRunner`: **14 passed**, including no-backup private location without a selected tree; task-only harness removed. |
| Current APK | `fvm flutter build apk --debug --flavor prod --target-platform android-x64 --no-pub`: exit 0. SHA-256 **`790f464d59d860b4e89eb93c1ce55629976c2f334f621b3d6bf6599ca196214b`** matches both independent installed prod apps; upgrade only, no data/cache reset. |

Two existing go_router tests remain skipped. The complete regression emitted
**59 Dart VM callback/finalizer diagnostics** and existing hit-test warnings,
with no failed test or runner hang. FVM/build output also retains the existing
`File modified during build. Build must be rerun.` diagnostic; successful exits,
clean source provenance and actual installed APK hashes are recorded separately.
An intermediate extra scoped command named a nonexistent `test/core/widgets/app_shell`
directory and exited 1; it is excluded. The complete final suite above passed.
Old CI and earlier runtime passes qualify only their own recorded commits/steps.

**Current Android upgrade and two-device evidence:** only leased
`emulator-5554` and `emulator-5556` were used. Both original dev installs remain
on their original APK, public identities and permission flags; protected physical
phones were untouched. Prod receiver D remains
`99c6fc2f-d8a3-4f77-a394-e500c02f67bf`; source C remains
`ea999d83-8ef6-4ea1-b184-e4cc61195b0e` with fingerprint
`028ab5cdf1e5a352add3bae0919c395d0f2a0681fe04cf10abb8926c462a18ce`.

The migration audit compares every opaque legacy preference against the private
one-frame snapshot: **all 8 receiver and 20 source keys match**, including exact
serialized signing identities, trust/high-water state, settings, reservations,
outbox and receipts. Initial effective notification outboxes also match exactly.
Both ordinary launches and genuine stop/relaunch cycles succeeded through the
production bootstrap/provider. SAF location, Notifications preference, approved
trust and all three subscription rules (two Bookmark, one Following) survive.
Source local Following folder/Topic and local Bookmark/QA Groups remain present.

A normal UI publication of the existing **empty task-only `144 Final Summary QA`**
Group produced signed catalog **22** after migration. Independent Python Ed25519
verification used C's original public key; receiver D authenticated and persisted
22. Normal **Stop Publishing** produced verified catalog **23**, with **no active
publication roots**, and D persisted high-water **23** through restart. The offer
checkpoint advances normally; this is not an outbox reset or historical alert
replay. Receiver Bookmark metadata remains **byte-identical** to the prior fully
withdrawn state: two retained rules, no mirror owners, no pending Post intent,
SHA-256 `b9a90c82b7b22a8ecb9cc1d9054c5f7a7c9049b648bccf493effb8e000486eba`.

The previous exact native acceptance on `70565c984`, `26679a90f` and `643ac6f20`
remains separately identified below: actual permission denial/restart/later grant,
generic fresh empty-device discovery, initial trust baseline/later authenticated
offers, deduplicated later Post batches, persistent Unseen, decoded Viewer,
combined Mark Read, future descendant, read-only Following, SVG, 320dp/200%/light
and keyboard checks, and real warm/cold child/owned-summary taps. Those UI,
notification and reading implementations are unchanged by `86e221083`; current
full regression requalifies their consumers. Their native steps were not all
repeated on this final APK. The final APK adds real migration/restart and signed
publication/withdrawal acceptance, rather than relabeling earlier screenshots.

Durable evidence is under ignored `.worktrees/_artifacts/144-notifications-2026-11-15/`:
`regression-86e2210831b2dc3d9eb8fef8abc81be25f2cca56.{json,log}`,
`analyze-...`, `prod-build-...`, `native-build-...`,
`regression-counts-86e221083.json`, `native-saf-86e221083.{json,log}`,
`private-authority-verification-authority-after-upgrade-86e221083.json`,
`private-authority-verification-authority-after-restart-86e221083.json`,
`native-private-migration-catalog-{22,23}.json`, and Maestro calls **435–460**.
Excluded selectors: 443 assumed an ancestor action at Home; 447 expected a
Published label inside the empty timeline after a successfully signed publication;
451 expected Stop Publishing where the actual action is Manage Publication.
Inspected recovery and independent state verification followed each; none is a
passed assertion or an application failure.

**Verification limits:** transport between the two independent real SAF folders
uses controlled, hash-verified immutable-file propagation, not a live
Syncthing/SMB session. Decoded synthetic-media Viewer checks do not qualify live
Safebooru/Pixiv services. Channel blocking has controlled host coverage; native
permission denial/later grant is actual Android evidence. Cache eviction is
reproduced with actual host directory deletion; no Android cache/data was cleared.
The native no-backup location is verified, but no live Google cloud/device-transfer
restore was run. Authority already lost before this upgrade cannot be recovered
automatically; corrupt/incomplete existing private authority deliberately requires
recovery instead of silently replacing a publisher. No social reactions or large
multi-device dashboard was added, as explicitly deferred by the owner.

**Final cleanup:** Both stopped prod apps have verified final TAR/APK checkpoints
including `cache/misc_data_v1.hive` and `no_backup` under
`{serial}/prod-accepted-86e221083/`. Earlier selected-directory-only backups are
not authority backups. Both displays match the original 720×1600 / 320dpi / 1.0
text baseline. Only task Maestro drivers, test harness and media helper were
stopped/removed; both exact leases were released. Local QA Groups, source Posts,
Following definitions, shared task files, original dev installs and user data
were retained. `native-progress-86e221083.json`,
`notification-no-replay-private-migration.json`,
`final-native-device-audit-86e221083.json` and `native-cleanup-86e221083.json`
record these checks. The notification comparison proves that only the accepted
offer catalog checkpoint advanced 21→23: known offers, pending intent, batch
counter and permission receipt remain unchanged.

The branch is prepared for **owner review/integration approval**. Keep #144 open;
no merge, PR, release, develop mutation or issue closure has been performed.
The final documentation-only commit reuses the unchanged runtime qualification
above. Windows hibernation may be requested only after its clean remote
publication and final issue/cleanup gates; the owner's instruction is to
hibernate once all authorized work is complete.

## Historical checkpoints (superseded by the final qualification above)

The remaining entries preserve earlier requirements, failures and exact-commit
evidence. Their pending-work and do-not-hibernate statements describe those
historical checkpoints, not the completed runtime above.

> **Most recent owner decisions (2026-11-15, after notification/icon handoff):** The approved [MiteMite follow-up implementation contract](144-mitemite-notifications-ui-brand-2026-11-15.md#follow-up-owner-decisions--approved-2026-11-15) now requires: **Unseen in a combined/subtree view if any covered Group is Unseen; actual full Viewer/Mark Read from that combined view marks all covered Group occurrences Seen**, while individual Group views remain local to that Group; **plain outlined Eye icon A** for All/Unseen/Seen; **one global MiteMite Notifications switch** controlling all three categories; **all MiteMite OS notifications tap to Bookmarks Home only**, not individual MiteMite pages or Groups. Social reactions and large multi-device UX are deferred; target 1–2 devices. This supersedes earlier conflicting read-provenance and category-specific notification-tap requirements. The corresponding canonical v5 spec is updated. No runtime code/tests changed by these documentation decisions.

> **New owner implementation scope (2026-11-15, after final QA):** Read [MiteMite notifications, responsive management, and approved icon](144-mitemite-notifications-ui-brand-2026-11-15.md). The exact owner-supplied monochrome SVG is committed at `assets/icon/mitemite.svg` (`cc1b7994`). Required next changes: remove multi-second global `service.busy` UI lockouts during background reconciliation; reproduce missing Android new-device alerts; add notifications for trusted newly published collections and newly received Post additions; **coalesce all received new Post changes into one OS notification per batch with canonical overlap deduplication**; place the MiteMite icon at Feature/Published/Bookmark device-divider surfaces; add contextual Seen-filter icon. No runtime changes or validation are claimed by this asset/docs handoff. Keep #144 open and do not merge without owner approval.

## Private-authority cache lifetime gap found at final audit (2026-11-15)

Runtime **`643ac6f20`** passed complete regression (**7,490 app, 1,708 package/CLI,
both shell suites, 76 Python; two known skips, 60 VM diagnostics, no failed test
or runner hang**), analysis (**0 errors, 0 warnings, 4,177 infos**), both matching
native APK installs, genuine warm/cold owned-summary taps, combined Mark Read,
future-descendant receive, all signed withdrawals, and **13 real SAF tests** after
stopping the lingering task Maestro device drivers. The original dev APKs,
identities and notification flags remained unchanged. All six task publications
were withdrawn normally; independent Ed25519 verification confirms original
publisher C's catalog **21** has no roots. Local source data is retained.

A final source/device audit then established a separate durability gap:
`ProductionBoorusamaBootstrap` opens `misc_data_v1` in
`getTemporaryPath()`; `IoFileSystem` resolves that to the **OS application cache**.
Production sync identity, settings, trust/high-water marks, reservations and
notification receipts use this store. Fsync alone does not protect them from OS
cache eviction. Both actual stopped QA apps have `cache/misc_data_v1.hive`.
Read-only private copies are captured in
`legacy-sync-authority-cache-checkpoints.json`; no device cache was cleared.
Earlier selected-directory TAR checkpoints include app_flutter/files/shared_prefs,
**not this cache authority file**, and must not be described as complete backups
of the sync signing authority. These additional private captures preserve it.

The approved durable-identity/anti-rollback contract requires a correction before
completion: put only `mitemite.v1.*` preferences in a dedicated app-data box,
migrating the entire legacy prefix as one durably committed snapshot before any
transport/key use. Later per-key writes retain existing durability/retry barriers;
ordinary cache preferences stay in their existing store. A valid durable snapshot
always wins over stale legacy cache; incomplete/corrupt durable authority fails
closed rather than generating a replacement identity. Preserve exact existing
opaque values and serialized writers. Exclude this device-specific private folder
from Android cloud backup and device transfer so persistence cannot clone one
publisher onto a second install ([Android backup rules](https://developer.android.com/identity/data/autobackup)).
The implementation uses Android's `noBackupFilesDir/mitemite_private` through
the existing native channel, without requiring a selected SAF tree. Desktop uses
app data. The complete migration is one Hive frame; serialized later writes are
per-key overlays. Migration/retry barriers include directory ancestry. Existing
empty files, orphan overlays and missing identities fail closed even when stale
legacy cache is still present. Ordinary startup remains available after a
snapshot validation/barrier failure; service preparation retries before key use.

The real cache-loss regression fails with the old cache-backed adapter and passes
with this store. The latest focused migration/native-location run passes **22
tests** (`private-authority-final-guards.log`), including stale-cache reopening,
failed cached-write retries, migration ancestry, partial-state rejection and
no-SAF private location. The broader earlier affected run passed **401 tests**
before the final empty-file guard. Full regression, rebuilt Android/native checks
and identity/checkpoint-preserving native upgrade acceptance remain required on
the resulting new runtime.
**Do not hibernate at this checkpoint.**

## Genuine Android group summary correction (2026-11-15)

`1824a05f0` passed its focused 374 tests and analysis/build, but **failed the
subsequent native grouping acceptance**: Android dissolved its orphan per-event
summaries and generated another launcher-only auto-group summary. The complete
regression was deliberately interrupted (SIGTERM, exit -15), not passed.
`native-final-summaries-after-resume.json` records all three actual event
notifications and Android's generated fourth container. No domain/read-state
mutation or rollback was performed.

The correction uses a genuine common MiteMite group with children and one stable
**silent, private, app-owned summary carrying the same Bookmarks Home payload**.
This is a native grouping container, not an additional Post event or audible
alert. Original event tags/IDs remain stable. Existing displayed MiteMite events
are silently regrouped on the next delivery; unrelated download notifications
are excluded. Opening the summary dismisses its displayed native children so
Android cannot recreate a launcher-only container after auto-cancel; durable
pending intent and persisted reading state are untouched. Cold and warm summary
taps share this behavior, with nullable native-data guards and best-effort
native dismissal that cannot prevent navigation.

The **14 focused notification tests** pass, covering shared grouping,
private/silent summary, legacy migration, download isolation, failed-summary
retry and warm/cold dismissal. The complete affected mitemite/navigation run
passes **378 tests** (`native-real-group-scope-qualified.log`, exit 0), including
actual summary identity through the production navigation/provider owner. Earlier
failed runs used stale expected summary IDs or counted the silent container as
another discovery event and are excluded. Final complete regression and genuine
summary/child-tap Android acceptance are still required. Do not hibernate at this checkpoint.

## Android auto-group summary correction (2026-11-15)

The subsequent clean `26679a90f` runtime passed the complete regression
(**7,485 app, 1,708 package/CLI, both shell suites, 76 Python; two existing
skips, 59 VM callback/finalizer diagnostics**) and full analysis (**0 errors,
0 warnings, 4,173 infos**). Its prod APK SHA-256
`1b013e65476f8108698e9a281bc123c834460276f157ae15f8d8c1d3822ef66d`
matched both independent QA installs. Native identity-only discovery warm tap
and genuine cold Post tap correctly reached Home; individual versus combined
full-media Viewer reading and the second genuine Post batch passed with exact
private mirror/read-state audits. Following folder/Topic receipt, read-only
menus, the Eye filter and light 320dp/200% keyboard/alias checks passed.

A further native case failed: with both a Post and an offer notification active,
Android generated an **auto-group summary** whose content intent launches the
app without the plugin payload. Tapping the collapsed summary left the retained
Group open (`fresh-maestro-call-282` through `284`); this is excluded from passed
navigation acceptance. Both OS notices were dismissed by that summary tap.
Android documents that automatic grouping varies by device and recommends an
explicit group and summary ([Android notification grouping](https://developer.android.com/develop/ui/views/notifications/group)).
Each existing logical MiteMite notice now supplies its own stable group key and
is itself that group's summary, retaining its original tag/ID and Home payload.
No extra notification, alert, receipt, private state or shared protocol is added.
This also prevents a system-created summary from combining MiteMite with unrelated
download notifications. The focused red run reproduces two missing grouping
contracts; the corrected complete mitemite/navigation run passed **374 tests**
(`native-summary-green.log`, exit 0). Final complete/native requalification is being
recorded in `144-notifications-2026-11-15/`. Do not hibernate at this checkpoint.

## Android-discovered Bookmark Home ingress correction (2026-11-15)

The complete clean-source regression on **`70565c984`** passed **7,485 application
and 1,708 package/CLI tests across 13 package suites, both shell suites and 76
Python tests**, exit 0. Two go_router tests were skipped. The log contains 60
native Dart VM callback/finalizer diagnostics and existing hit-test warnings,
without a runner hang or failed test. Full analysis reported **0 errors,
0 warnings, 4,171 infos**, exit 0. Current Android JVM tests passed **52/52**,
and the prod provider-instrumentation APK built. This pass qualifies that exact
runtime only; the following Android-discovered correction requires requalification.

Two independent current-source prod installs matched APK SHA-256
`ae850a75fa2f5391da9a5264a923bc13994940578720396a8f83ba9119a7dbb1`.
Original dev apps and protected phones stayed untouched. The actual native
fresh-device denial, ordinary-launcher process restart, subsequent OS permission
grant, one private generic notification, and warm tap from Browse to Bookmarks
Home passed. The existing publisher identity/fingerprint survived its update
and SAF relocation. Initial trust baselined existing offers silently; a later
direct Child publication produced one `New Collection Available` notification.
Actual native screenshots verify the immutable published SVG and one SVG at the
received device divider with no repeated card glyph or Local heading.

The next native tap **from an already-open Bookmark Group failed**: the Group
remained open (`fresh-maestro-call-120/121.json`). The browser's `_open` keeps
its Group path in page state, so draining Navigator routes alone is insufficient.
The corrected ingress sends an explicit destination-root request after guarded
route unwinding, remounts that destination's root browser, and keeps content
activity suppressed through the replacement frame. Ordinary destination switches
retain their existing Group path. Persisted ownership, read state, journal and
notification state are unchanged by this UI reset.

`notification-real-browser-root-red.log` reproduces the retained-page failure
in both production-provider tap cases. The corrected cases pass in
`notification-real-browser-root-green.log`; the subsequent expanded navigation,
mitemite and application-consumer run passes **384 tests** in
`notification-browser-navigation-final.log`. The final two tap scenarios also
cover an offstage retained Bookmark browser and pass in
`notification-real-browser-root-retained-final.log`. Native reinstallation,
complete regression and analysis on this corrected candidate remain required.
The early test's text hit-target warning was removed by tapping the real card.
The synthetic v10 Post-only fixture lacked a required dated membership and was
correctly rejected before apply; qualified replacements include a dated Default
membership. Import validation was not relaxed.

Android generation/delivery and reading acceptance is still in progress;
**do not hibernate at this checkpoint**. Durable native evidence is in
`144-notifications-2026-11-15/native-progress-70565c984.json` and the private
Maestro/native dumps. Failed selectors and the failed retained-Group tap are
excluded from passing native evidence.

## New scope: durable notification implementation checkpoint (2026-11-15)

The next runtime increment implements one private typed outbox for device
identity discovery, authenticated new direct publication offers, and one
canonical new-Post summary across all publishers/Groups in a receive batch.
It preserves the stored `discoveryNotifications` preference as the **single
Notifications switch**. Initial hydration and initial trust are baselines;
renames, metadata changes, duplicate paths, removals/reappearances and retries
are not new arrivals. Future descendants of existing subscriptions are included.
Exact member intent and ever-observed membership are committed in the mirror
journal, separately from the 200-entry Activity display window. The local
Activity format remains byte-compatible with legacy v1 journals until v2
notification metadata is introduced; no signed/shared format or identity changes.

The outbox copy and domain cursor commit atomically before journal retirement.
A matching cached cursor after a failed preference durability barrier must pass
that barrier again. Durable Forget tombstones prevent interrupted older intent
from being reintroduced, even after the Forget Activity row is truncated.
Notification acknowledgements use captured generation tokens, preserving changes
merged during native awaits. Failed/disabled/denied/channel-blocked delivery
retains exact intent for **24 hours**, expiring individual stale items while
keeping Activity; permission prompting has a durable one-attempt receipt.
Already-consumed legacy discoveries cannot safely be replayed because their old
receipt does not distinguish a real display from the previous denial bug.

All categories reuse the application-owned native notification instance and the
existing channel, including blocked-channel preferences. Stable native tags/IDs
replace the same batch after a crash; later genuine batches receive a new ID.
Both legacy and new notification payloads open **real Bookmarks Home**, including
when the Bookmark branch has retained nested routes. Route PopScope guards are
respected. Content activity is synchronously suppressed while that navigation
unwinds, including already-queued Viewer callbacks; notification taps never
mark content Seen or grant trust/subscriptions.

`notification-journal-final.log`: **269 passed**, covering the complete
mitemite directory plus explicit navigation-root, transient-route and
activity tests. Cases include a 100-Post baseline, shared parent/child and sibling
memberships, future descendants, trusted offers without subscriptions, cross-
publisher/2+3+4 aggregation, permission/channel refusal, preference changes during
permission waits, native receipt failures, restart, 205 exact changes beyond the
200-row Activity window, failed cached durability writes, Forget tombstones,
and real-provider warm/cold legacy-payload Bookmarks Home ingress.
The earlier integrated pass had 267 tests; the durability-barrier pass had 268.
Earlier failed fixture/compile/revision-replay attempts are retained and excluded
from passing evidence. The scope analysis before the final two durability cases
reported **0 errors, 0 warnings, 268 infos**, exit 0; final complete analysis and
regression are still pending. Some focused runs include the known native Dart VM
callback/finalizer diagnostic; no focused runner hang remains.

Current-source Android installation/notification/UI acceptance, complete final
regression and full analysis remain active work. Both exact emulator leases were
reclaimed after expiry; the original dev apps remain intact. Complete validated
checkpoints protect the separate prod QA package on B; the package was confirmed
absent on A before any new install. **Do not hibernate at this checkpoint.**

## New scope: approved subtree reading and icon checkpoint (2026-11-15)

The concurrent owner decisions through `75da5eae5` were preserved before replaying
and pushing the unchanged responsiveness runtime as **`c6b48fc7d`**. The original
unpublished `6d8ae7743` differs only in its parent/documentation; its 232-test
runtime evidence remains applicable. The first push was rejected without
changing the remote; no force push or concurrent-commit overwrite occurred.

The next increment implements the approved combined-view contract. A collapsed
member is Unseen whenever any covered canonical Group considers it Unseen.
Its Viewer/Mark Read captures all represented publisher/source/Group/member
identities, with the viewed subtree boundary, and commits applicable reading
changes in one journal transaction. Individual Group behavior stays scoped.
Current ownership/membership and current subtree ancestry are revalidated at
commit; removed/reowned/reparented targets cannot redirect a stale callback.
The existing actual-full-media/foreground/covered-route gates are retained.

`subtree-red.log` reproduces the root-Seen/child-Unseen mismatch. The corrected
projection, atomic reading, independently subscribed child, restart, reparented
and forged-owner tests pass. The additional real signed second-publisher test
(`subtree-real-foreign-final.log`) proves that the same portable Post outside the
viewed publisher subtree remains independently Unseen.

The immutable owner SVG now appears at the MiteMite entry, published Bookmark/
Following collections and received device dividers. Received cards omit repeated
status glyphs and retain read-only semantics; nested Bookmark titles retain a
small receive cue. Following's real Folder/feed and definition-change controls
remain. Unsubscribe consistently uses unlink. The fixed plain Eye filter has
localized Read Status accessibility labels. Nine asset/raster tests pass at
16/20/24/32dp in light/dark; actual rasters were inspected. Its intrinsic aspect
ratio initially exceeded a square icon slot, caught by the tests and fixed with
an outer square constraint without changing the SVG bytes. The 320dp/200% filter
choice regression passes. `./gen.sh i18n` was run for the new localized label.

`subtree-icons-consumers.log`: **2,461 passed**, covering complete Bookmark,
mitemite, Following, Viewer and timeline directories. It includes hit-test
warnings in existing stale-selection fixtures; it is not described as warning
free. The final Topic/folder accessibility change was followed by **814 passing
mirror/Following tests** (`subtree-foreign-and-following-final.log`); the extra
signed-foreign test then passed separately. Scoped analysis before that final
test reports **0 errors, 0 warnings, 818 infos**, exit 0; final analysis repeats
that result in `subtree-icons-final-analyze.log`. Full final-source
regression and Android acceptance remain required after notification work.

A genuine fresh prod-flavor installation on B, publisher
`ea999d83-8ef6-4ea1-b184-e4cc61195b0e`, selected the real SAF root with zero
publications. Two verified immutable files were propagated to A. Without A's
Update Now, foreground scanning posted one generic private Android notification,
importance 3, stable identity tag, ONLY_ALERT_ONCE/AUTO_CANCEL, confirmed after
several polls (`native-baseline-discovery.json`, calls 29–35). Its actual tap
opened the old Subscriptions route; the new owner requires Bookmark Home instead.
The exact missing-alert report is **not reproduced under these granted/enabled
conditions**. The known denied/disabled acknowledgement defect still needs its
new durable retry implementation and native qualification. Initial launch/picker
selector attempts are excluded from passes. Original dev identities and user
content remain intact; protected phones remain untouched.

All three durable notification categories, global Notifications wording,
Bookmarks Home taps, full final regression, native/UI qualification and cleanup
remain active work. Do not hibernate at this checkpoint.

## New scope: interactive management checkpoint (2026-11-15)

The latest owner scope above is in progress; the previous final pass below
qualifies only `99a3b71b2`. The clean branch was fast-forwarded to the owner's
four asset/document commits through `ae46c29a3`, preserving the exact approved SVG
SHA-256 `154cdfaad6869d3133ecb94818f6d1e05f9aaf3a3b8888b74f1b0ab0519c852e`.

The first runtime increment separates `isReconciling` and per-target pending
actions from internal transport serialization. Management dialogs/navigation,
identity details/copy and unrelated actions stay available during a scan.
Notification preferences commit under the existing metadata coordinator without
waiting for slow transport; settings and their in-memory projection change
inside the same critical section. Conflicting writes still queue through the
existing operation coordinator, validate the current target and retain error
feedback. Identical explicit update requests join the running reconciliation;
polls/resume do not request an extra no-op scan while it is active. Actual local
mutations retain their durable catch-up intent. Update Now shows progress while
remaining able to join its existing operation.

Durable evidence: `.worktrees/_artifacts/144-notifications-2026-11-15/`.
`responsive-red.log` reproduces two failures: distinct futures for overlapping
Update Now requests, and a null/disabled Device Name callback after ten seconds
of controlled deferred scan time. `responsive-green.log` passes both; the complete
`fvm flutter test --no-pub --concurrency=6 --timeout=2m --reporter expanded
 test/core/backups/mitemite` passes **232 tests**, including local-preference
completion during held transport, queued Subscribe/Stop, one Stop history event,
retained mirror IDs/reading and ordered Forget/reapproval. A separate widget test
opens/cancels name and alias dialogs and navigates root/Published/Subscriptions/
Devices while the provider future remains unresolved. The first widget fixture
incorrectly awaited file I/O under FakeAsync and was stopped; its interrupted log
is excluded. The corrected fixture uses real-I/O setup plus controlled frames.
Initial sandbox-only FVM attempts could not write the SDK cache and did not run
tests. Scoped analysis exits 0 with **0 errors, 0 warnings, 206 infos**;
`responsive-analyze.log`. Format/diff checks pass.

Both existing dev installs have complete validated new baseline checkpoints.
For a genuine fresh publisher, a separate prod-flavor debug package was proven
absent on emulator B, built from the prior unchanged runtime and installed there;
the existing dev app/identity/data remain intact. Its source/APK provenance and
absence-before-install are private artifacts. Native baseline reproduction is in
progress; initial launch automation encountered the ordinary What's New modal,
not a proved product startup failure. Protected phones remain untouched.

Still required in this new scope: durable typed notification generation,
aggregation/retry/tap handling, native missing-alert reproduction and all three
categories, approved SVG/filter integration, complete final-source regression,
Android/UI acceptance, final evidence/push and lease cleanup. Hibernate only
once all authorized work is finished; no merge, PR or #144 closure.

## Previous owner-review handoff — 2026-11-15

**Verified runtime:** `99a3b71b2bad328a370ae181a1647b0ec4d5197e` on
`feature/144-folder-based-collection-sync`. Later documentation-only commits
preserve that runtime/test tree. The approved v5 implementation and final owner
UX corrections are implemented. This section supersedes the outstanding-work
statements in the chronological checkpoints below; their earlier failures and
passes remain evidence for their exact candidates. No merge into develop, PR,
issue closure or protected-phone operation was performed or authorized.

### Exact final verification

| Check | Executed result and durable artifact |
| --- | --- |
| Complete `./scripts/run_regression_tests.sh` on clean, unchanged `99a3b71b2` | **7,447 application tests; 1,708 package/CLI tests across 13 suites; both shell suites; 76 Python tests**, exit 0. Two existing go_router skips. `final-regression-99a3b71b2.json` verifies clean source before/after and unchanged HEAD; `.log` contains all results and **59 native Dart VM callback/finalizer diagnostics**, without timeout or runner hang. |
| Focused final Viewer/page-view/Bookmarks/mitemite consumer tests through `fvm flutter test --no-pub` | **1,608 passed**, exit 0, no callback diagnostics; `full-media-reading-consumers.log`. Includes the real mixed Viewer with held/failed full image and a real covering Kurumi modal. |
| `fvm flutter analyze --no-pub --no-fatal-infos` | Exit 0; **0 errors, 0 warnings, 4,103 infos**; `full-media-reading-workspace-analyze.log`. The earlier scoped analyzer exited 1 for ten infos, not errors/warnings; it is not counted as an exit-0 pass. |
| `fvm flutter build apk --debug --flavor dev --target-platform android-x64 --no-pub` | Passed; `full-media-reading-apk-build.log`. Both installed APKs match SHA-256 **`7b4c8b67407c4b2b82cb0852eea291b995640f21d9464fa4cdff025e0f384fca`**. Updates used `install -r` after complete validated checkpoints, without data clearing or older-state restoration. |
| Android native tests, unchanged native inputs | **52 JVM tests** and **13 real ContentResolver/provider instrumentation tests** (9 MiteMite, 4 Auto Backup) passed. `native-candidate-*-build.log`, `native-saf-instrumentation-second.log`, `OK (13 tests)`. The first attempt collided with an existing UiAutomation registration and is excluded. |

Durable private artifacts are under the ignored workspace directory
`.worktrees/_artifacts/144-remediation-2026-11-14/`. Logs, screenshots, signed
transport fixtures and complete private app/APK checkpoints remain there. Private
app archives can contain account state and remain untracked; credentials are never
included in committed documentation. Existing green Actions runs
were not substituted for these local/current-source results.

### Owner report and approved UX traceability

| Requirement | Final implementation and verification |
| --- | --- |
| U1: one-route Android Back | Real Settings-shell regression covers subpages/dialog-first Back at 390/1024 widths. Native Back traversed Subscriptions → MiteMite → Export and Import → Settings. Its initial outer Bookmark-Home assertion was wrong because the actual caller was Browse; that initial flow is excluded. |
| U2: exact contextual Publish | Production-provider regressions preserve the captured writable source, confirm/cancel and full descendant scope. Native contextual publication exchanged the actual signed source between independent installs. |
| U3: published-only management | Only direct roots, simplified rows and trailing Stop Publishing menu. Native overlapping child withdrawal retained parent coverage; final parent withdrawal reported two uncovered Groups. |
| U4: explicit-root offers | Signed-root and real-provider tests cover inherited descendants, direct child offers and canonical virtual links; native parent/child acceptance retains one source identity/read state. |
| U5: trust before collection detail | Real-provider tests and native untrusted discovery expose identity/trust only, without collection metadata or media. |
| U6: identity labels | Separate selectable ID and signing fingerprint, compact This Device/Device Details; production UI tests and native inspection. |
| U7: discovery notification | Native Android warm tap, cold-launch tap, actual permission denial, privacy, channel and dedup; durable receipt/history tests. Subscribe/discovery success toasts are removed. |
| U8: authoritative subscribed state | Real service → storage → provider → mounted UI regressions, truthful Subscribed label, idempotent commands, pending-toast/teardown regression and full runner completion. Native Subscribe creates current read-only device sections immediately. |
| U9: source-owned received sections | Repository guards and actual Home/Group/Viewer paths, local-only All Bookmarks, direct 48dp alias Edit, read-only AppBar actions and separate ordinary Timeline More/View Options. Typed-only Work/Pool timelines and nested routes are covered by focused tests. |

The later owner contract is authoritative: **plain persistent Unseen `N`, zero
hidden, and no Group-open acknowledgement**. The canonical specification,
conflicting tests/mockup explanations and plan Task 7 now reflect it. No Local
heading or Folder glyph appears on Bookmark Home; received cards/titles use the
compact incoming-tray glyph. The 20dp top-right Unseen marker disappears during
selection so Preview remains usable. The conditional All / Unseen / Seen filter
keeps reset reachable when its current result becomes empty. The Group AppBar
menu and Timeline More remain separate; Group commands never enter View Options.

The initial five-member native scenario passed **5 → 5 on open → 4 after actual
full Viewer display**, then filtered occurrence/Mark Read/restart checks. Final
native qualification on `99a3b71b2` additionally establishes:

- An independently duplicated/published/subscribed four-member Group stays at
  **4** after opening and after the full image fails while its red thumbnail and
  Retry remain visible. Actual purple full-image display changes **4 → 3**. The
  older independent Group retains its separate **3**, including its historical
  receipt from the defect reproduced on `e90af7b4e`; no receipt was reset.
- A genuine green video frame renders behind the video-settings modal after an
  explicit server release. Process termination while still covered and ordinary
  relaunch retain **3**. Active loading/poster-only video also retains **3**;
  actually visible playing green video changes **3 → 2**. The first wholly
  stalled-stream attempt hit Exoplayer's network timeout and is excluded.
- At **320dp / 200% text**, Seen/Unseen filter the correct occurrences, Timeline
  View Options and the separate read-only Group menu remain reachable, and
  selection Preview replaces the Unseen dots. Mark Read consumes the remaining
  two memberships, the empty active filter remains resettable, and hidden zero
  survives display restoration/process restart.

`native-read-gate-99a3b71b2.json`, private Maestro calls 276–362 and the
`native-99-*.png` screenshots record these observations. The native-discovered
thumbnail/full-image bug was reproduced before its minimal fix and qualified by
new behavior tests plus this actual Android repeat, not just source inspection.

### Following, automation, durability and SAF

All remaining v5 subsystems are connected: source-owned Following Topic/folder/
Feed definitions and current/future descendants; receiver-local profile/refresh/
cache/NEW/read state; separate definition receipts; durable dirty reconciliation,
activity/failure isolation and recovery; bounded own-namespace retention with
foreign-file protection. The focused suites and complete final pass include
journal faults, overlapping ownership, replay floors, independent failures,
retention/offline catch-up, identity repair and interruption recovery. Earlier
implementation sections retain the individual commands and findings.

Final two-install Following acceptance automatically published a third future
Topic, received it under the existing folder without another subscription, then
renamed it to **144 Landscape Renamed**. Catalogs advanced automatically to
**14/15**, without publisher Update Now. B fetched actual public Posts through
its existing Default profile. Renaming preserved the four cached previews and
Last Post value, and reflagged the explicitly acknowledged Topic definition.
Prior local profile/disabled-refresh preferences and the independent one-Topic
Local folder copy survived. `native-following-live-99a3b71b2.json`, calls 363–386
and two screenshots retain this evidence. The initial fetch establishes NEW=0;
nonzero NEW alongside a definition notice is covered by host tests, not claimed
as a subsequent native live arrival. No native query edit was performed: the
existing Topic editor exposes Name and Auto Update.

Native authenticated Pixiv acceptance on `e90af7b4e` (unchanged selection inputs)
used normal single/multiple Work selection and ordinary local Bookmark pickers;
two typed Works retain **4 and 14 Pages**, without converting to Page bookmarks.
Typed-only local Timeline View Options also opened. Real Work publication was
cancelled after automatic approval review rejected its confirmation; it was not
transmitted. Native Publish/Receive media acceptance instead used generated
media, with typed received routes covered by host tests.

The 13 real-provider tests exercise unknown sizes/actual byte bounds, immutable
partial identity/payload/descriptor/catalog writes, fresh-name retry, duplicate/
renamed documents, read failures, independent concurrent channels, owner/path
bounds, foreign preservation, partial/revoked grants and recovery, and opaque
provider display names. Actual system-picker relocation selected an empty
`Documents/Boorusama144RelocationFinal`, retained A's public identity SHA-256
`2f61727a535cee2cff26bc3d0059804a3a15f6da7f4f082cafebb8e85a0fcd40`, continued
catalog **11 → 12**, and preserved subscriptions and independent read counts
while the remote publisher was absent. Returning through the picker to the
original `Documents/Boorusama144Test` continued at **13**. APK update/restarts
retained that selected root, identity, counters, trust and reading. No stale
checkpoint was restored. `native-relocation-evidence.json` records the evidence.

### Final device state and precise limits

Both exclusively leased independent installs used actual Android SAF roots and
signed namespace exchange with per-file immutable hash validation. This is
**controlled file propagation, not a live Syncthing/SMB or commercial cloud
DocumentProvider qualification**. Protected physical phones were untouched.

Normal Stop Publishing actions withdrew all task publications: A's signed catalog
**18**, B's **11**, both with empty publication roots. Stopping the direct child
first retained both Groups under parent coverage. After final verified withdrawal,
only the covered received mirrors disappeared; A's local parent/child and B's
independent Bookmark/Following copies remained. Private subscription rules,
trust, original publisher identities and monotonic history were not reset.

Four generated discovery namespaces were removed only after exact file/hash
validation. Four staged QA exports were archived/hash-verified and removed from
B's Downloads; only the task-created `.dev.test` instrumentation APK was
uninstalled. The first absence postcheck incorrectly treated Android's expected
`pm path` exit 1 as an error; a separate successful read-only check proves every
file/test-package absence and main-app presence.

**Automatic approval review rejected permanently deleting an Imported Groups QA
wrapper (two Groups/four synthetic Bookmarks), because its QA-only status was not
sufficiently established under the data-preservation instruction. The destructive
confirmation was never executed; Cancel was verified.** All local QA Groups,
independent copies and the new Pixiv QA profile are intentionally retained rather
than bypassing that rejection. Any future permanent cleanup needs owner approval.
Both active Browse destinations use the original Default profile. The unused
relocation directory/extra SAF grant are retained; only the selected transport
root, display settings and notification flags are claimed restored.

The actual native theme remained Default/Midnight; light/dark component behavior
is covered by widget tests, **not a native light-theme run**. At 200% text the
existing shared small Retry-button label wraps below its background; selection
and actions remain reachable. No unrelated shared-button redesign was added.
Startup under concurrent full host regression is not a performance or seamless
upgrade qualification. The two existing skips and VM diagnostics above remain
reported limitations.

`final-native-device-audit-99a3b71b2.json` verifies both installed APK hashes,
unchanged public identities, exact original **720×1600 / density 320 / font 1.0**
and restored notification grant/flags. A's alias is its original blank fallback;
B's remains **Sync emulator A**. Both main apps are stopped. Fresh complete TAR
checkpoints with expected members/end blocks and SHA-256 are in each device's
`native-final-99a3b71b2accepted/`; they preserve the final state without overwriting
pre-update archives. The private Maestro MCP/media server are stopped, our VM
forward is removed/absent, and both exact emulator leases are released.
`native-cleanup-progress-99a3b71b2.json` and `native-fixture-file-cleanup.json`
record completion and the intentional retained data.

Only owner review/integration approval remains; do not merge, create a PR or
close #144. The requested computer hibernation is performed only after this
final documentation is committed, pushed and remote publication is verified.

## Historical checkpoint: native-found full-image reading correction (2026-11-15)

Final native acceptance found a remaining defect in `e90af7b4e`: a decoded
progressive thumbnail shares the full image controller, so its `completed` state
could mark an intentionally failing full image Seen. The synthetic failed member
in `144 Viewer Gates Final` changed that Group from 4 to 3. This is a failed
acceptance case, not a successful failed-media gate. Its persisted read receipt
has not been reset or restored from an older checkpoint.

The Viewer now additionally requires an accepted full-rendition decode before a
still image can acknowledge reading. Progressive thumbnails remain visible and
retain existing geometry/gesture behavior. Only the accepted target/intermediate
size callback releases this gate; the controller must still contain decoded
pixels after a frame, and settled-page, foreground, current-route and navigation
guards still apply. Metadata updates of the same portable Post do not discard a
valid decode; changing Post identity or actor invalidates it.

- `full-media-reading-red-qualified.log`: both real mixed-Viewer cases reproduce
  `Expected: empty; Actual: Set:['still']` while only the thumbnail has decoded.
  The earlier red attempt used the wrong preview fixture and is excluded.
- `full-media-reading-green.log`: both pending/failed full-image cases pass.
  `full-media-covered-qualified.log`: an actual full image decoded behind a Kurumi
  modal remains unacknowledged until the modal closes. The earlier cache-key wait
  attempt is excluded; the qualifying test waits for the decoded image itself.
- `full-media-reading-consumers.log`: **1,608 passed**, exit 0, covering complete
  Viewer, page-view, Bookmark and mitemite consumer directories; no native
  callback diagnostics. Complete analysis: **0 errors, 0 warnings, 4,103 infos**,
  exit 0 with `--no-fatal-infos`, in `full-media-reading-workspace-analyze.log`.
  The first scoped analyzer exited 1 for ten existing infos, without errors or
  warnings; it is not reported as an exit-0 pass.

The new x64 dev debug APK builds successfully
(`full-media-reading-apk-build.log`). Complete regression and fresh Android
read-gate acceptance subsequently finished on `99a3b71b2`, as recorded in the
final section above. The earlier complete pass
below remains historical evidence for its own candidate.

Additional `e90af7b4e` native results are durable in
`native-final-acceptance-e90.json` and numbered private Maestro records:
authenticated Pixiv single/multiple Work selection and ordinary local save
(two Works, 4 and 14 Pages), typed-only local Timeline View Options, automatic
Following root rename plus a future Topic received on B with the independent
Local copy and prior profile/disabled-refresh settings preserved, and native
warm/cold-tap/actual permission-denial discovery notifications. The real Pixiv
Group publication was cancelled after automatic approval review rejected its
confirmation; it was not transmitted. Generated media QA publications use only
the two emulator-local test roots with controlled immutable-file propagation.
Two earlier media fixtures used invalid source-base paths; their Unavailable
state is not a Viewer pass. The corrected fixture is
`144-viewer-gates-final.bsexport`, SHA-256
`9f2469743b8f2b3b9b921ae35097c8629b27918c93fe89834dbac6ec71003b13`.
No real Syncthing/SMB transport acceptance is claimed.

## Historical runtime `e90af7b4e`: complete regression passed (2026-11-15)

The unchanged, clean final cleanup candidate passes the entire repository runner:
**7,444 application tests; 1,708 package/CLI tests across 13 suites; both shell
suites; 76 Python tests**, exit 0. Two existing go_router skips remain. The log
contains 60 native Dart VM callback/finalizer diagnostics, without a test timeout.
`final-regression-e90af7b4e.json` records exact HEAD, clean source and completion;
the corresponding `.log` contains every result. Complete analysis also passes:
**0 errors, 0 warnings, 4,103 infos**. Later documentation-only updates reuse this
runtime/test evidence; subsequent runtime/test changes require requalification.

Both authorized emulators have this final x64 dev debug APK installed without
clearing data. Local/installed SHA-256 on each:
`f0048522ba3f445fe658ccc68bed4ab31381b61cc95758c3f1fb70945bfb6a67`.
The existing 52 Android JVM and 13 actual provider-test passes retain unchanged
native channel inputs. Current runtime native acceptance continues below.

During A's pre-update checkpoint, its Windows Phone1 AVD exited and disappeared
from ADB. The partial archive is explicitly marked interrupted/non-restorable;
it was never accepted as a completed checkpoint. The same reserved Phone1 was
cold-booted on port 5554 with `-no-snapshot-load`, without wiping data or restoring
an older snapshot. Fresh complete checkpoints on both emulators were validated
for TAR completion, expected directories and SHA-256 before their update was
accepted. Public identity/mirror continuity is still to be rechecked in the
remaining two-device acceptance. Protected phones remain untouched.

Continuation state: B has a draft `144 Pixiv QA` profile in the ordinary Pixiv
login WebView; successful authentication/Work selection is not yet established.
The credential reader and private Maestro MCP use field redaction and disable
the command Viewer before confidential input. No credential screenshot is taken.
The correct credential-free media fixture `144-native-viewer-qa.bsexport` for the
existing Safebooru/Danbooru profile is staged in B's Downloads but not yet imported.
The earlier four-record Gelbooru QA Group remains correctly Unavailable without
a matching account; retain it for normal test cleanup, not as a media-display
pass. Fresh warm/cold/denied notification fixtures are generated, not installed.

Continue genuine two-device Following/Bookmark changes, Viewer video/failed/
covered-media gates, native Pixiv, final UI/SAF checks and normal QA cleanup.
Active exact-device lease tokens remain in the ignored artifact. Do not mark
this checkpoint complete or hibernate yet. No merge, PR or issue closure.

## Whole-workspace analysis cleanup (2026-11-15)

The additional complete analyzer run found **0 errors, 7 warnings and 4,103
infos**, exit 1 (`final-entire-workspace-analyze.log`). Five warnings were
redundant Viewer null assertions/a cast after type promotion; the other two
were an unused Pixiv test import and unused cover-URL test constant. Removing
only these no-op checks/declarations yields **0 errors, 0 warnings and 4,103
infos**, exit 0 (`final-entire-workspace-analyze-qualified.log`).

All affected Viewer tests plus the Pixiv Favorites lifetime suite pass:
**290 tests**, exit 0, no native callback diagnostics
(`final-viewer-warning-consumers.log`). Format/diff checks and the x64 dev debug
APK build pass (`final-viewer-warning-apk-build.log`). No ownership, media,
selection, profile or persistence behavior changes. Repeat full regression on
this final cleanup candidate and install it on both emulators before final
current-source acceptance. The preceding `f077bc26c` full pass remains exact
historical evidence, rather than a claim about unexecuted steps.

## Final runtime regression checkpoint `f077bc26c` (2026-11-15)

The clean, unchanged committed runtime passes the complete repository runner:
**7,444 application tests, 1,708 package/CLI tests across 13 suites, both shell
suites and 76 Python tests**, exit 0. The two existing go_router skips remain.
`final-regression-f077bc26c.json` confirms unchanged HEAD and clean source at
completion; `.log` records all results, 60 native Dart VM callback/finalizer
diagnostics and no test timeout. This supersedes the earlier complete runtime
pass for current-source qualification; later documentation-only edits reuse it.

Both independent emulators now run the same current x64 dev debug APK without
clearing data. Installed/local SHA-256 on each:
`f14de0d76f90619e1ae548e139d0649b4e1b5bfb33af0f7b5e860399da7fc6f2`.
Before-update data/APK archives are preserved with restricted permissions.
The real-provider/native SAF evidence above remains applicable: its Android
channel/provider inputs have not changed in the popup-only correction.

Current native Following evidence (`fresh-maestro-call-32/37/40.json` and
`native-current-build-evidence.json`) proves accessible AppBar and Topic popup
actions, inherited-only omission of Unsubscribe, retained disabled auto-update,
opening without consuming the definition dot, and explicit definition-dialog
acknowledgement. The before/after popup screenshots show the same Kurumi visual
surface. Failed selector/transition attempts are retained and excluded from passes.

Initial UI readiness was delayed under concurrent full regression. B needed a
stopped-process restart/recheck; A became ready after the initial bounded launch
assertions failed. VM inspection showed its bootstrap Future completed with a
runtime, no permanent Sync/bootstrap deadlock, and the ordinary Browse UI then
rendered. This is not a startup-performance or seamless-upgrade claim.

Continue Android acceptance and cleanup: B is reviewing a normal, credential-free
QA media import with fresh identities. Its controlled loopback PNG/MP4 server
supports explicit video-release signals; fixture generation is not counted as a
feature test. Remaining genuine two-device/media/Pixiv/UI cases and final cleanup
are still open. The owner requested hibernation only after all work is finished;
do not hibernate at this checkpoint. No merge, PR or issue closure is authorized.

## Native Following popup accessibility correction (2026-11-15)

Current-build Android review found that Following's visible Topic/folder and
AppBar popup actions were missing from the platform accessibility tree. An
outer Tooltip introduced a second OverlayPortal semantics traversal relationship
around the popup. Ordinary widget-label finders still found its detached nodes,
so earlier widget assertions did not establish platform accessibility.

`KurumiPopupMenuButton` now accepts a trigger-only tooltip below its own anchor;
the two Following callers use it instead of wrapping the entire popup. Labels,
hover help, keyboard focus/restoration, Kurumi styling and source ownership stay
intact. The real-provider regression now searches the rooted semantics tree.

- `following-popup-accessibility-red.log` reproduces zero reachable Create Local
  Copy nodes on the prior runtime; the same test passes after correction in
  `following-popup-accessibility-green.log`.
- Complete Sync + Following consumers: **995 passed**, exit 0;
  `popup-consumers.log`. Complete Kurumi: **224 passed**, exit 0;
  `popup-kurumi-complete.log`, including standard/custom trigger semantics and
  Escape dismissal. Scoped analyzer: **0 errors, 0 warnings, 32 infos**, exit 0;
  `popup-analyze.log`. Formatting and diff checks pass. The corrected x64 debug
  APK builds successfully in `popup-apk-build.log`.

The full regression above this checkpoint was for `3d6e85520`; it must be repeated
on this new runtime. Native verification of corrected action nodes and remaining
two-device/media/UI acceptance continue before completion.

## Full host regression and native provider qualification (2026-11-15)

Runtime `3d6e85520` passes the complete `./scripts/run_regression_tests.sh`
with concurrency 6: **7,444 application tests, 1,706 package/CLI tests across
13 suites, both shell suites and 76 Python tests**, exit 0. The go_router suite
retains its two existing skips. The log contains 59 Dart VM callback/finalizer
diagnostics despite successful completion; these are not silently discarded.
`final-regression-3d6e85520.json` records the unchanged candidate and completion;
the corresponding `.log` contains every suite result. Test infrastructure edits
at this checkpoint affect Android instrumentation fixtures only.

The current x64 dev debug APK and instrumentation APK build, and all **52
Android JVM unit tests** pass (`native-candidate-*-build.log`). On exclusively
leased `emulator-5556`, **9 real MiteMiteChannel/ContentResolver provider tests
and all 4 affected Auto Backup provider tests pass** (`native-saf-instrumentation-
second.log`, `OK (13 tests)`). Coverage includes unknown sizes/actual bounded
bytes, immutable partial payload/descriptor/catalog/identity files, fresh-name
retry, renamed/duplicate documents, read failure, independent concurrent
channels, owner/traversal bounds, foreign-file preservation, persisted partial/
revoked grants and explicit recovery, and side-effect-free opaque display names.
The fixture is nested only in its opt-in Sync mode, preserving Auto Backup's
existing flat behavior. It never operates the selected external transport root.

The first native attempt failed because the idle Maestro driver's UiAutomation
registration was still active; no product test passed on that attempt. Releasing
that driver allowed the unchanged 13-test candidate to pass. The original MCP
connection remained marked dead, so UI acceptance uses a fresh local Maestro MCP
stdio session, with the same lease, and Viewer at `http://127.0.0.1:10000/`.

Emulator B was updated without clearing data; before-update private data and APK
archives are durable. Local and installed APK SHA-256 both equal
`f92435be973a276780e73c39ad5c8a0951c9754fcde0435e0c3c2a72ce99a077`.
Current-build Following opens without consuming its definition notice, omits
source-order-inapplicable Sort and creates a separate Local Copy. Native review
also exposed missing popup accessibility nodes under an outer Tooltip; that
finding is being reproduced before correction. Remaining two-device/media/UI
acceptance and cleanup continue; this is not completion or merge approval.

## Bounded own-namespace retention (2026-11-15)

Publication now performs bounded own-file retention after its complete signed
catalog and completion receipt. It retains two authenticated complete catalogs,
all referenced revisions/withdrawal evidence, cached complete revisions and the
two newest local reservations. Foreign namespaces, unknown/unowned collections,
identity documents, directories and unknown names are preserved. Catalog intent,
counters and inspected caches are rechecked before every deletion. Provider I/O
cannot be treated as an obsolete/incomplete catalog. A partial newest snapshot
blocks cleanup; an obsolete partial catalog can be removed after safe supersession.

Passes cap deletion at 128 files and catalog examination at 32. Limited scans keep
all revision files until they locate another complete snapshot; later scans resume.
Maintenance failure has its own Pending/Retry status and history context, while
current publication and healthy incoming work remain intact.

Verification based on `0610d87f3`:

- Full MiteMite suite **227 passed**, exit 0; `retention-qualified.log`;
  no native callback diagnostics. The initial run had 226 passes and one obsolete
  expectation that corrupt catalog files accumulate forever. The updated case
  checks a fresh higher-sequence replacement before bounded retention removes
  the obsolete corrupt file; no immutable overwrite is accepted.
- Two further preparation-race/scan-budget cases were added without runtime
  changes; all nine retention tests pass in `retention-final-focused.log`.
- Scoped analyzer: exit 0, **0 errors, 0 warnings, 204 infos**;
  `retention-analyze-qualified.log`. Format, translations and diff checks pass.
- Real independent library acceptance keeps the receiver offline through five
  definition updates, proves its old payload was pruned, then catches up with
  the same mirror ID, disabled local refresh and preserved/stale-safe definition
  receipts. Pure storage tests cover complete references, foreign/unknown data,
  corruption, I/O, bounded continuation, cached/in-flight tails and newer intents.

This completes the identified host runtime feature gaps, subject to the final
regression and platform review. Android remains on `33aaca7c1`; the new runtime
has not yet been installed. Next: final full regression, Android native provider
fault tests and current-build two-device/UI acceptance, then normal test-state
cleanup and the owner's requested hibernation. No merge/PR/issue closure.


## Typed failure history and own-identity relocation (2026-11-15)

Failures now retain typed local episodes rather than raw provider diagnostics:
permission, unavailable publisher, missing revision, unsupported data, identity
change, invalid signature, rollback, conflict, provider I/O and unknown errors.
Repeated polls/reconstruction deduplicate an active cause; recovery clears its
receipt, and a later episode is recorded again. History and date metadata remain
private. Attempts and full success persist separately; Last Updated now uses
success, while Last Attempt identifies unsuccessful attempts. Missing subscribed
publishers cannot silently produce a Ready/full-success result.

Own public identity verification runs before every outgoing reconciliation,
including cached/no-op publication. Partial/conflicting bytes remain immutable.
The UI explains Retry/different Storage Location without rotating identity or
resetting counters. Configuring an invalid folder preserves the current setting;
relocation retains incoming mirrors, subscriptions, trust and source IDs, writes
the same public identity, advances catalogs, and leaves old partial evidence.
A broken own identity still permits healthy trusted incoming subscriptions.

Verification based on `342540bb7`:

- Full MiteMite suite: **219 passed**, exit 0;
  `failure-and-identity-qualified.log`, no native callback diagnostics.
- A bounded deferred-diagnostic buffer was added after that pass; final focused
  classifier, identity, event and real-service tests pass in
  `failure-and-identity-final-focused.log`.
- Scoped analysis: exit 0, **0 errors, 0 warnings, 186 infos**;
  `failure-and-identity-analyze-qualified.log`. Translation generation, format
  and diff checks pass. Three now-unused UI imports were removed after the first
  analysis attempt.
- The new real-service identity fixture first failed because cached/no-op
  publishing skipped identity validation; the pre-publication check fixes that
  exact path. Coverage includes immutable partial bytes, same-identity relocation,
  incoming operation during outgoing failure, monotonic catalogs, unchanged
  invalid-target settings, offline publisher status, stable failure episodes,
  privacy-safe event serialization and retained success dates.

Host evidence only; Android remains on `33aaca7c1`. Owned-file retention and final
full-regression/native qualification remain open; no merge/PR/closure is approved.


## Journaled Activity and completed-publication recovery (2026-11-15)

Activity now uses the existing Bookmark/Following journals: a private 200-entry
outbox commits with source changes, subscriptions, Unsubscribe, Forget and Local
Copy. Monotonic per-domain cursors and bounded history update atomically in one
local preference value. Delayed delivery keeps occurrence-time ordering and
cannot evict newer events merely because an older journal was delivered later.
Reading, aliases, cache operations and digest migration do not invent changes.
Source ownership and transport formats are unchanged; metadata outbox rollback/
rewrites are rejected. Explicit Bookmark Local Copy can create fresh Local
Groups in the same journal, while rejecting existing Local edits, source-owner
changes, record writes, deletes and mixed parents.

Completed catalogs record their actual publication roots and completion time
locally; Publish/Stop history recovers from that receipt after an interrupted
history write. Failed publication intents are not reported as completed. Legacy
root receipts seed without duplicate historical announcements. Forget delivery
waits until both domain cleanup journals complete. Independent history failures
show Activity History Pending/Retry and retain successful domain changes. A
narrow Following activity reader avoids decoding its cached Posts on each flush.

Legacy Following journal recovery can recover missing folder-name scopes from
its own saved ownership metadata, preserving same-named folders across devices.
This is private rollback data, never incoming transport authority.

Verification based on `2100907c8`:

- Reproduced lost Bookmark and Following history after domain commit in
  `durable-activity-red.log`; both cases now recover exactly once after service
  reconstruction, with no repeat on polling or definition acknowledgement.
- All Backup/Import, Bookmark and Following consumers: **2,659 passed**, exit 0,
  `durable-activity-consumers-qualified.log`; no native callback diagnostics.
  One unused import was then removed; final affected store/service/history tests
  **21 passed**, exit 0, `durable-activity-final-focused.log`.
- Final scoped analyzer: exit 0, **0 errors, 0 warnings, 207 infos**;
  `durable-activity-analyze-final.log`. Its preceding run had one unused-import
  warning, now removed. Translation generation, formatting and diff checks pass.
- Tests cover interrupted receive/publication history, bounded delivery cursors,
  chronological delayed events, cursor rollback/fork rejection, Local Copy guards,
  deferred Forget history, independent-domain read failure and legacy scopes.
- Earlier intermediate failures: two Local Copy cases exposed the deliberately
  strict received-transaction guard (now a narrowly checked explicit copy path);
  publication fixtures exposed discovery-history persistence as another delivery
  failure (now isolated and retried); one new fixture used a non-const constructor
  as const. These runs do not qualify the final candidate.

No Android update was performed for this chunk. Installed runtime remains
`33aaca7c1`. Final full regression, native acceptance, owned-file retention and
actionable identity-file recovery continue; this is not #144 completion.


## Independent subscription failure isolation (2026-11-15)

Bookmark and Following receive now partition old/new coverage into connected
atomic units. Hierarchy overlap/moves and shared saved identities remain together;
independent roots under an unpublished ancestor remain separate. New shared
Bookmark metadata can enlarge a unit before commit, preventing a healthy update
from rewriting a failed sibling's global record. Every unit rechecks catalog
freshness and current ownership. Missing/incompatible units retain old data and
receipts; healthy independent units can advance. Service projection and Activity
include committed partial progress even when the operation reports failure.

Verification based on `98383c20b`: full MiteMite suite **195 passed**, exit 0;
`independent-root-isolation-qualified.log`. New coverage includes real independent
Following retry/catch-up, authentic new Bookmark descriptor/catalog with missing
payload, production-service partial projection/history, old/new moves, overlapping
roots, shared identities, 2,000-node iterative traversal, and newly shared metadata
remaining unchanged when the enlarged unit is incomplete. The first Bookmark
fault fixture used a cached revision plus catalog-only rename; that was correctly
applicable and was replaced with a genuinely unavailable new revision. The
Following starvation red reproduction is retained in the artifact log.
Scoped analyzer and formatting/diff checks pass; full final app/package regression
and Android acceptance remain pending. Activity is still recorded after domain
commit at this checkpoint; durable crash recovery of history is the next change.


## Following Local profile recovery and definition UI (2026-11-15)

A Local Topic/copy whose original profile is unavailable now offers an explicit
profile choice in Edit. Save starts disabled; no account fallback is selected.
The flow retains query structure, revalidates the chosen live profile and keeps
received definitions read-only. The edited surface reuses KurumiDialog and the
existing profile option component, with scrolling/wrapped actions for narrow
screens and keyboard insets. Cancel leaves the recovery draft unsaved.

Opening a received folder/Topic no longer acknowledges definition changes. The
folder header retains its explicit definition/details glyph; Topic receipts stay
independent. Received folders omit the ineffective Sort action, retaining Search,
Feed and More. Backup counts now match Local-only export content.

Verification based on `12d6b34e6`: **815 tests passed**, exit 0, all Following
consumers plus real-Hive/production-provider Following and backup-source tests;
`following-profile-and-ui-consumers.log`. Includes explicit recovery/cancel,
320dp at 200% with keyboard, menu action semantics, and folder-versus-Topic
receipt independence. The red missing-picker reproduction is retained. The first
candidate run had 13 passes/one obsolete ambiguous glyph selector; the selector
now targets the Topic rather than the independently visible folder glyph.
Scoped analysis, formatting and diff checks are recorded with this commit.
Native profile recovery and popup hierarchy verification remain pending on the
next Android candidate; host semantics coverage is not native UI evidence.


## Local Following import and rollback isolation (2026-11-15)

Local backup/import capture and rollback exclude source-owned definitions and
retain their IDs as exclusion metadata. Restore preserves the current received
folders, Topics, feed caches, refresh settings and definition receipts, including
newer source changes received after capture. Same-profile Local restoration is
allowed; incoming received IDs and received merge destinations remain rejected.
Ordinary matching never adopts a received Topic as a writable import target.
Replace removes/replaces Local definitions only. Following export excludes
received definitions; Create Local Copy remains the explicit independence path.
Legacy feed import/order/rollback also limits itself to Local records.

The private rollback codec preserves publisher folder name scopes, allowing
same-named folders from different devices without collapsing identities. This
is private journal metadata, not transport authority or credentials.

Verification based on `c2c0072d1`:

- Reproduced the prior capture/rollback failure in `following-local-rollback-red.log`.
- All Backup/Import and Following tests: **1,653 passed**, exit 0;
  `following-local-import-consumers.log`. Focused real-Hive tests cover ordinary
  import beside same-profile mirrors, protected ID collision/Replace rollback,
  a newer received definition surviving Local restoration, and reopen persistence.
- Scoped analyzer: exit 0, **0 errors, 0 warnings, 26 infos**;
  `following-local-import-analyze.log`. Dart format and diff checks pass.
- This is host verification. Android remains on the earlier installed runtime;
  full final regression and native import/recovery acceptance are not claimed.


## Following folder definition receipts (2026-11-15)

This continuation retains the owner-approved current/future descendant scope.
Folder/Feed receipts now include immediate child source identities, kinds and
order, so catalog-only membership/order/withdrawal changes cannot pass silently.
The private folder digest advances to v3; Topic profile digests remain v2 and
transport/schema identifiers are unchanged. Seen/unseen v1/v2 migration cases
preserve receipts for unchanged definitions, reject stale acknowledgements and
retain receiver-local refresh/runtime state. Activity compares canonical source
definitions rather than private digest formats, avoiding migration-only events.
Actual topology and publisher name scope are validated at the repository boundary.

Verification of this candidate, based on `33f0c6389`:

- `fvm flutter test --no-pub test/core/backups/mitemite test/core/search/following_topics test/core/backups/following_topics_source_test.dart --concurrency 6 --reporter expanded`: **992 passed**, exit 0; durable `following-definition-v3-consumers-qualified.log`.
- A preceding run executed 947 passing cases but exited 1 solely because an
  additional backup-source path did not exist; it is not a qualifying pass.
- `fvm flutter analyze --no-pub --no-fatal-infos` on MiteMite, Following and
  changed tests: exit 0, **0 errors, 0 warnings, 141 infos**;
  `following-definition-v3-analyze-qualified.log`. Format and diff checks pass.
- The focused future-child failure was reproduced before implementation;
  `following-folder-definition-red.log`. New coverage includes eight legacy
  format/Seen/child-change combinations and a real two-library Activity case.
- Host verification only. Installed Android runtime remains `33aaca7c1` and has
  not yet exercised v3 migration. Full final regression/platform acceptance and
  remaining v5 durability/import/isolation/retention work continue below.


> **Owner instruction:** Hibernate the computer only after all authorized #144 work is finished, verified, committed and pushed, with this handoff saved. Do not hibernate at an intermediate checkpoint or while verification/device operations are running.

> **Owner-approved MiteMite naming and Storage Location (2026-11-14):** [The final UX handoff](144-final-owner-ux-implementation-2026-11-14.md#approved-mitemite-terminology-title-case-and-storage-location-2026-11-14) now establishes **MiteMite**, **Published / Subscriptions**, **Publish to MiteMite / Stop Publishing**, **Devices / Activity / Storage Location / Update Now** and Title Case for English UI labels. The storage location must reuse Auto Backup's human-readable Android SAF display-path provider, **never show the raw `content://` URI**, and preserve the real opaque URI for transport. Earlier notes proposing Share/My Shares or saying the MiteMite name is undecided are superseded. This is a documentation-only acceptance update.

> **Latest approved owner UX contract (2026-11-14):** Read [Final owner UX implementation handoff](144-final-owner-ux-implementation-2026-11-14.md) **first**. It overrides the previous arrival `+N`/Group-open acknowledgement rule with a persistent **unseen member count `N` that only changes when specific members are seen/marked seen**; the thumbnail dot is **top-right**, hidden during selection to avoid the existing zoom control. It also specifies the ordinary Pixiv Work selection/Bookmark flow, no Subscribe success toast, native Android new-device notifications, and the other approved compact UI fixes. Earlier code/test checkpoint descriptions remain historical evidence, not acceptance of these new requirements.

> **Owner UX review (2026-11-14, after Android QA):** [Feedback on commit `78adbb7`](144-owner-ux-feedback-2026-11-14.md) is a required design/UX acceptance supplement for #144: Android system notifications (not discovery toasts), simplified This device/Publish/alias/Bookmark Home, per-Post Unseen markers + conditional Seen/Unseen filter, concise Subscribed copy, and a separately source-traced Pixiv timeline long-press selection regression. Naming was subsequently decided in owner commit `79f515f14`: **MiteMite** is approved for the visible feature label; other proposed terminology remains unapproved.

## Current checkpoint: `33aaca7c1` — latest received Group and device-header UX

All five additional owner QA corrections from `d6ee88508` / `2a3b87b19` are
implemented. Bookmark Home retains ordinary local/All cards without a Local
heading. Device dividers end in a 48dp Edit pencil opening the shared MiteMite
alias editor directly. Alias changes are receiver-local and work offline;
blank input restores the publisher name. Cards and opened Group titles share
`Icons.move_to_inbox_outlined` (20/18dp), labelled Received Group. The Unseen
thumbnail badge now uses the shared 20dp overlay extent, a contrasting theme
outline, 6dp inset and IgnorePointer; selection continues to hide it for Preview.

The actual production-route comparison established the missing Timeline More
mechanism: four Post cases passed, while four Work cases failed because the
button consulted only the raw Post controller. It now uses displayed mixed
membership; Post Statistics still requires actual Posts. Select / View Options
remain independent from the AppBar's Group commands, and empty filtered results
and selection hide the ordinary menu. Large-text tests additionally reproduced
the View Options ListTile trailing-width assertion. The sheet now places the
existing Kurumi dropdown below its label where width/text constraints require
it; desktop retains ordinary settings tiles. No shared Kurumi API was changed.

- `latest-owner-qa-consumers-qualified.log`: `fvm flutter test --no-pub
  test/core/backups/mitemite test/core/bookmarks test/core/posts/listing
  --concurrency 6 --reporter expanded` — **1,344 passed**, exit 0, two native Dart
  VM callback/finalizer diagnostics. This includes twelve real repository/provider
  app-route comparisons (local/received, root/nested, Posts/Works/Pools) at
  **320dp / 200% text**, an actual Grid Size change through View Options,
  selection and empty-result behavior, alias cancel/save/blank/reload/offline
  behavior with unrelated aliases and source authority preserved, and light/dark
  20dp overlay geometry/contrast/gesture/selection checks at two grid sizes.
- `latest-owner-qa-analyze-qualified.log`: **0 errors, 0 warnings, 70 infos**,
  exit 0. Formatting, i18n generation, diff checks and the illustrative mockup's
  JavaScript syntax/behavior/structure checks passed. Canonical contradictory
  Local-heading, device-menu, lock glyph and 8–10dp wording is updated.
- `timeline-owner-qa-valid-reproduction.log`: **4 passed / 4 failed** before
  the mixed-membership fix. Earlier fixture attempts omitted the Pixiv profile
  or awaited a looping empty-state animation and do not establish the cause.
- `latest-owner-qa-consumers-final.log`: **1,332 passed / 12 failed** before
  the large-text layout fix. `timeline-large-text-layout-fix.log` then passed all
  twelve routes; the qualified broader pass above includes the final dropdown
  interaction assertion. `latest-owner-qa-first.log` failed one new fixture
  assertion using an obsolete All-card label, and the second run had a fixture
  compile error; neither is a qualification pass.

### Android continuation on `33aaca7c1` (2026-11-15)

`android-owner-ux-33aaca7c1-build.log`: `fvm flutter build apk --debug --flavor dev
--target-platform android-x64 --no-pub` passed (Gradle 33.4s, existing toolchain
deprecation warnings). Both leased emulator installations match APK SHA-256
`fc018f90a2841aa60936af5f6322cb98ae660c25c4b8e74cace1f4aaa91b4dd7`.
Built runtime `33aaca7c1`, documentation-only HEAD `3431c34b1`. Complete private
before-install archives include `app_flutter`, `files` and `shared_prefs`;
installation used `-r`, with no reset, identity replacement or old backup restore.
Protected physical phones were untouched.

The durable `android-owner-ux-results-33aaca7c1.json` and `owner-ux-*.png` record:

- Emulator 5556: five live General-rated Posts were selected through the normal
  Timeline toolbar and saved with the ordinary bulk Group picker into **144
  Unseen Android QA**, source `45613e37-b93f-4860-9b46-968447bf8ca8`. Publisher
  `f43f6a4a-7850-4bf3-9048-ec0968ef6338` published it through contextual Publish.
  Eight immutable namespace files were copied with per-file hash verification to
  emulator 5554. These are two real independent installs using actual SAF roots;
  the propagation is manual, **not Syncthing/SMB qualification**.
- Emulator 5554 subscribed through the real Subscriptions page. The card showed
  **5 → 5 after Group open → 4 after visible full-Viewer media display**. Only
  that Post lost its marker; the mixed filter appeared. **4 survived app restart**.
  At **320dp / 200% text**, Seen showed the one read Post; Unseen excluded it and
  opened the correct next occurrence (raw index 1 at filtered index 0). This
  second intentional Viewer read produced **3**. Standard selection hid the
  20dp badges for Preview; Select All + Mark Read consumed the three remaining
  unread memberships. The empty active Unseen filter retained its reset, All
  restored all Seen items and hid the filter, and the zero Group badge disappeared.
- The real received Timeline menu opened View Options, with no Copy/Unsubscribe
  Group commands. The ordinary Search Timeline separately showed Select / Stats /
  View Options. View Options rendered at normal width and **320dp / 200% text**.
  Dark-theme screenshots show the incoming glyph, plain count and 20dp overlay.
- Device pencil opened the shared alias editor directly. Emulator 5556 verified
  cancel, live update, app restart, blank-name fallback and restoration of its
  original **Sync emulator A** alias. Emulator 5554 verified a long alias and
  reachable Save/Cancel above the keyboard at **320dp / 200% text**, while the
  copied publisher namespace was temporarily unavailable. Its original empty
  alias was restored. `owner-ux-offline-publisher.json` proves the copied namespace
  was restored with identical hashes; the actual source installation was never
  moved. Emulator 5554's font/density match its saved baseline again; emulator
  5556's display was unchanged. No lost advertisement removed the received Group.
- Android Back verified Subscriptions → MiteMite → Export and Import → Settings.
  The test's subsequent Bookmark Home assertion failed because the outer caller
  returned to Browse. Navigating to Bookmarks then passed the Group checks; do
  not describe that entire initial flow as a pass. Early alias automation left a
  suffix because eraseText deletes before the cursor; corrected selection and
  explicit restart/restore checks passed. A filter attempt hit an underlying Seen
  node; the corrected popup action passed. The empty-state label is **No data
  available**, not the initially asserted No bookmarks. Failed flows and early
  loading-frame screenshots are not acceptance evidence. Existing Groups were
  not all empty; their delayed cover loading initially obscured existing members.

The new source Group/publication/subscription and its five records remain for
further acceptance; receiver reading is now all Seen. Cleanup must use the normal
scoped actions, never restore older signing/revision authority. Leases need fresh
claims/renewal before every operation; emulator 5556's earlier lease may expire
while emulator 5554 is being tested. Native OS notification delivery/permission/
tap/dedup, Pixiv gestures, light-theme inspection, remaining SAF fault cases,
remaining v5 durability/isolation/retention/recovery and complete repository
regression are still outstanding. The native notification work below supersedes
that notification limitation. Hibernate only after all authorized work and the
final saved/pushed handoff are complete.

### Native Android discovery notifications on `33aaca7c1`

Actual OS delivery, channel, privacy, warm/cold tap, durable deduplication and
permission denial are now qualified on emulator 5554 with the same APK. Three
**host-generated production-signed fixtures**, each with a valid empty Bookmark
package/catalog and a distinct untrusted identity, supplied discovery inputs.
These fixtures are not additional app installations and are separate evidence
from the real two-install Group exchange above. Their private signing keys were
not persisted; their signed files remain in the ignored artifact directory.
No source installation identity or discovery receipt was reset.

- The Android notification shade displayed **MiteMite** and the generic review-
  identity body, without the fixture device name or untrusted collection title.
  `native-notification-warm-channel.json` records channel
  **mitemite.discovery.v1 / MiteMite Devices**, importance 3,
  **PRIVATE**, **ONLY_ALERT_ONCE** and **AUTO_CANCEL**. Warm tap opened the actual
  Subscriptions route; Trust Device remained required and collection titles
  remained hidden.
- For cold tap, the alert was posted during a foreground scan, then the app was
  backgrounded and killed through Maestro's process-death operation. **pidof
  confirmed no app process**, while Android retained exactly the cold fixture's
  notification (`native-notification-cold-before-tap.json`). Tapping it started
  the app and opened Subscriptions. An initial immediate Trust Device assertion
  raced service loading; the subsequent completion-based wait passed, and Back
  popped once to Browse. This proves cold **tap navigation**, not detection while
  terminated.
- The warm notice did not reappear during the cold-fixture scan. After cold tap
  and app restart, Android held zero active discovery notices. Both keys remained
  suppressed through subsequent scans.
- Only POST_NOTIFICATIONS was revoked for the denial case. The app was opened
  through the Android launcher, and the **actual Android permission prompt was
  denied**. The new publisher remained visible as untrusted in Subscriptions,
  with no active OS notice (`native-notification-denied.json`). The original grant
  **and exact permission flags** were restored. Two explicit Update Now scans
  then produced neither a repeat nor a backfilled denied notice
  (`native-notification-dedup-after-regrant.json`).
- Only the three fixture copies were removed, after comparing every path/hash
  against the retained generated files; the original A/B namespaces were left
  intact. Normal discovery Activity/receipts remain as audit history. The QA
  Group's zero badge also survived these process deaths and permission changes.

`owner-ux-qa-checkpoint.json` records both apps stopped, complete private
`owner-ux-qa-checkpoint.tar` archives, restored display settings and **released
leases**. The namespace, aliases and notification grant/flags were restored;
the new QA Group/publication/subscription remains intentionally available for the
remaining acceptance. Reclaim exact serials before any further operation. Keep
working on the outstanding v5 features, Pixiv gesture/light-theme/remaining SAF
acceptance and final full regression; this checkpoint is not task completion.

## Previous checkpoint: `3782f5770` — standard Pixiv Work selection

Pixiv Work timelines now use the existing ordered selection controller, selection
bar, keyboard/back handling and Preview. Long press selects a Work; image and
caption taps add/remove occurrences. The ordinary Work Bookmark action supports
one or multiple actual Work references through the existing Group picker and
atomic typed-draft save. It never converts a Work into Page bookmarks. Captured
actor/occurrence checks reject stale callbacks and profile loss before mutation.
Other native presentations must explicitly opt into selection actions.

- `native-work-selection-consumers-qualified.log`: `fvm flutter test --no-pub
  test/boorus/pixiv/works test/core/bookmarks test/core/content test/core/selection
  test/core/posts/listing --concurrency 6 --reporter expanded` — **1,481 passed**,
  exit 0; one native Dart VM callback/finalizer diagnostic. Nine new production
  native-grid/Hive cases cover single/multiple Work saves, ordinary selection,
  caption/keyboard actions, 320dp/200% text, new-Group creation with the keyboard,
  refresh, lost actor, stale callbacks and an opt-out presentation. The Viewer
  return test records its route boundary; media loading is disabled in these
  fixtures, so this does not establish decoded-media or Android acceptance.
- `native-work-selection-analyze-qualified.log`: **0 errors, 0 warnings,
  33 infos**, exit 0. Dart formatting, diff checks and the illustrative mockup's
  JavaScript syntax/behavior checks passed.
- Tested unpublished `a46e459da` was replayed over owner documentation-only
  commits `d6ee88508` and `2a3b87b19` as `3782f5770`; runtime/test/package/tooling
  tree comparison was empty. The replay is pushed to the feature branch.
- The rejected-create regression drains the known oktoast error-toast clock and
  awaits queued real I/O through completion signals. Earlier failed/interrupted
  fixture runs are not passes. Production timer assertions remain enabled.

Next: implement the latest owner QA additions (no Bookmark Home Local heading,
real Timeline More/View Options investigation, incoming Group glyph, 20dp Unseen
overlay and direct device-alias pencil), then the outstanding v5 durability,
failure isolation, retention and recovery work. Complete repository regression
and the final APK's two-device Android acceptance remain outstanding. Both
emulators are stopped on `ee124f356`, with retained data and released leases.
Do not hibernate until all authorized work and the final handoff are complete.

## Previous checkpoint: `5bb273980` — native device discovery notifications

Discovery now uses Android system notifications on the distinct
`mitemite.discovery.v1` channel, through the existing application-owned native
notification plugin. It retains the download tap callback; download routing
ignores MiteMite payloads. Notifications have a generic localized body and private
lock-screen visibility, without untrusted collection titles/counts. Durable
publisher+fingerprint receipts suppress repeat scans/restarts; stable per-key
native tags/IDs replace a prior notice if delivery succeeded before a receipt
write failed. Failed alerts do not starve independent publishers.

Denied permission or disabled Device Notifications records discoverability in
Activity/Devices without a toast. The receiver-local preference persists without
changing publication settings, identity or transport. Native initialization and
receipt failures remain retryable. Foreground/resume scans detect devices; no
terminated-app detection is promised. Warm/cold notification taps open
Subscriptions through the real application navigation owner, without granting
trust. Duplicate taps while already open are consumed rather than reopening the
page after Back; post-frame delivery/navigation explicitly schedules a frame.

- `discovery-native-final.log`: `fvm flutter test --no-pub
  test/core/backups/mitemite test/download_activity
  test/core/bookmarks/bookmark_folder_ux_test.dart --concurrency 6
  --reporter expanded` — **241 passed**, exit 0; one native Dart VM callback/
  finalizer diagnostic. Coverage includes actual native-plugin channel messages,
  permission denial, disabled preference, concurrent polls, restart/dedup,
  fingerprint change, unrelated history, initialization/show/receipt failures,
  foreground loss, shared download taps and production warm/cold navigation.
- `discovery-duplicate-tap-red.log` reproduces both warm/cold duplicate taps
  reopening management after Back; the final candidate fixes both. Earlier
  host fixtures omitted the external-effects wrapper or unrelated storage
  permission override, and waited for looping Home animations. They are failed
  evidence only. The harness now optionally mounts a selected production effect
  around its normal CoreApp; all other callers retain the previous default.
- `discovery-native-analyze-final.log`: **0 errors, 0 warnings, 49 infos**, exit 0.
  Dart formatting, i18n generation and diff checks passed.
- Native channel calls above are host-controlled plugin evidence. Actual Android
  OS delivery, permission UI, notification tap and two-device acceptance still
  require the final APK; installed emulators remain `ee124f356` with released
  leases. Complete repository regression remains pending, including all users of
  the shared notification wrapper and the additive headless-harness option.

The Work selection step is now implemented above. Final Android delivery and
the outstanding v5 work still require verification on the final candidate.

## Previous checkpoint: `8a19d0c41` — final terminology and readable Storage Location

The final label map from owner commits `2e544fbea` / `75cf7851c` now governs the
UI and canonical specification. Published, Publish to MiteMite, Subscriptions,
Devices, Activity, Update Now, Last Updated, This Device and Device Details use
the approved English Title Case. Devices provides identity/trust/Edit/Forget;
Subscriptions retains approved offers and direct subscription management. Device
section actions open Devices. Ordinary Post/link/file Share is unchanged.

Storage Location reuses Auto Backup's display-path implementation. Its optional
access validation uses the existing read-only directoryDisplayName channel call
before decoding external-storage paths; it never prepares a backup directory.
Opaque providers supply their actual display name. Absent, invalid, revoked or
unnamed content locations show localized guidance with the existing actionable
location row; raw content URIs never become display fallbacks. The stored opaque
URI and all transport/identity/checkpoint/read state stay unchanged. Display-only
lookups refresh after location changes, reconciliation and failure/recovery.

- `mitename-location-qualified.log`: `fvm flutter test --no-pub
  test/core/backups/mitemite
  test/core/backups/auto_backup_android_repository_test.dart
  test/core/backups/auto_backup_layout_test.dart
  test/core/bookmarks/bookmark_folder_ux_test.dart --concurrency 6
  --reporter expanded` — **230 passed**, exit 0. Tests include primary/removable
  volumes, opaque provider names, absent/invalid/revoked paths, unchanged ordinary
  filesystem paths, restored permission/name refresh, no prepare call, 320dp /
  200% text, actual clipboard, committed subscribe state and mobile/desktop Back.
  Earlier obsolete text selectors and missing scroll-layout waits were corrected
  before the pass. Android-native SAF evidence for this change is still pending.
- `mitename-location-analyze-qualified.log`: **0 errors, 0 warnings, 70 infos**,
  exit 0. Dart formatting, i18n generation and diff checks passed.
- The prior compact-management runtime was replayed unchanged from unpublished
  `415cf507c` to `848b41636` over concurrent owner-only documentation. The exact
  runtime/test comparison is empty; its 85-test evidence below remains historical.
- Complete final repository regression, native notifications, Pixiv timeline
  selection and fresh two-device acceptance remain open. Both emulators remain
  stopped with released leases and their previous `ee124f356` APK/data.

## Previous checkpoint: `848b41636` — compact MiteMite management

Owner naming commit `79f515f14` is preserved; **MiteMite** replaces only the visible
feature label. The other proposed page/action labels remain unapproved. Internal
transport, paths, signing and persistence names have not changed.

This device now presents its name/status compactly. ID and fingerprint are behind
Device details with accessible copy actions. Publish lists direct roots without
leading upload icons, redundant All children subtitles or prominent stop icons;
More offers the existing overlap-aware confirmed Stop publishing operation. The
alias action is Edit and an empty alias retains its existing reset semantics.
Subscribe shows its committed Subscribed state without a success toast; errors
retain the existing feedback and ownership guards.

- `compact-management-qualified.log`: `fvm flutter test --no-pub
  test/core/backups/mitemite/bookmark_mirror_engine_test.dart
  test/core/backups/mitemite/following_service_test.dart
  test/core/bookmarks/bookmark_folder_ux_test.dart --concurrency 6
  --reporter expanded` — **85 passed**, exit 0. Covers actual publication menu +
  confirmation, direct/inherited scope, real subscription status, clipboard
  delivery from hidden identity details, 320dp / 170% text + keyboard, alias edit
  at 150%, and production mobile/desktop Settings Back behavior. The initial
  copy test needed a frame after scrolling before tapping; it was corrected
  before this pass. Earlier localization compile failures do not count as passes.
- `compact-management-analyze-qualified.log`: **0 errors, 0 warnings, 29 infos**,
  exit 0. Dart formatting, i18n generation and diff checks passed.
- Complete repository regression and fresh Android acceptance remain pending.
  The existing 1,401-consumer pass below qualifies only `22a0f57e9`.

Native system notifications and standard Pixiv timeline Work selection are still
next. The two released emulators retain their data and the older `ee124f356` APK;
no new device evidence is claimed for these UX commits.

## Current continuation: `22a0f57e9` — received member read filtering

The application now renders top-right, noninteractive accent Unseen dots with a
contrasting dark outline and Seen/Unseen semantics only on received member cards.
The dot disappears during selection so Preview retains its existing slot. The
ordinary listing controls show All / Unseen / Seen only for mixed complete
membership or an active filter; the reset remains reachable at 320dp / 200% text,
including empty results. Search, sort and availability do not change read state.
Filtering preserves the raw Post-controller indices and reconciles hidden
selection. Typed Work references keep their own portable identity.

Viewer routes capture the filtered occurrence sequence plus exact read provenance.
Collapsed subtree duplicates use root membership first, otherwise the first
source-ordered descendant, independently of display sorting or read state. A
captured occurrence validates publisher/source/member before acknowledgement and
cannot mark another Group's duplicate membership read. Parent badges retain the
complete independent Unseen union. Local Groups and All Bookmarks have neither
read marker nor filter. Reading also preserves the mirror's retired status.

Verification of this unchanged runtime/test candidate (unpublished `1430fb05f`, replayed as `22a0f57e9` over the owner-only naming documentation; runtime/test tree comparison is identical):

- `seen-filter-consumers-qualified.log`: `fvm flutter test --no-pub
  test/core/bookmarks test/core/backups/mitemite test/core/posts/details
  --concurrency 6 --reporter expanded` — **1,401 passed**, exit 0. Includes the
  production grid/filter/selection regression at 320dp / 200%, mixed native Work
  projection, independent Group read state, source provenance after unsubscribe,
  restart serialization and existing still/video foreground-frame gating tests.
  One native Dart VM callback/finalizer diagnostic remains.
- `seen-filter-analyze-qualified.log`: affected runtime/tests — **0 errors,
  0 warnings, 43 informational findings**, exit 0 with `--no-fatal-infos`.
  Changed Dart formatted; i18n generated; `git diff --check` passed.
- Earlier fixture attempts are failed evidence only: duplicate provisional IDs,
  incorrect helper calls, a nullable-owner compile check and waiting for the
  looping empty-state Lottie were corrected before the qualified run. The
  obsolete failing broad runner was interrupted and does not count as a pass.
- No APK/device or complete repository regression is claimed for this candidate.
  Both released emulators still contain `ee124f356`. Next implement the remaining
  approved native notifications, compact management and Pixiv selection UX, then
  qualify the final source with complete regression and fresh Android acceptance.

## Previous checkpoint: `68cb95b1c` — persistent Unseen Group badges

The [final owner UX handoff](144-final-owner-ux-implementation-2026-11-14.md) is
now the governing contract. Continue the remaining UX tasks before returning to
the outstanding v5 durability/platform work. The later owner decision `79f515f14` approves MiteMite as the visible name. Only
the existing feature branch may be pushed; no develop integration, PR or closure.

- Received Group cards use the persistent `members - readMembers` set and show
  plain **N**, hidden at zero. Publisher-scoped parent unions deduplicate portable
  identities while keeping each Group's read flags independent. The production
  browser no longer calls the legacy arrival acknowledgement on empty or rendered
  Group open. Existing private journal/reading fields remain unchanged.
- Removed the obsolete folder glyph and folder/sync combination from Group
  cards. Device headings now put the name first, an expanding divider between,
  and the management action last; long names truncate within a bounded width.
- The canonical specification, mockup and earlier QA note explicitly adopt the
  new contract. The mockup now preserves Group counts on open, uses a top-right
  Unseen dot hidden during selection, conditional Seen filtering and captured
  filtered Viewer indices. These mockup behaviors do **not** establish that the
  corresponding application marker/filter work is implemented yet.
- `persistent-unseen-bookmark-consumers-2.log`: unchanged committed candidate,
  `fvm flutter test --no-pub --concurrency 6 --reporter expanded
  test/core/bookmarks test/core/backups/mitemite` — **1,120 passed**, exit 0.
  One native Dart VM callback/finalizer diagnostic remains. The earlier broad
  attempt failed on an uncontrolled favicon in the new app-router fixture;
  deterministic existing test media adapters fixed the fixture before this pass.
- The new real app-router/provider/Hive test proves **5 before open, 5 after
  returning, 4 after marking one specific member read**, with no Group-open
  metadata write or transport access. The repository projection test proves
  independent parent/child read flags, deduplicated counts, serialized state
  retaining 2, source rename preserving state and zero after all relevant reads.
- `persistent-unseen-count-analyze.log`: **0 errors, 0 warnings, 30 infos**, exit 0
  with `--no-fatal-infos`. Changed Dart formatting, i18n generation and diff checks
  passed. `final-owner-mockup-check.log` records JavaScript syntax/behavior checks
  for persistent counts, filter reset, selection-dot collision and captured
  filtered Viewer navigation. No new Android APK or final full regression is
  claimed for this newer runtime.

Remaining owner UX work: application top-right per-member indicators and
All/Unseen/Seen filtering; typed/filtered Viewer provenance and selection;
standard Pixiv Work timeline selection and multi-Work Bookmark action; native
Android notification permission/dedup/tap handling; removal of Subscribe success
toasts; compact device/details and Publish management, alias Edit labels and the
remaining responsive/accessibility cases. Finish their required regressions,
then run the exact-final-candidate complete suite and Android acceptance. The
underlying v5 activity/failure durability, independent-root isolation, retention,
identity repair and additional SAF scenarios below remain open as well.

Both emulators are stopped with complete private Following QA checkpoints and
**released leases**. They still run `ee124f356`, not this new Unseen implementation.
Test data and signing/revision state are retained; claim fresh exact-serial leases
before updating them. Never restore old archives over newer identity authority.

## Previous checkpoint: `ee124f356` — Following service/UI integration

This section supersedes the checkpoint below. The feature branch remains the
only publication target. Issue #144 is **incomplete**; no PR, merge or closure is
authorized. Continue implementing and qualifying the remaining approved v5 work.
No owner decision is currently blocking implementation: Following folder/Feed
scope includes current and future descendants; the two existing emulators are
authorized, subject to fresh exclusive leases. Protected physical phones remain
outside this task.

### Connected behavior and safety

- Publication settings and catalogs retain typed Bookmark/Following roots, even
  when both domains have the same source UUID. Local Topic/folder definitions
  publish through the signed package writer. A folder and its Feed use one source
  identity; current/future descendants and overlapping direct rules share one
  revision history. Mirror definitions never become outgoing Local definitions.
- The production service now orchestrates Following receive and refreshes the
  **real** Following notifier from the committed journal snapshot. Incoming data
  retains source ownership; compatible existing local profiles bind safely and
  missing/ambiguous profiles remain paused. Runtime/cache/NEW/auto-update state
  remains receiver-owned. Ordinary Following UI does not activate Sync storage
  merely by being opened on an unconfigured installation.
- Following Home shows Local and per-device sections, canonical independent root
  links, inherited publication indicators and source-owned structure. Received
  Topics/folders reject ordinary edit/delete/move/reorder/mixing/republishing and
  keyboard selection; compatible operational refresh and auto-update remain
  available. Local copies stay visible even when their original profile is
  unavailable. Feed menus address the same owning folder and hide source edits.
- Definition receipts have their own outlined sync-dot/detail action. Expected
  digests prevent an old view/detail from consuming a newer change. Source
  engine/site changes now affect the definition digest; existing v1 receipts
  upgrade without manufacturing a new notice for unchanged definitions. Post
  NEW/read and refresh state remain independent.
- Forget first persists an intent and revokes shared trust, then completes both
  domain journals before clearing the intent. Restart recovers an interrupted
  second-domain cleanup before any reapproval or receive. Local copies and
  anti-rollback checkpoints survive. Shared activity links preserve source kind.
- The new real-provider UI regression exposed two actual UI defects: a missing
  profile merged the action button into the entire card's accessibility label,
  and a long menu escaped the screen at 320dp/200% text. Received menus now have
  their own semantics boundary; long Topic/folder menus scroll within a bounded
  anchor surface and use at least 48dp rows. Consumer tests scroll real menus and
  retain their behavior assertions. This is not yet a complete popup target audit.

### Exact scoped verification

Unchanged runtime/test candidate committed as `ee124f356`:

- `following-integration-consumers-final-3.log`: `fvm flutter test --no-pub
  --concurrency 6 --reporter expanded test/core/backups/mitemite
  test/core/search/following_topics test/core/backups/sources
  test/core/backups/export_import` — **1,249 passed**, exit 0. The log contains
  **one** native Dart VM callback/finalizer diagnostic; this remains unresolved.
- `following-review-analyze-final-2.log`: affected Sync/Following source and test
  analysis — **0 errors, 0 warnings, 229 infos**, exit 0 with `--no-fatal-infos`.
  Changed Dart formatting, localization generation and `git diff --check` passed.
- New tests use two genuinely separate Hive libraries/paths and real domain
  repositories. They cover typed UUID collisions, future descendants, no outgoing
  echo, independent auto-update state, overlap unsubscribe, interrupted Forget,
  source-profile changes and stale receipt rejection. The production widget test
  uses the real Following notifier/repository and reload callback, including
  paused profiles, read-only menus, definition detail acknowledgement, keyboard
  exclusion, Local Copy and subsequent ordinary Local folder edits with mirrors.
- `following-scrolling-menu-qualified.log`: **98 passed** for the final menu,
  Following page and real-provider paths, including 320dp/200% interactions.
  Earlier broad attempts failed on obsolete Material finders and the actual
  off-screen action defect; the first was interrupted during an additional
  fake-clock/real-I/O harness stall and is not pass evidence. New I/O-dependent
  widget operations use completion signals while pumping the fake scheduler.

### Later verification of `ee124f356`, before the final owner UX pass

- `regression-following-ee124f356.log`: complete runner stopped after the app
  suite at **7,334 passed / 1 failed**, exit 1. The failing sharing consumer still
  searched for a Material Following menu after its Kurumi conversion. Package,
  CLI and tooling stages were **not reached**. The log contains **58** native
  Dart VM callback/finalizer diagnostics. This is not a complete green result.
- `following-link-menu-consumer-fixed.log`: both unchanged sharing behavior
  cases passed after targeting the actual modern Topic menu and retained legacy
  Feed menu separately. The complete suite still needs its final-candidate repeat.
- `android-following-ee124f356-build.log`: debug dev x64 APK built successfully.
  Both authorized emulators were updated without clearing data. Installed and
  archived APK SHA-256 is
  `695590eebbb1b2ac66f081784c2fb2b68ac00af8359761eb412aa9102fed0dbe`.
- Genuine Android/SAF Following exchange used the existing separate installation
  identities/grants and controlled immutable host propagation with hash checks.
  A folder/Feed published before its Topic was created offered only that root;
  the receiver immediately showed Subscribed, Local/device sections, the future
  Topic and compatible local profile. Its inherited Topic menu omitted source
  edits/Publish/Unsubscribe. Receiver auto-update toggled off, Local Copy created
  an independent Local Topic, and a source rename reached the original mirror.
  The received Feed reused its owning folder and exposed only permitted actions.
  Native Back dismissed the popup before leaving the Feed. This does not qualify
  Syncthing/SMB, missing-profile Android behavior or Following Post NEW transitions
  (the test query returned no Posts). Preference persistence after the rename was
  not separately rechecked on Android; its host regression is recorded above.
- Exact source IDs/results, three main screenshots and complete private before/
  after archives are in the durable artifact directory; see
  `following-android-results-ee124f356.json`. Visible Kurumi popup labels were
  absent from Maestro's Android hierarchy, so some actions used coordinates
  identified from inspected screenshots. Failed text assertions are not reported
  as passes. The folder AppBar also truncates excessively with its existing
  controls; these UI/accessibility limits need remediation and requalification.
- Both apps are stopped; complete `app_flutter`/`files`/`shared_prefs` checkpoint
  archives are private. Display settings are unchanged and **both leases are
  released**. Retain test publications, mirrors, Local Copy, trust and revision
  state for continuation; final test cleanup is pending. Reclaim exact serials
  before further operations and never restore older signing/revision authority.

The final owner UX contract at the top of this handoff supersedes **all older
arrival-badge/Group-open acceptance descriptions below**. The old APK and tests
are historical evidence, not qualification of persistent Unseen count `N`.

### Remaining implementation and qualification

The two owner documentation commits `f26335ac6`/`fd1cb3e23` arrived while the
local integration was being qualified. Both are preserved. The unpublished local
commits were replayed on top; `git diff e9feb67f1 ee124f356 -- lib test packages`
is empty, so the scoped runtime/test evidence remains applicable. Apply the
linked UX supplement as well: native notifications without discovery toasts,
compact device/details and publication management, Edit alias action, left-aligned
device headings, per-Post Unseen markers/conditional filters and concise
Subscribed status. Keep the feature name unchanged pending an explicit choice;
the documented Pixiv timeline selection item requires separate source review.


Continue with durable crash-safe activity/failure receipts, isolation between
independent subscriptions/publication roots, notification preference/OS delivery,
owned-file retention, actionable partial-identity repair and subtree Viewer/Mark
Read provenance. Review manual import/rollback alongside mirrors: current storage
protects received data by rejecting whole-profile restore calls, but a failed
ordinary import needs a Local-only recovery route that preserves live mirrors and
all their runtime/checkpoints. An unbound Local Copy remains visible, but its
ordinary edit dialog currently requires the original profile; explicit safe local
profile recovery still needs work. Following Feed/header/device scenarios need
actual Android qualification. Full SAF revocation/provider/termination/relocation
acceptance, final full regression and test-state cleanup remain open. The prior
complete `003982a24` run is not evidence for this candidate.

## Earlier checkpoint: `00ea7cdac`

This section supersedes earlier checkpoints below. Work is pushed only to
`feature/144-folder-based-collection-sync`. Issue #144 is incomplete; no PR,
merge or closure has been performed or authorized.

### Latest scoped Android correction

After the complete `003982a24` regression pass, actual Android testing at 320dp
and 150% text exposed Save/Cancel under the keyboard in the device-name/alias
dialog. The controlled widget reproduction failed with Save at y=435 while the
keyboard began at y=380 (`alias-keyboard-red-final.log`). `00ea7cdac` applies the
same keyboard-inset padding as the existing Bookmark name dialog and preserves
Kurumi styling, scrolling and validation.

- `alias-keyboard-green-engine.log`: all **24** real-provider/management engine
  tests passed, including the new keyboard geometry and successful alias save.
- `alias-keyboard-analyze.log`: 0 errors, 0 warnings, 26 infos, exit 0 with
  `--no-fatal-infos`. Formatting and `git diff --check` passed.
- Debug dev x64 APK build passed. `emulator-5556` was updated without clearing
  data; installed SHA-256
  `aaddf31189b446bbb3ad8058b8df3919343aab43977fb2c4d3af87fce7a21727`
  matches this build. The actual 320dp/150% keyboard repeat visibly exposes both
  actions above the keyboard, and Cancel closes the dialog. Evidence:
  `alias-keyboard-fixed-320.png`. Original font scale and display size were
  restored; `display-test-state.json` records restoration.
- `emulator-5554` still has the earlier `003982a24` APK with hash recorded below.
  The **complete** suite pass belongs to `003982a24`, not to the later dialog
  change. Final full verification is required after the remaining v5 runtime
  work; this scoped correction is not a complete-issue qualification.

### Following and committed-display recovery

- `cef3deaa4` publishes one credential-free Topic or folder/Feed definition in
  the existing `.bsexport` envelope. Protocol identity remains
  `(publisher, following_topics, source UUID)`; the backup source identifier
  intentionally remains `pinned_searches` for compatibility. Source profile
  references contain canonical engine/site hints, with credentials, private
  labels, runtime/cache/NEW and automatic-refresh preferences excluded.
- `a1c9494c5` adds bounded Following revision preparation and the receive engine,
  using the existing signed catalog gate and journaled Following storage.
  Current/future descendants follow the owner's explicit approval. Canonical
  overlapping roots, signed withdrawal, retirement/replay floors, independent
  local copies and offline overlap-aware cleanup are covered by real Hive tests.
  Missing/ambiguous profiles remain unbound; one compatible existing local
  profile may bind safely. No saved profile or credentials are created.
- Source rename retains local runtime and refresh choices; a material query or
  profile-binding change resets only that Topic's incompatible execution state.
  Definition receipts are separate from Post NEW/read state. Folder name scopes
  are derived from authoritative ownership, never trusted from imported JSON;
  equal Local/device section names are allowed without weakening local sibling
  name validation or repository mutation guards.
- The complete app run at `a1c9494c5` exposed one genuine regression: keeping
  signed sparse positions also stopped compacting stale Local Home entries.
  That run finished **7,328 passed / 1 failed**, exit 1; package/tooling steps
  were not reached. `828ffdb1b` preserves received positions and restores Local
  normalization. The unchanged failing repository test and sparse-position
  mirror regression then passed together.
- `003982a24` distinguishes a durable mirror commit from a failed consumer
  display reload. Receive projects the newer committed ownership, records the
  subscription/activity, shows a localized display-refresh-pending state and
  offers a transport-free retry. It does not suppress repository-read failures
  or claim the stale listing has refreshed. The fault-injection widget test uses
  the real Bookmark notifier/repository, verifies read-only authority during
  reload failure, then successfully retries with shared-folder access disabled.

The Following engine is a tested foundation, **not activated Following Sync**.
Remaining integration includes service orchestration and typed publication roots,
Following provider reload/change detection, trusted Receive management, Local/
device sections, unavailable-profile presentation, definition indicators and all
read-only UI/keyboard/bulk/import paths. Do not enable incoming Following data in
the current ordinary page: it assumes every displayed Topic has a saved profile
and does not yet provide the required device sections and guarded actions.
Cross-domain Forget needs recoverable orchestration before activating it.

### Exact verification and Android evidence

- `following-package-final.log`: 19 passed (new package tests plus publication
  pipeline); final package analysis: 0 errors, 0 warnings, 7 infos.
- `following-namespaced-consumers.log`: 806 passed before the subsequent sparse
  Local-order correction. This is scoped intermediate evidence.
- `following-sparse-green.log`: 8 passed on the engine/journal state with sparse
  positions; `following-local-order-fix.log`: 59 passed after the correction.
- `final-foundations-focus.log`: **87 passed** on the final runtime/test state,
  covering Bookmark engine/real provider, explicit publication roots, Following
  engine/journal and ordinary Following repository. Analysis of MiteMite,
  Following repository/organization, shared tree and Sync tests: **0 errors,
  0 warnings, 110 infos**, exit 0 with `--no-fatal-infos`.
- `regression-refresh-candidate.log`: complete `./scripts/run_regression_tests.sh`
  on unchanged runtime/test candidate `003982a24`, concurrency 6: **7,330 app,
  1,706 package/CLI tests across 13 suites, 76 Python tests and both shell suites
  passed**, `REGRESSION_EXIT=0`. Two go_router tests were skipped. The log still
  contains **61 native Dart VM callback/finalizer diagnostics** despite exit 0;
  this unresolved diagnostic is not a clean native-runtime qualification.
- `android-refresh-build.log`: `fvm flutter build apk --debug --flavor dev
  --target-platform android-x64 --no-pub` succeeded (toolchain deprecation
  warnings). APK SHA-256
  `b36acb19e461d3d370d9bb55c2a446777b8a2ea9aa39fa4c47ee7c8d3565cd5a`
  matches both data-preserving installed APKs. This is the normal `main.dart`
  debug dev build; no app data was cleared.

Both emulators independently selected `/sdcard/Documents/Boorusama144Test`
through Android's actual SAF picker and confirmed the grant. They have distinct
installation identities: `emulator-5554` =
`18a17c4f-9084-424f-be39-3ce22ee1bca2`; `emulator-5556` =
`f43f6a4a-7850-4bf3-9048-ec0968ef6338`. Signed immutable files were propagated
in both directions through the host, with hash verification and conflict refusal.
This is genuine independent Android/SAF library exchange with **controlled file
propagation**, not Syncthing/SMB transport qualification or a host-Hive substitute.

Executed on reading runtime `a02a40fca` before the update:

- Contextual Publish named A and its recursive scope. B was created afterward;
  receive applied B as a descendant while offering only A. Explicitly publishing
  B then exposed B as a second offer. Before approval, Receive showed only the
  labeled ID/fingerprint and Trust action, with no collection label.
- Subscribe immediately became Subscribed. Bookmark Home displayed Local first
  and a separate device section. Received menus offered Local Copy/Unsubscribe,
  without ordinary source-edit actions. Unsubscribing A reported removal of one
  Group and retained independently subscribed B at device root.
- A received B was copied locally, renamed independently and published from the
  second install. The first install discovered that independent publisher,
  displayed the in-app new-device notice, required separate fingerprint approval
  and subscribed successfully. No mirror was republished as local data.
- A receiver-local device alias appeared in Receive and Home. After force-stop
  and data-preserving relaunch, SAF access, identity, publication/subscription and
  alias survived; Sync reached Ready.
- A new incomplete `catalog/999.json` was injected only in the dedicated copied
  test namespace. Sync showed partial failure while the received B and local
  copy remained. Only the injected file was removed; Sync returned to Ready.
  `partial-catalog-fault.json` records completed cleanup. This is partial-catalog
  validation, not a grant-revocation or process-death transaction test.
- A real Post was added to A through Browse -> Viewer -> Bookmark Group picker
  and its new revision propagated. Nonempty Group/Viewer acceptance on the
  updated APK is recorded below.

Executed on the hash-matched `003982a24` APK:

- Both installs retained their libraries, signing IDs and Sync state across the
  data-preserving update. Initial UI hierarchy reads after relaunch sometimes
  exposed only the status bar while screenshots showed app content. Bounded
  Maestro waits recovered; no reset, driver changes or performance pass is
  claimed from these observations.
- Receiver A displayed `+1`; opening it rendered its child Group and the received
  Post listing. The full Viewer visibly displayed the decoded received image.
  Returning Home showed the arrival acknowledged. Source added that same Post
  to B through the nested Group picker, and the new revision propagated.
- A then showed the aggregate `+1` for unopened B; B showed its own `+1`.
  In B, selecting the Post offered Mark Read despite its earlier Viewer visit
  through A. Applying Mark Read kept selection active and removed the action.
  This qualifies direct-Group still-image selection/reading independence; it
  does not qualify video, Work/Page or subtree reading.

Artifacts, propagation manifests and `receive-overlap-alias.png` are in the
ignored durable artifact directory recorded below. The earlier files named
`before-candidate-app-data.tar` / `before-refresh-candidate-app-data.tar` contain
only `files` and `shared_prefs`: **they omit `app_flutter` and are not complete
rollback backups**. Current checkpoint archives explicitly include `app_flutter`,
`files` and `shared_prefs` and have private permissions. No archive has been
restored over the installations; existing app data has only been updated through
normal UI and verified Sync. Both test apps are now stopped, final consistent
`final-qa-app-state.tar` archives are private, and both emulator leases have been
released. Reclaim the exact serials before any further operation; the retained
token file is historical and does not grant a lease. Display settings are
restored. Dedicated test Groups/publications, trust, signing identities, replay
floors and reading state are deliberately retained for continuation; final test
data cleanup is still pending. Do not restore old archives over newer signing or
revision authority. `emulator-qa-checkpoint.json` records this state.

Still open beyond Following integration: durable crash-safe activity/failure
recording, independent subscription failure isolation, OS notification
preference/delivery, owned-file retention and actionable partial-identity repair,
subtree Viewer/Mark Read provenance, full SAF revocation/provider/termination/
relocation cases, enlarged/narrow device UI qualification and final test-state
cleanup. A measured popup target audit is also needed: the existing Kurumi menu
default uses 6-pixel padding around its icon and may fall short of the plan's
48-dp action-target requirement. Physical phones, including protected CPH2769,
remain untouched.

## Local continuation: recovered management candidate

The following supersedes the historical web-only status below. Current committed
reading-checkpoint runtime: `a02a40fca`, following video-read commit `b12fc08e4`, management
commit `3050991f7` and protocol commit `352a230c1`. No merge, PR or issue
closure is authorized. Following and platform acceptance remain incomplete.

- Fetched origin and fast-forwarded the clean existing task worktree from
  `ca2220551` to `5b74f7f0a`. `origin/develop` is an ancestor; no unrelated work
  was reset, stashed or overwritten.
- Decoded the management payload to 111,902 bytes and verified SHA-256
  `13a7604d3f70e694b394911c85093b68dbd72b2488540287ee9ba2ef28cd6ff0`.
  `git apply --check` succeeded. Reviewed the executable changes, including
  signing, direct-root scope, trust-first UI, overlap-safe management, reactive
  consumers, discovery receipts, aliases and local dirty intent. Fixed a missing
  post-await route-lifetime check and made remote identity/fingerprint selectable.
- Removed the encoded patch and both temporary remediation workflows after
  recovery and verification. Raw and decoded recovery evidence is retained in
  ignored durable `.worktrees/_artifacts/144-remediation-2026-11-14/` at the main
  workspace. There is no remaining workflow that applies and auto-pushes this patch.
- Independently reproduced both failures. The original Receive test reports the
  2.3-second oktoast timer assertion, then requires bounded termination (exit 124).
  Explicitly dismissing the toast alone removes that assertion but still strands
  teardown at `Hive.close()` (exit 124). Closing Hive while the widget scheduler
  can pump its fake-zone continuations completes real I/O and exits normally.
  The management harness now dismisses global toasts and drains Hive before
  leaving the widget callback, including assertion-failure cleanup. Production
  success feedback and ownership assertions are retained; no longer sleep or
  suppressed pending-timer assertion was introduced.

Verification actually executed:

| Candidate/check | Result and limits |
| --- | --- |
| Recovered management runtime before final review corrections: `fvm flutter test --no-pub --concurrency=6 --timeout=2m --reporter expanded test/core/backups/mitemite test/core/bookmarks test/application/backup_restore_flow_test.dart` | 1,103 passed; `management-consumers.log`. Host tests, not Android acceptance. |
| Final runtime/test state in `3050991f7`: same command restricted to `bookmark_mirror_engine_test.dart` and `publication_roots_test.dart`, `--timeout=60s` | 27 passed, clean exit; `management-final-focus.log`. Covers the route-lifetime/selectable-identity/import cleanup corrections after the broader pass. |
| `fvm flutter analyze --no-pub --no-fatal-infos` on MiteMite, changed Bookmark page/card, app external effects and Sync tests | Exit 0; 0 errors, 0 warnings, 79 informational findings. Earlier analysis had one unused test import, subsequently removed. `management-final-analyze.log`. |
| `./gen.sh`, changed-file `fvm dart format`, `git diff --check`, `.github/scripts/test-pull-request-policy.sh` | Passed. Translation inputs required regenerated ignored output. |
| Original unmodified integration file | 22 passed after harness cleanup, before final selectable-identity/lifetime corrections. `mirror-engine-green.log` includes one native Dart VM finalizer diagnostic despite test exit 0; this is not a clean native-runtime qualification. |
| Android discovery only | One physical Pixel 4a; no running emulator. SDK has no emulator binary/system images. No operation, installation, reset or data access on any phone. SAF and genuine two-instance acceptance remain pending. |

Outstanding work is still the approved remediation plan's Tasks 7–10: rendered
arrival/read gating, complete Following synchronization and guards, robust change
activity/failure isolation, notification preference/OS integration, bounded
retention/recovery, full final-candidate regression and real SAF/two-device
acceptance. The recovered foreground discovery toast is an in-app fallback; it
does not establish an OS notification preference or delivery. Current automated
checks do not establish Android Back gestures or any two-device behavior.
Owner clarification received on 2026-11-14: Following folder/Feed publication
and subscription include current and future descendant folders and Topics. This
is now recorded explicitly in the specification.
The protected CPH2769 restriction remains in force; another connected personal
phone is not an implicit substitute.

## Local reading candidate: `a02a40fca`

- Nonempty Group arrivals now use the library snapshot rendered by the listing,
  rather than the outer browser build. Hidden, loading, refreshing, failed or
  stale listings cannot acknowledge a newer revision. A meaningful empty state
  still counts; opening a parent does not acknowledge its children.
- Video reading uses the native player's current-source first-rendered-frame
  signal, then checks the settled foreground Viewer and route/destination
  activity. Initialization, hidden/preloaded surfaces and old-source frames do
  not count. Still-image/animated-image decoding retains its existing boundary.
- Received-only Viewer recovery returns transient display media instead of
  attempting to persist a publisher-owned snapshot. Bulk hydration targets local
  memberships and checks local membership again before committing each response.
- Updated the specification and mockup notes for U3/U5: existing direct roots in
  Publish management, explicit-root Receive offerings only after trust. Older
  illustrative HTML checklist controls are explicitly subordinate to those notes.

Exact checks on this runtime/test state:

- New video and Viewer boundary selection (`--plain-name frame`): 11 passed,
  including both new frame/read tests; `video-frame-focused.log`. The player
  boundary uses a controlled player signal, while the Viewer regression verifies
  production callback wiring. Actual native playback was not exercised.
- New arrival/recovery tests (`--name 'arrival receipts|received-only recovery'`):
  2 passed; `arrival-recovery-final.log`. An initial arrival fixture waited for
  every animation to settle and timed out; it now waits for the listing's own
  completion receipt while permitting unrelated media animation. No functional
  assertion was removed. An initial video-test compile failure was corrected by
  explicitly typing the fake player's mutable frame notifier.
- Affected-scope `fvm flutter analyze --no-pub --no-fatal-infos`: 0 errors,
  1 pre-existing warning (`coverUrl` unused in `mixed_post_details_page_test.dart`,
  verified present before these changes), 136 informational findings; exit 1.
  `reading-final-analyze.log`.
- Android Kotlin compile using the installed Gradle 8.14 distribution and
  `:app:compileDevDebugKotlin --console=plain`: BUILD SUCCESSFUL, 506 tasks,
  5 executed / 501 up-to-date. Gradle deprecation warnings remain. No device was
  accessed. The ignored Gradle wrapper is absent in this worktree.
- `./scripts/run_regression_tests.sh`: **exit 0** on `a02a40fca`: 7,318 app
  tests, 1,706 package/CLI tests across 13 suites, 76 Python tests and both shell
  suites passed. Two `go_router` tests were skipped. Completion is recorded by
  `REGRESSION_EXIT=0` in `regression-reading-candidate.log`. Runtime/test source
  remained unchanged during the run; documentation-only edits and source commits
  do not alter its candidate. The log contains 59 native Dart VM finalizer/callback
  diagnostics, still unexplained. This test exit does not qualify native playback
  or device stability.
- Dart formatting, `git diff --check` and mockup JavaScript `node --check` pass.

Owner report traceability (host evidence only unless stated):

| Requirement | Executable evidence / remaining boundary |
| --- | --- |
| U1: one-route Back | Real Settings-shell test in `bookmark_mirror_engine_test.dart`, 390/1024 widths, all three subpages and dialog-first Back; Android button/gesture pending. |
| U2: contextual Publish | Same file's contextual Publish test: exact Group, cancel, complete subtree, no unrelated Group publication. Folder-picker cancellation and stale target/device flows need broader acceptance. |
| U3: published-only management | Contextual Publish test and signed-root tests; overlap preserved by queued publish-intent regression. |
| U4: direct-root offers | `publication_roots_test.dart` and trust-first Receive test; inherited children are applied once without independent offers. |
| U5: trust-first detail | Real-provider Receive test asserts collection labels absent before approval; no untrusted package preparation is admitted. |
| U6: labeled identity | Receive test checks separate ID/fingerprint; remote identity is selectable. Actual clipboard/device interaction pending. |
| U7: new-device notice | `local_events_test.dart`: durable scan/restart deduplication, bounded history; foreground in-app delivery connected. OS notification preference/delivery and notice interaction are pending. |
| U8: subscribed row | Real-provider Receive test checks Subscribed/Unsubscribe and durable mirror owners. Post-commit provider-reload failure remains a source-identified gap described below. |
| U9: read-only device sections | Existing narrow/enlarged received-device UI test plus real provider reload, local-only All Bookmarks and mirror repository guards. Full received-Home-to-Viewer device path pending. |

Still release-blocking, not waived by this continuation:

1. Following publication/receive, journaled ownership and read-only guards, source
   definition indicators, local profile/refresh/cache/NEW preservation, and
   Local/device UI remain unimplemented. The owner has now explicitly approved current/future descendant scope for
   Following folders/Feeds; the implementation must preserve distinct direct and
   inherited reasons and one canonical definition mirror.
2. Complete activity durability/failure history, per-subscription failure
   isolation within a publisher, OS notification preference/delivery, bounded
   owned-file retention and actionable partial-identity recovery remain open.
   Watcher/dirty wiring exists but crash/busy-transition acceptance is incomplete.
3. Source inspection shows `_applied` still propagates an `onApplied` reload error
   after the mirror transaction commits. That can obscure committed subscription
   state and skip later activity recording; a focused fault-injection regression
   and truthful committed-but-refresh-pending projection are still required.
   This is a source finding, not a newly executed failing-provider reproduction.
4. Subtree Viewer/Mark Read still needs explicit originating-Group provenance;
   current direct-Group reading must not be broadened to every matching membership.
   Actual media painting, hidden-route and revision-race device coverage remain
   pending. The new host listing receipt proves current snapshot completion,
   not a physical screen's pixels or native media presentation.
5. The owner made `emulator-5554` and `emulator-5556` available during this
   continuation; both were exclusively leased. Physical Pixel 4a and protected
   CPH2769 remain untouched. Two-instance shared-folder propagation, SAF
   restart/revocation/partial writes, process death and relocation remain required
   until their executed results are recorded below.

## Historical interrupted-web handoff (retained evidence)


Updated: 2026-11-14 UTC. **Review and implementation handoff only; no runtime change was made in this final audit.**

## Baseline and source of truth

- Continue the **existing** `feature/144-folder-based-collection-sync` worktree; fetch latest origin before acting. Remote HEAD inspected: `403b45269a9584f7bcccf9a676dde5ced96a153b`. `origin/develop` inspected: `f77ca1f6841e076afdd48b57e62f2124d1099739` (included in this branch).
- #144 remains **open**; no PR, merge, closure, or release approval. The Collection/Viewer UX work is paused and out of scope.
- Required contract: [approved v5 spec](../designs/2026-11-03-folder-based-collection-sync.md), [original detailed remediation plan](../plans/2026-11-14-mitemite-v5-remediation.md), [v5 interactive reference](../designs/mockups/2026-11-03-mitemite.html), and [prior implementation report](144-mitemite-v5-local-integration.md). Latest owner corrections in the remediation plan take priority over conflicting old v5 mockup/spec language.
- The prior implementation agent reported a **full regression pass at `8bdfdb26b`** (7,300 app / 1,706 package+CLI / 76 Python, two shell suites) and Android Kotlin compile. That is **historical** and cannot qualify the current candidate.
- This handoff is a GitHub-source and Actions-log review, **not** an executed local/device review. Treat the aborted chat's progress messages as preliminary, not proof that the edits were committed or tested.

## Three distinct development states — do not conflate them

### A. Committed runtime, verified by scoped CI

`97c5cc676349ce267f6e634a6ef2e959f5003574` is the latest remotely **committed runtime** in the #144 branch; subsequent commits only changed a CI workflow or a staged patch file.

1. **Mirror authority reload (implemented):** `BookmarkMirrorReader` is a deliberately read-only capability forwarded by `BookmarkMutationRepository`; `BookmarkLibraryService` reads durable mirror ownership through it rather than dropping to `BookmarkMirrorState.empty()` during the production `onApplied → bookmarkProvider.refresh()` path. The regression uses the actual provider callback, rather than only a static snapshot. Files: `lib/core/bookmarks/src/types/bookmark_mirror_state.dart`, `services/bookmark_mutation_repository.dart`, `services/bookmark_library_service.dart`, and `test/core/backups/mitemite/bookmark_mirror_engine_test.dart`.
2. **Nested Settings back stack (implemented):** `lib/core/settings/src/pages/settings_page.dart` now prioritizes the nested content Navigator for Back. Headless regression covers MiteMite → Publish/Receive/Activity at 390 and 1024 logical pixels. **Real Android Back gesture/button has not been exercised** on the final candidate.

Evidence: [successful run 43610299457](https://github.com/timberpile/Boorusama/actions/runs/43610299457), which **applied a temporary patch, ran 1,092 targeted tests successfully, and pushed the verified `97c5cc6` runtime commit**. Analyzer output contains informational findings; this was not a full repo regression. Source-level guard behavior still needs real app/screen verification.

### B. Large, unmerged management/Sync repair patch on the remote branch

The current branch contains `.github/144-remediation.patch` (added in `ddba40dc35bfd8b9fe990cbc66326acb1c0e580f`). It is a **gzip-base64-encoded Git patch**, not committed Dart source. The header's SHA-256 is `13a7604d3f70e694b394911c85093b68dbd72b2488540287ee9ba2ef28cd6ff0`. The decoded patch is 111,902 bytes and affects **18 files** (~1,315 additions, 539 deletions). The archive was decoded and its digest checked in the interrupted web runtime; GitHub Actions also successfully applied it to an ephemeral checkout.

Prepared, **not shipped or accepted** in this patch:

- Direct contextual Group Publish and confirm; published-only management, overlap-aware stop; root-selection state moved into serialized commands.
- Signed direct-publication-root catalog metadata, root-only Receive offerings, trust-first publisher disclosure and Subscribe state handling.
- Labeled device ID and key fingerprint; identity-only discovery; deduplicated local discoveries, notification surface and activity history.
- Reactive Sync view projection, dirty-signal tracking and optional filesystem watcher/polling fallback.
- Device alias management, localized status/error strings and production-level integration tests.

**Critical CI failure:** [run 43613388528](https://github.com/timberpile/Boorusama/actions/runs/43613388528) (source `469f65f`) applied this patch and formatted 16 Dart files. Its first integration test, `trust-first Receive exposes only direct roots and updates Subscribe through real provider`, failed with `A Timer is still pending even after the widget tree was disposed`. The pending fake-async timer (2.3 seconds) originates from `Kurumi.showSuccessToast` in `MiteMitePage._subscription` (`page.dart` line ~473 of the ephemeral candidate). The test runner then stalled until bounded termination (reported exit 137); no later test suite or candidate commit ran. Diagnose both teardown and remaining async resource leakage; merely increasing timeouts or suppressing the timer assertion is not acceptance.

[Run 43612202171](https://github.com/timberpile/Boorusama/actions/runs/43612202171) was cancelled during a previous broad test attempt. [Run 43611895816](https://github.com/timberpile/Boorusama/actions/runs/43611895816) was green **only because no patch existed and all test/commit steps were skipped**. [Run 43613554762](https://github.com/timberpile/Boorusama/actions/runs/43613554762) only cancelled a previous stalled diagnostic; it provides no product verification.

The temporary `.github/workflows/144-remediation-check.yml` can **auto-commit/push** the test candidate after success; `144-stop-stalled-check.yml` is also temporary. Inspect/disable/remove both after safely recovering the work, so an unrelated push does not cause unreviewed automation. Do not mistake the encoded patch file for integrated production code.

### C. Additional local scratch draft, NOT on GitHub

The interrupted web runtime also had a separate **uncommitted, untested diff** against a locally reconstructed candidate containing the large patch. A copy is attached to the conversation as `144-2026-11-14-uncommitted-reading-draft.patch`, SHA-256 `8de6b6e40bed8d4d37e011ee5ebbedb0d909421fc7f17d2f24e6ea811cf823c3`. It changes seven files (~144 additions, 8 deletions): Bookmark Group render-based arrival acknowledgement, receiver-only recovery/hydration limits, BookmarkScrollView revision callbacks, and first-real-video-frame Viewer read gating with a test stub.

**Do not blindly apply it to `403b4526`**: the draft was made *on top of* the unmerged management patch. The draft was not compiled, tested, independently reviewed or pushed. Treat it as optional design/code reference and validate the code and actual APIs before incorporating. If the conversation attachment is not available to the local agent, implement the remaining behavior directly from the approved v5 contract rather than guessing its contents.

## Owner-reported failures: current disposition

| Owner report | Committed HEAD `403b4526` | Next gate |
| --- | --- | --- |
| Android Back skips pages to Settings | Nested Settings router fix **committed**, headless tests green | Real system/gesture Back, dialog-first and context-entry checks |
| Group-card Publish opens generic Publish page | **Not fixed in tracked runtime**; change in encoded patch | Confirm target after setup; confirm current/future subtree; cancel/retry |
| Publish page lists every local Group | **Not fixed in tracked runtime**; patch includes direct-roots management | Existing explicit roots only; stop with overlap-safe consequence |
| Receive lists all inherited descendants | **Not fixed in tracked runtime**; patch adds signed publicationRoots | Direct roots only, separately published children independently offered |
| Untrusted devices show their Groups | **Not fixed in tracked runtime**; patch hides pre-trust detail | Device identity/trust only, no preview, post fetch or metadata disclosure |
| Trust device ID unlabeled | **Not fixed in tracked runtime**; patch adds labels | `ID:` and `Key fingerprint:` separately, copyable |
| New-device notification absent | **Not fixed in tracked runtime**; patch adds local events/notice | Durable dedup, no notification storms, in-app fallback |
| Subscribe remains Subscribe | Core mirror reload fixed **in committed runtime**; reactive management not merged | Genuine Receive→subscribe→visible status and restart test |
| Incoming Groups look local / allow ordinary actions | Core mirror reload fixed **in committed runtime**; complete real UI unverified | Local/device section, sync-lock, source-owned readonly guards, no loss after refresh |

## Local agent execution order

1. **Recover safely.** Read current `AGENTS.md`, the v5 spec and the [remediation plan](../plans/2026-11-14-mitemite-v5-remediation.md). Fetch current origin. Use the existing task worktree if available; never reset unrelated work. Preserve the encoded patch and exact CI evidence. Reconcile any commits newer than `403b4526`. No reset of real synced device data.
2. **Make the staged management patch reviewable.** Read and SHA-verify `.github/144-remediation.patch`; decode gzip/base64 into a durable ignored artifact; `git apply --check` against the verified HEAD, then apply in the isolated worktree (not via an auto-commit workflow). Keep the raw patch as recovery evidence until its replacement commits are verified. Review the 18-file diff for signing/schema, trust and journal boundaries. Split implementation into logically testable commits rather than committing the entire blob without review.
3. **Reproduce and resolve the red integration test first.** Run `bookmark_mirror_engine_test.dart` directly with the real provider harness and an explicit bounded completion signal. The known `oktoast` success timer survives disposal; confirm whether cancelling/draining that UI timer resolves the test and separately locate any stalled async operations, open provider containers, Hive coordination, pending scans or scheduler feedback. Preserve meaningful toast behavior; do not weaken assertion logic or use long fixed sleeps. Verify red→green under the same configuration and clean teardown. Then run focused management, catalog-root, event, settings and Bookmark consumer suites.
4. **Review every owner acceptance path.** Direct Publish must survive folder selection and group rename/deletion, stop publication must preserve direct child overlap, Receive must not reveal untrusted data, Subscribe must switch promptly after a durable commit, and imported-only content must remain outside Local/All Bookmarks. Check duplicate taps, offline operation, failed/out-of-date catalogs and existing root migration. Assert no silent ownership loss and no echo publication.
5. **Complete the unimplemented v5 features, not only the visible bugs.** The following remain material: full source-owned **Following** Topic/folder/feed publication, receive, read-only repository guards and local-only refresh/NEW/cache state; source-definition change indicator; missing Bookmark parent arrival aggregates and correct Viewer/read and conditional Mark Read coverage; source-error isolation; watcher/dirty reconciliation; device aliases, activity/deep links, accurate state classification and local-notification preference. Treat the untested scratch reading patch only as a candidate; video/animation frame display must be proven, not inferred from initialization or thumbnails. Avoid unrelated Collection/Viewer redesign.
6. **Real platform acceptance.** Follow `docs/android_emulator.md` for exclusive emulator leases and use Maestro where required. Verify Android SAF persisted tree grant across restart, revoked/offline share, immutable partial-document protection, two writers, process death, relocation without revision reset, and real bidirectional Sync between two independent device installs/shared storage. Honor the earlier explicit instruction not to operate the protected physical phone. A Kotlin build or two-Hive host simulation is not device acceptance.
7. **Final qualification and cleanup.** Run scoped tests after each change and `./scripts/run_regression_tests.sh` on the *final runtime candidate*, plus relevant `fvm flutter analyze` and Android Kotlin build and manual UI checks (320/390dp, large text, keyboard, desktop). Maintain evidence: exact SHA, tests, failures/skips, native verification and independent review findings. Remove the temporary CI patch/workflows only when their changes are safely committed and verified. Update this handoff and issue #144 with remaining risks. Do not merge, PR or close without owner approval.

## Security and data invariants (non-negotiable)

- Source-owned received Groups/Following definitions are **not** ordinary writable local data; preserve canonical publisher+source identity, journaled ownership, stable local UUIDs and repository-level write guards.
- Publishing or subscribing Bookmark Group A covers its complete current/future subtree; direct roots and inherited coverage are distinct. A+explicit B overlap must map to **one** B mirror. Root UI links must not create copies or duplicate read checkpoints.
- Verified signed `withdrawn`/`deleted` and confirmed user actions alone authorize cleanup. Missing catalogs, revoked SAF permission, network/offline failures, signature mismatch, unsupported schemas and stale revisions **never** delete local data.
- **Superseded on 2026-11-14:** Group opening never acknowledges or changes its visible Unseen state; a Post is read only when actually shown in active full Viewer or explicitly selected for Mark Read. Loading a thumbnail, work cover, neighbor, failed media or an initialized-but-not-rendered video does not count.
- Folder relocation preserves publisher identity, trust, subscriptions, mirror checkpoints and anti-rollback. Received content is excluded from outgoing publication and the local-only All Bookmarks aggregate absent independent local membership.

## Proof required before reporting #144 complete

A final branch SHA containing **no encoded pending repair patch**, current executable tests and clean local/devices-only acceptance evidence; direct confirmation of every reported owner bug; all v5 Bookmark and Following cases; actual two-device SAF testing; an updated source-grounded handoff; and owner approval before integration. No partial Actions success or a documentation-only commit qualifies the runtime.

## Active local continuation checkpoint (2026-11-14, 17:26 UTC)

The owner explicitly approved current/future descendant scope for Following
folders/Feeds and made two emulators available. Continue implementation and
acceptance; this checkpoint is not completion.

- Feature branch pushed through `bae7fa3db`; latest runtime `a02a40fca` has the
  complete host pass above. Debug APK build passed. SHA-256
  `0d5ff653a56fd8491a90fe08712c0b11ff60cdf17e8c18ee8367a63b0a66e50c`
  matches both installed APKs. No app data was cleared. Before-update app data
  archives and font/size/density observations are in the ignored artifact folder.
- Emulator leases are retained in the ignored artifact `emulator-leases.json`;
  renew before every device operation and release when finished. The artifacts
  include the targeted update/backup script. Physical phones remain untouched.
- Maestro Viewer: `http://127.0.0.1:9999/`. UI control is through Maestro MCP only.
  First-launch site CAPTCHA disappeared before the attempted Cancel tap (that
  tap failed); no CAPTCHA was solved or bypassed.
- `emulator-5554`: selected the dedicated existing
  `/sdcard/Documents/Boorusama144Test` through the actual SAF picker, confirmed
  Android's grant, and reached Ready. Publisher ID
  `18a17c4f-9084-424f-be39-3ce22ee1bca2`. Its empty Publish page contains only the
  contextual-publication hint. Actual Maestro `back` passed Publish, Receive and
  Activity -> Sync Home, then Sync Home -> Export and Import, one route each.
  Current screen is Export and Import. Restart/grant-revocation and two-instance
  propagation are not yet exercised.
- `emulator-5556`: candidate launched with data preserved, current screen Browse.
  No MiteMite setup has been performed yet.
- For two-instance tests, use dedicated test directories and manually propagate
  immutable signed namespaces between them if no transport app is installed.
  That can qualify two independent Android SAF installs, but must be reported as
  controlled file propagation, not Syncthing/SMB/live-service acceptance.

### Following storage foundation

Committed `b79688aa7` adds the separate Following mirror storage capability,
source ownership/checkpoint metadata and repository guards. It reuses
`ImportTransaction` / `ImportJournalStore` / `ImportRecoveryService`, journals
receiver runtime and organization rollback locally, and recovers before reads.
It is not yet a Following transport/UI implementation.

- `following_mirror_storage_test.dart` plus existing repository tests: 53 passed.
- Complete `test/core/search/following_topics` plus new storage tests, concurrency 6:
  765 passed (`following-storage-consumers.log`). Includes local runtime writes,
  definition rename/query behavior, profile removal preservation, ordinary edit/
  organization guards, interrupted apply/reopen recovery and unrelated local data.
- Corrected a review finding: detaching an owned Topic into Home must fail even
  if all its row values remain unchanged. Canonical local parent mapping is now
  checked against source-parent ownership; the direct-root exception applies only
  when that source parent is outside received coverage.
- Final storage analysis: 0 errors, 0 warnings, 21 informational findings;
  `following-storage-clean-analyze.log`, exit 0. The initial two redundant null
  assertions were removed. Full app/package regression still needs repeating on
  the eventual complete Following candidate.
- Current uncommitted work introduces Following definition package/publication
  support in ordinary source files, with focused tests running. No transport or
  UI path can yet subscribe Following definitions. Do not treat this foundation
  as completed Following Sync.


## Following device header correction — 2026-11-16

Following now matches the Bookmark device header: bounded single-line device
name, expanding divider, and a 48dp Edit pencil at the right edge. The pencil
opens the shared receiver-local device alias editor for that publisher rather
than navigating to Devices. Signing identity and source definitions are unchanged.

Verification: `fvm flutter test --no-pub --concurrency=6
 test/core/backups/mitemite/following_service_test.dart` passed all 21 tests.
The production widget regression checks pencil geometry and positive divider
width. Its outdated Remove Alias step now clears the alias through Edit Alias,
as required by owner commit `146ec7637`. Analysis of the changed page reports
zero errors, zero warnings and 15 informational findings. Logs are retained in
`.worktrees/_artifacts/144-following-device-header/`. Earlier failed/interrupted
runs are retained separately; `verified.log` records the passing final test
source. No Android acceptance or full repository regression was run for this
scoped header correction; earlier runtime evidence does not qualify this change.


## Published paths and Devices-only management — 2026-11-16

Published rows now use Bookmark/Feed leading icons and reuse BookmarkPickerLabel
for the source name plus its inline ancestor path. Root entries omit the path;
Following folders exclude their own name and Topics use their parent placement.
Subscriptions retains collection actions but omits device identifiers/fingerprint,
Edit and Forget Device, including offline Forget controls. Devices retains those
controls; the trust confirmation still identifies the signing key.

Focused production UI verification passed four tests (Published parent path/icon,
trust-first Subscriptions, 320dp enlarged-text/keyboard device alias editing, and
management interactivity during deferred scanning). Command: `fvm flutter test
--no-pub test/core/backups/mitemite/bookmark_mirror_engine_test.dart --name
'context Publish confirms|device alias actions fit|management.*scan|trust-first Receive'`.
Final log: `.worktrees/_artifacts/144-published-paths/verified-final.log`.
Changed-page analysis: zero errors/warnings, ten informational findings.
The earlier complete file run was NOT green: 42 passed, 14 failed, including
outdated timeline glyph, alias text, subscription status and management assertions.
Relevant management assertions were updated and the four focused cases rerun;
the complete file and repository suite have not been requalified. No native
Android acceptance was performed for this scoped change. Concurrent notification
copy and translation edits were preserved and excluded from this commit.


## Following UNSEEN, public source access and folder-only publication — 2026-11-16

Current runtime candidate: **`ae0151f01`**, pushed on the existing `feature/144-folder-based-collection-sync` branch. Its runtime/tests equal the pre-rebase `0d70ba48f`; the intervening remote commit `bf7213665` adds documentation only. Test-only remediation **`09d21125a`** was committed/pushed first: obsolete glyph, alias-editor, subscription-label and notification-copy expectations now match the owner's committed UI. The full mitemite directory passed **321 tests** at that earlier exact state.

Implemented the A/B/C contract in [the Following handoff](144-following-unseen-and-public-access-2026-11-16.md): blue per-Topic UNSEEN, recursive Folder aggregation, captured route-entry acknowledgements in one journaled batch, revocable credential-free reading for explicitly allowed public sources, new Folder-only publication and direct-only Folder icons. Legacy direct Topic roots, overlapping mirrors, source identity, read/runtime state and signed storage remain compatible. The canonical specification now reflects these decisions and the existing Published paths/Devices-only controls.

Current verification:

- Focused Sync/Following/content boundary: **1,290 passed**; additional final public-access/preview suite: **5 passed**. The full regression includes the two public-preview cases added after that boundary run.
- Actual received Search and Folder Feed routes were exercised with zero saved profiles, the production receipt repository/journal and controlled request/filesystem adapters. Tests cover unsupported-route refusal, no acknowledgement on Folder browse or refresh, a later revision while Search is open, actual anonymous dispatch, Feed entry, and in-flight authorization revocation. Separate disk-based service regressions cover receipt persistence, stale digests, nested future Topics, empty Folders, overlap and batched epoch preservation. Narrow 320dp/2x presentation checks keep UNSEEN and Post NEW independent.
- Whole-app analysis: **0 errors, 0 warnings, 4,242 informational findings**, exit **1**; not a clean analyzer result.
- Host Android compilation: **passed**, `fvm flutter build apk --debug --flavor prod --target-platform android-x64`. APK SHA-256 `34e4c9db785af3de22ef6c5027cb041a6fb9bdca21b7f79ad77a41ce67f32c5e`.
- Complete repository regression: `./scripts/run_regression_tests.sh` (concurrency 6): **exit 0**; **7,552 application tests + 1,711 package/CLI tests across all 13 suites passed**, with **2 existing Go Router tests skipped**. Both shell policy/release suites and **76 Python tooling tests passed**. Completed 2026-11-16 11:51:26 UTC. Runtime/test inputs remained unchanged for the entire run; the final fingerprint matches the build and analyzer.

Durable evidence lives in `.worktrees/_artifacts/144-test-remediation-2026-11-16/`, especially `scoped-final.log`, `public-previews-final.log`, `actual-public-routes-fixed.log`, `analyze-final.*`, `android-build-final.*` and `regression-final.*`. Candidate records for build/analysis have unchanged runtime/test-input SHA-256 `47eff9c0df0eae7c00a2c6c5e1d8c9c0b3dcae7bbf71eb08813103eafc4943cc` (5,290 inputs). Earlier failed/interrupted checks and prior green CI runs do not qualify this candidate.

**Outstanding limits and separate work:** The owner's instruction to **leave the emulators alone** cancelled emulator work. The lease was released; no installation/UI acceptance, physical-device operation, native Android SAF validation or genuine two-device acceptance occurred in this continuation. An emulator startup attempt preceded cancellation; it is not device acceptance. The APK build and host adapters do not prove Android responsiveness, live-public-service behavior or shared-directory/device delivery. The owner retains live performance acceptance. The newly arrived [notification categories/routing/offer-badge handoff](144-mitemite-notification-routing-2026-11-16.md) explicitly requests an independent work package and remains unimplemented here. The unrelated Timeline/thumbnail work is excluded. No merge, PR or #144 closure was performed.


## Remaining notification, Timeline and marker delta — 2026-11-16

Continued the owner's [delta handoff](144-open-items-2026-11-16.md) on the existing branch, retaining the approved Following behavior. Runtime candidate **`a20cacce1`** includes independently committed notification categories/routing/NEW lifecycle (`612a8af61`), generated Timeline group dividers (`8c2a216a6`), bounded offer projection (`e38158561`), the image-anchored 14dp borderless marker (`d726f699b`) and conditional recovery after a failed cached offer receipt flush (`a20cacce1`). All runtime commits have been pushed; no merge, PR or #144 closure was performed.

- Notifications: **444** focused Sync/navigation tests passed, including source-specific durable outbox migration, introduced Topic journal intent with first-subscription suppression, warm/cold production destinations, native compatible-destination summaries and privacy/trust/read-state guards. Actual Subscriptions NEW lifecycle passed at 320dp/2x, including late arrivals and acknowledgement on exit. The post-review cached-flush regression failed before the correction and passed afterwards; its complete **25-test** receipt/delivery/visit boundary is green.
- Timeline: **18** control tests and **12** production menu cases passed, with automatic group dividers, narrow scrolling, RTL, keyboard and enlarged text. Received/local Posts, Works and Pools retain ordinary More/selection behavior. The reported missing menu was **not reproduced**, including a real typed-only empty Unseen filter and restoring All after a reading refresh; shared menu logic and `_ViewOptionTile` were intentionally preserved.
- Marker: independently verified image-surface geometry before migration; actual Flutter/ExtendedImage decoding, metadata mismatch, contain/cover, placeholders and narrow portraits determine bounds without resizing the cell. Post/Pool/Work covers share this receiver-local decoration scope. Marker/Viewer/grid consumers: **73 passed**; ExtendedImage package: **47 passed**. Actual Classic/Standard PostGrid cases check position, click-through and unchanged Preview/selection geometry.
- Final complete regression (`./scripts/run_regression_tests.sh`): **exit 0**, **7,582 application tests + 1,711 package/CLI tests across all 13 suites passed**; **2 existing Go Router skips**. Both shell suites and **76 Python tooling tests passed**. Completed **2026-11-16 13:40:45 UTC** on `a20cacce1c01a39a78126f63fcce7704601429e0`. Runtime/test-input SHA-256 remained unchanged at `1477e85d7e4e5cf6ff04f10782401b72f496a0f8ccd8282ae8ae4b891385614d` (5,295 inputs), matching the final build and analyzer.
- Final whole-app analysis: **0 errors, 0 warnings, 4,279 informational findings**, exit **1**; not a clean analyzer pass. Final host Android build: **exit 0**, `fvm flutter build apk --debug --flavor prod --target-platform android-x64`, APK SHA-256 `56089d4f7d3df9ef888e81113552633a342a00dbcc11fabc2a525bd79c63995b`. The earlier full run returned exit 0 but its input comparison detected the durability edit, so it does not qualify the final candidate.

See [the delta handoff](144-open-items-2026-11-16.md) and [notification implementation evidence](144-mitemite-notification-routing-2026-11-16.md) for commands and durable logs in `.worktrees/_artifacts/144-remaining-2026-11-16/`. The canonical specification now states the later five-category destination contract, NEW lifecycle, present-group dividers and image-surface marker geometry. Its historical all-taps-to-Bookmarks and bordered-20dp wording is superseded.

**Limits:** No emulator or protected-device operation was performed, as explicitly instructed. MethodChannel/host navigation and an Android APK build cannot prove native system UI, real cold-process launches, SAF/shared-directory delivery, genuine two-device or live-service acceptance. Owner live-device performance acceptance remains separate. A persisting owner-device-only missing-menu symptom still needs a concrete reproduction; no speculative menu/settings rewrite was introduced.

## Owner correction: restore normal View Options and tile-corner Unseen — 2026-11-16

Pushed runtime **`22b95616b279e491db1f75d068eab67aacdeadcc`** on the existing branch. The owner's latest instructions supersede both the earlier retention of `_ViewOptionTile` and the painted-image anchoring requirement.

Commit **`a51ecbd51c3049591a3fbbfb3936063ed92a079c`** removes the stacked wrapper from the shared View Options sheet and restores ordinary inline Kurumi settings rows for every Timeline. The displayed selected value is bounded for enlarged text; dropdown options and callbacks, mixed-item More availability and the separate Group commands are preserved. The new ordinary-row layout assertion failed before the correction. A plain restoration also reproduced the 320dp/200% trailing-width assertion; bounding the selected value fixes that without stacking the controls.

Commit **`22b95616b279e491db1f75d068eab67aacdeadcc`** restores the original tile-corner Unseen overlay, 6dp from the top/right, retaining its borderless 14dp appearance. It removes the unused image-surface helper, dedicated geometry tests and renderer export, restoring the prior Post/Pool/Work image construction. The Classic/Standard portrait cases failed before the revert and now verify tile placement, click-through, unchanged cell bounds and selection/Preview controls. Reading persistence and sync ownership logic are unchanged. The canonical specification and delta requirements reflect both newer decisions.

- Final combined menu/quality/mirror/Bookmarks/listing tests: **1,248 passed, exit 0**, at concurrency 6.
- Complete ExtendedImage package suite: **47 passed, exit 0**.
- All changed Dart files analyzed: **0 errors, 0 warnings, 12 infos, exit 1**; menu/application test alone: no issues, exit 0. Formatting and diff checks passed.
- Exact commands and durable logs are recorded in [the delta handoff](144-open-items-2026-11-16.md#latest-owner-corrections--ordinary-view-options-and-tile-corner-unseen), under `.worktrees/_artifacts/144-restore-view-options-2026-11-16/`.

These scoped checks qualify `22b95616b`; the previous full repository regression/APK qualify `a20cacce1` only and were not rerun for these corrections. No emulators or protected devices were touched. No native Android, SAF, two-device, live-service or live performance acceptance is claimed. No merge, PR or #144 closure was performed.


## Topic action menu correction — 2026-11-17

Removed the Subscriptions navigation action from the shared `followingSyncMenu`, covering received Topic and Folder actions, including Feed member cards. This matches Bookmark Group action menus; subscription management remains available in MiteMite. Publication, alias, local copy and applicable Unsubscribe actions are unchanged.

Verification: `fvm flutter test --no-pub --concurrency=6 test/core/backups/mitemite/following_mirror_engine_test.dart` passed 17 tests. Changed-file analysis reported zero errors/warnings and three informational brace findings (exit 1). Formatting and diff checks passed. Logs: `.worktrees/_artifacts/144-topic-menu-2026-11-17/`. No emulator/device operations or full regression were performed for this menu-only removal.


## Mark Read exits Bookmark selection — 2026-11-17

After a successful selected-bookmark Mark Read save, the mounted Bookmark timeline now disables and clears selection. A thrown save error still follows the existing error path without closing selection. No read-target, journal or ownership behavior changed.

Verification: the 12 production Timeline route cases pass, including five received root/nested Post/Work/Pool action-callback checks at 320dp/200% text. The already-Seen root Work fixture retains its existing empty-filter coverage. The tests invoke the production Mark Read callback and await real IO completion; they do not qualify toolbar overflow hit-testing. Earlier UI-tap attempts failed and do not count as acceptance. Changed-file analysis: zero errors/warnings, eight informational findings, exit 1. Formatting and diff checks passed. Durable logs: `.worktrees/_artifacts/144-mark-read-selection-2026-11-17/` (`final.log`, `analyze.log`). No full regression or emulator/device operations were performed for this scoped action change.


## Collection-specific subscription progress — 2026-11-17

Pushed runtime **`c1704c92c72f042429ebf91751d72092cc2713e2`** on `feature/144-folder-based-collection-sync`. Previously, the Subscriptions page consulted one pending key per publisher/content type, so subscribing to one Group disabled every other Group of that type from the publisher and changed their labels to Updating.

The service now exposes `isSubscriptionPending(SyncCollectionId)` and tracks each explicitly requested publisher/type/source alongside the existing aggregate counters. Only affected entries show Updating and disable their buttons; other entries remain clickable and their operations queue through the unchanged service lock. Batch roots are captured before queuing and receive individual reference-counted keys. Completing one overlapping request cannot clear another request's pending state. Both Subscribe and Unsubscribe, for Bookmarks and Following, use this path. No persistent schema, journal, identity, trust, anti-rollback or reading logic changed. The canonical specification records the new UI contract.

Verification on the unchanged runtime/tests committed as `c1704c92c`:

- `fvm flutter test --no-pub --concurrency=6 --reporter=expanded test/core/backups/mitemite test/core/search/following_topics test/core/bookmarks`: **2,103 passed, exit 0**. This is the complete affected-directory regression, not the complete repository suite. Physical core detection returned 6.
- The new real Subscriptions screen regression failed before the fix because the unrelated button was disabled. It now passes at **320dp/200% text**, keeping B enabled with Subscribe while A is paused, accepting B's click, re-enabling A while B remains pending, and persisting both direct roots. The production provider/repository and controlled storage gates are used.
- Both content types additionally pass controlled service checks for publisher/type/source isolation, queued additions without lost roots, immutable caller-root capture, batch keys, overlapping Unsubscribe reference counts, failure cleanup, retained committed subscriptions and successful batch retry. An initial gated-service fixture timed out because startup maintenance consumed a test gate; the final fixture awaits maintenance completion before enabling its gates. The final complete affected-directory run includes these corrected tests.
- `fvm flutter analyze --no-pub lib/core/backups/mitemite/service.dart lib/core/backups/mitemite/service_following.dart lib/core/backups/mitemite/page.dart test/core/backups/mitemite/bookmark_mirror_engine_test.dart test/core/backups/mitemite/following_service_test.dart`: **0 errors, 0 warnings, 100 informational findings, exit 1**. Not a clean analyzer pass. Changed Dart formatting and `git diff --check` passed.

Durable evidence: `.worktrees/_artifacts/144-subscription-pending-2026-11-17/`, especially `before.log` (expected UI failure), `bookmarks-fixed.log`, `pending-domains-final.log`, `regression.log`/`.exit` and `analyze-final.log`/`.exit`. Earlier failed fixture attempts do not qualify the final candidate. Host test logs include locale/VM and controlled image-fetch diagnostics; the final command/assertion outcome is exit 0.

**Limits:** No complete repository regression, APK build or native Android acceptance was performed for this scoped change. No emulator or protected-device operations were performed. SAF, two-device, live-service and owner live performance acceptance remain separate. No merge, PR or issue closure.
