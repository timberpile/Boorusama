# Posts über „Boorusama link“ direkt in der App öffnen

> **Archive disposition (2026-10-20): Completed on `develop`.** Portable Boorusama post/search link files were integrated in `9be0d3e` (`feat(links): add portable post and search link files`). Earlier in-progress status and manual acceptance notes below document historical branch work, not a pending repository work item.

Priority: Normal
Affected feature: Post-Sharing, URI-Empfang und Profilauflösung
Claimed by: ChatGPT, 2026-10-16
Branch: `feature/POST-009-boorusama-links`
Base: `e8bf883912ecd5a8c4154472a962aa0aabf0c09a` (`develop`)
Workspace: isolated task worktree `/mnt/data/post009-worktree` (snapshot-based local history); published branch is authoritative.

## Problem und Ziel

Nutzer möchten einen Post-Link versenden, den Empfänger direkt in ihrer installierten Boorusama-App öffnen können, ohne Website oder Post manuell zu suchen.

## Vereinbartes Verhalten und Akzeptanzkriterien

- Der bestehende Share-Dialog erhält unter Links den Eintrag „Boorusama link“ mit den vorhandenen Aktionen Copy und Share; es gibt keinen zusätzlichen Schalter oder Modus-Picker für „Link only“ versus „Image + link“.
- **Copy:** Kopiert ausschließlich den portablen Boorusama-URI als reinen Text in die Zwischenablage, ohne Bild, Beschreibung oder vorangestellten Text. Dafür wird kein Medium heruntergeladen.
- **Share:** Übergibt in einem gemeinsamen OS-Share-Vorgang ein Bild als Anhang und denselben Boorusama-URI als Text/Bildunterschrift. Der Text enthält eine kurze, menschenlesbare Zeile wie `Open in Boorusama`, gefolgt vom vollständigen, unveränderten URI in einer eigenen Zeile. Kein Markdown-/Rich-Text-Linklabel voraussetzen.
- Für den Bildanhang die bestehende Medienvorbereitung und temporäre Datei-Lifecycle aus [IDEA-029](IDEA-029-unified-share-flow.md) wiederverwenden; für Posts ohne teilbares Standbild (z. B. Video) kann, sofern vorhanden, ein Vorschaubild verwendet werden. Ist kein Bild verfügbar oder schlägt die Vorbereitung fehl, wird dies verständlich angezeigt; Copy bleibt nutzbar. Keinen separaten normalen „Link only“-Sharemodus einführen.
- Copy und Share müssen dieselbe Post-Referenz enthalten. Der Messenger entscheidet, ob der Text als tatsächliche Bildunterschrift erscheint, getrennt von der Datei angezeigt oder ignoriert wird. Die App darf eine Bildunterschrift oder klickbare Darstellung nicht garantieren.
- Der Link verwendet ein eigenes URI-Schema und benötigt eine installierte Boorusama-App. Keine zusätzliche Website, kein Hosting und kein Browser-Fallback gehören zum Umfang. Messenger können benutzerdefinierte URI-Schemata als nicht anklickbaren Text behandeln; die vollständige URL muss deshalb sichtbar/kopierbar bleiben.
- Der Link kann die geschlossene App starten oder den Post in der bereits laufenden App öffnen. Die App muss nicht vorher geöffnet sein.
- Der Link enthält die Website und eine stabile Post-Referenz; zusammengesetzte Post-Keys werden für unterstützte Engines korrekt abgebildet. Keine Zugangsdaten oder senderlokalen Profil-IDs übertragen.
- Das Öffnen führt zum richtigen Post und mutiert keine Bookmarks oder Favoriten.
- Genau ein passendes Empfängerprofil wird automatisch verwendet. Bei mehreren passenden Profilen erscheint eine Auswahl.
- Ohne passendes Profil wird die Einrichtung angeboten; nach erfolgreicher Einrichtung wird der ursprünglich verlinkte Post geöffnet. Abbruch ist möglich.
- Ungültige Links, nicht unterstützte Websites/Post-Referenzen und nicht verfügbare Posts werden verständlich behandelt. Vorhandene Datei-Import-Intents bleiben funktionsfähig.

## Kontext und technische Festlegungen

An [IDEA-029](IDEA-029-unified-share-flow.md) und die [Post-Architektur](../../post_architecture.md) anschließen, ohne laufende Claims zu übernehmen. Das genaue URI-Schema, dessen versionierbares Format und die unterstützten Plattformen vor Umsetzung festlegen.

Copy-only-URI und Share-Payload (Bilddatei plus Text mit identischem URI) automatisiert prüfen. Für tatsächliche Messenger-Weitergabe insbesondere WhatsApp, Telegram, Signal und Discord testen und dokumentieren, ob Caption/Text erhalten und der URI anklickbar bzw. kopierbar ist. Das Öffnen bei kalter und laufender App auf den vorgesehenen Plattformen prüfen.

## Ausführung und Verifikation

2026-10-16: Umsetzung vom Nutzer beauftragt. Aktualisierten Vertrag aus `maintenance/POST-009-share-link-contract` übernommen und Ticket vor Implementierung beansprucht. Keine Integration in `develop`, kein Pull Request.

Die lokale Ausführungsumgebung enthält kein Flutter/FVM und keinen Android-Emulator; direkter Git-Zugriff scheitert an der DNS-Auflösung. Deshalb wurden die Quelltexte in einem isolierten Snapshot-Worktree bearbeitet und über den GitHub-Connector auf dem Feature-Branch veröffentlicht. Flutter-Analyse und Tests wurden mit dem gepinnten SDK in GitHub Actions tatsächlich ausgeführt. Der nur für diese Sitzung benötigte CI-Helfer und sämtliche Patch-Transferdateien wurden im abschließenden Dokumentationscommit entfernt.

## Entscheidung

2026-10-05: Nutzer hat „Boorusama link“, einen direkten URI-Link ohne Website/Hosting, die Voraussetzung einer installierten App sowie die automatische Profilwahl, Auswahl bei mehreren Profilen und Einrichtung bei fehlendem Profil bestätigt.

2026-10-16: Share-Verhalten präzisiert: Copy kopiert nur den URI, Share sendet Bild und URI zusammen mit kurzer, menschenlesbarer Bildunterschrift. Kein zusätzlicher Share-Modus-Picker; die tatsächliche Darstellung und Klickbarkeit hängen vom Messenger ab.

## Implementierter Stand

- Versioniertes URI-Format `boorusama://post/open?v=1&engine=<engine>&site=<encoded-base-url>&key=<encoded-key>`; Parser und Generator sind von Accounts unabhängig. Normale IDs, Sankaku-Server-IDs und Pixiv-Werk/Bildindex werden erhalten. Unbekannte Versionen, doppelte/unbekannte Parameter, ungültige Schlüssel und URLs mit Zugangsdaten werden zurückgewiesen.
- Der bestehende Links-Tab enthält genau eine Boorusama-link-Zeile. Copy übergibt nur den URI. Share verwendet die bestehende Bildvorbereitung, Cache-Leases, Abbruch-, Fehler- und Übergabepfade und übergibt Bild plus lokalisierten Text mit URI. Androids eigener Bildkanal erhält `EXTRA_TEXT`; der share_plus-Pfad erhält dieselbe Caption und einen Popover-Ursprung. Video-Posts verwenden nur vorhandene Bildvorschauen.
- Die neue `/open`-Route verwendet bestehendes Flutter/GoRouter-Deep-Linking. Profilauflösung erfolgt nach Engine und normalisierter Website, niemals nach Sender-Profil-ID. Mehrere Empfängerprofile benötigen eine Wahl; fehlende Profile öffnen den vorhandenen Editor und setzen danach den ursprünglichen Link fort. Der Post wird über das gewählte Empfänger-Repository geladen und seine Identität verifiziert. Es gibt keinen neuen globalen Profilwechsel und keine Bookmark-/Favoritenmutation.
- Fehler-, Wiederholungs-, Abbruch- und Profilwechselzustände sowie deutsche und englische Texte sind implementiert. Neue Links verdrängen veraltete Ladeergebnisse. Die Protokollgrenzen sind in `docs/post_architecture.md` dokumentiert.

## Verifikation des Implementierungsstands

Geprüfter Commit: `4a7bb02a7c57bfd205df58bed9b6624c90fea388`.
[CI-Lauf mit Prüfprotokollen](https://github.com/timberpile/Boorusama/actions/runs/38825240008).
Der Lauf startete auf dem Transfercommit `0b88b4e5f55a1e70cb316dc2237d95fa79778694`, wandte die beiden letzten Testkorrekturen an und zeichnete den tatsächlich geprüften Commit separat auf. Der abschließende Commit ändert nur diese Dokumentation und entfernt den temporären Workflow; Runtime und Tests bleiben gegenüber dem geprüften Stand unverändert.

- Gepinntes Flutter `3.47.2` über FVM `4.3.1`; `./init.sh` einschließlich Generierung erfolgreich. Geänderte Dart-Dateien wurden mit `fvm dart format` formatiert.
- `fvm flutter analyze --no-pub --no-fatal-infos lib/core/posts/links lib/core/posts/shares lib/core/routers lib/foundation/clipboard.dart test/core/posts/links test/core/posts/shares/share_boorusama_link_test.dart`: Exit 0, keine Fehler oder Warnungen; ein nicht blockierender Hinweis `avoid_redundant_argument_values` für das ausdrücklich gesetzte `showAnim: false` im Toast-Test-Teardown.
- `fvm flutter test --no-pub --reporter=expanded --concurrency="$(python3 scripts/physical_core_count.py)" test/core/posts/links test/core/posts/shares test/foundation`: **325 bestanden, 10 übersprungen, keine Fehler**. Die übersprungenen Fälle sind bestehende GIF/FFmpeg-Tests ohne `/usr/bin/ffmpeg`, keine Post-Link-Tests.
- Abgedeckt sind URI-/Credential-Validierung, normalisierte Profilauflösung, exakte Pixiv-/Sankaku-Identität, initiale URI-Navigation, neue URI über den Flutter-Plattformkanal, verdrängte Ladeergebnisse, Profileinrichtung/Abbruch, Auth-/Fehlerzustände, schmale Profilwahl mit großer Schrift, Copy ohne Medienzugriff sowie Bild und identischer URI über Android-Method-Channel und share_plus. Die Dart-seitigen Plattformadapter sind gemockt; native Empfänger werden dadurch nicht verifiziert.
- `scripts/run_regression_tests.sh`: **fehlgeschlagen**. Die vollständige App-Suite meldet **3.398 bestanden, 1 fehlgeschlagen, 10 übersprungen**. Wegen des frühen Abbruchs wurden die nachgelagerten Paket-/CLI- und Repository-Tooling-Suiten dieses Gates nicht ausgeführt.
- Der fehlgeschlagene Fall ist `test/settings/image_cache_limit_ui_test.dart` — `image and video limit dialogs save independently and restore their visible values`. Nach Testende tritt beim Hive-Aufräumen eine `PathNotFoundException` für `pinned_search_folders.lock` auf; der Stack führt über `_FollowingTopicRepositoryBuild._closeBox`. Sowohl dieser Test als auch `lib/core/search/following_topics/src/data/providers.dart` sind gegenüber der Branch-Basis unverändert. Der Ablauf deutet auf eine Teardown-Race mit dem bereits entfernten temporären Verzeichnis hin; eine Reproduktion auf der unveränderten Basis wurde nicht durchgeführt. Keine fachfremde Reparatur in POST-009. Vor Integration muss dieser Regressionsfehler geklärt und der vollständige Gate erneut erfolgreich ausgeführt werden.
- Lokale Abschlussprüfungen: `git diff --check`, JSON-Validität und übereinstimmende neue Übersetzungsschlüssel für Englisch/Deutsch sowie lokale Dokumentationslinks bestanden. Runtime-/Testdateien stimmen bytegenau mit dem archivierten CI-Prüfstand überein. Manuelle Codeprüfung von Profilbindung, Parser, Navigation und Sharing durchgeführt; keine unabhängige Agenten- oder native Geräteprüfung behauptet.

## Noch offene Plattformabnahme

Status bleibt **in progress**: Die Plattformabnahme und ein vollständig grüner Regressionslauf sind noch offen. Bestehende Android- und iOS-Scheme-Registrierungen wurden statisch geprüft; dies ersetzt keine native Ausführung. Neue Desktop-Protokollregistrierungen und Web-/HTTPS-Fallbacks gehören nicht zu V1.

- Android/iOS: Post-Link bei geschlossener und laufender App öffnen; bestehende Profil-Links und Dateiimporte gegenprüfen. Ein, mehrere und keine passenden Profile sowie Abbruch/Einrichtung, Authentifizierung und nicht verfügbare Posts auf Geräten prüfen.
- Android-Instrumentierungstest `ImageClipboardChannelTest.shareIncludesCaptionInTheSameImageIntent` ausführen; neue Prüfung umfasst Caption, Bild-URI, Leseberechtigung und Lesbarkeit nach Entfernen der Quelldatei. In dieser Sitzung nicht nativ ausgeführt; kein APK-/iOS-Build als bestanden behauptet.
- WhatsApp, Telegram, Signal und Discord: tatsächlichen Empfang der Bilddatei und des unveränderten URI prüfen und je App festhalten, ob Caption/Text erhalten, der URI anklickbar oder nur kopierbar ist. iPad-Popover, Live-Authentifizierung und sichtbaren Abbruch während Medienvorbereitung prüfen. Keine Empfänger-App wurde in dieser Sitzung bedient.

Keine Integration in `develop`, kein Pull Request. Nur der eigene Feature-Branch wurde veröffentlicht.

## Extension: portable search links (2026-10-20)

User decision: search links belong on the same feature branch. Keep `engine`
in the URI: a self-hosted site's engine cannot always be inferred from its
hostname, and the receiver needs it to create a matching profile.

- `boorusama://search/open?v=1&engine=...&site=...&mode=raw|tags&q=...`
  opens the shared search on the receiver's device.
- Share a search from the search-results header or a saved/followed search's
  menu.
- Copy copies only the complete URI. Share sends plain text with a readable
  label, an optional search name and the complete URI. Dynamic searches do not
  attach an image or thumbnail.
- Engine/site resolution, profile selection and profile creation follow the
  post-link behavior. Do not transmit sender profile IDs, Following Topic IDs
  or credentials. Opening a search does not automatically follow or save it.
- Distinguish raw queries from ordered typed-tag lists, including negative
  tags. Engine-specific sorting, pagination, local unread state and cache state
  are outside V1.
- Tests cover URI validation and roundtrips, profile resolution, cold and warm
  routes, profile creation, Copy/Share and constrained layouts.

Verify the extension together with POST-009. A complete integration regression
pass and real device/messenger acceptance remain required before moving this
work item to `done/`.

## Local rebase continuation (2026-10-20)

Continued the existing local task worktree at
`/home/timber/code/Boorusama/.worktrees/rebase-post-009`. Preserved the verified
local rebase `769ea679d09ee768fb4b64d98af812371a1e6e10` on
`develop` / `origin/develop` `3bf372bb01ba475659059b459ed3949b39d3cea1`.
Imported the search extension and task CI workflow through origin feature tip
`6f74bf5e2165f29dac88ddc67c20d4e004695abe`, including its formatting changes.
The feature remains local; no feature push, PR or integration into develop.

Compatibility adaptations preserve the current Following page imports, use
current Kurumi Material types in new widget tests, import the required profile
extension and exhaustively handle the new menu actions in feed management.
Added regression checks for unchanged post/search URIs in the production router
and copying a Following Topic with its owner's profile without changing saved
state or the active profile. The imported extension section above is translated
into English under the current repository language rule.

Verified the final source/test working tree committed with this record:

- Regenerated changed translations with `./gen.sh i18n` and formatted affected
  Dart files with `fvm dart format`.
- `fvm flutter test --no-pub --concurrency=6 --reporter=expanded test/core/posts/links test/core/posts/shares test/core/search test/core/routers test/core/navigation/production_route_catalog_test.dart test/core/navigation/navigation_policy_test.dart test/foundation/clipboard_image_file_test.dart`:
  **973 passed, no failures or skips**. Six workers match
  `python3 scripts/physical_core_count.py`.
- `fvm flutter analyze --no-pub --no-fatal-infos lib/core/posts/links lib/core/posts/shares lib/core/search/search lib/core/search/following_topics test/core/posts/links test/core/search/following_topics/following_topics_page_test.dart test/core/navigation/production_route_catalog_test.dart test/core/navigation/navigation_policy_test.dart`:
  exit 0, no errors or warnings; 17 non-blocking informational lints.
- The imported task workflow parses as YAML and every embedded Bash step
  passes `bash -n`. No remote workflow execution is claimed.
- Translation JSON, matching English/German search-link keys, relevant local
  documentation links and `git diff --check` passed.
- An earlier combined run exposed a temporary-file cleanup race in the
  unchanged unsupported-media sharing test. That whole file passed in
  isolation, and the complete affected selection passed on rerun without
  changing it. The new source-owner regression required a valid engine ID and
  hint in its fixture and fake-clock advancement through toast disposal.

The full application/package/CLI/tooling integration gate and native/device/
messenger acceptance have not been run for this candidate. Existing acceptance
requirements remain open and the work item remains in progress. The maintenance
contract is preserved as ancestor commit `144d65fb9d1a29068d71d0d983e77d25bfd91038`;
its original remote commit is patch-equivalent and its full acceptance section
is present here. The user authorized removal of that redundant local/remote
maintenance branch.

## Local Android launch follow-up (2026-10-20)

Fetched `origin` and fast-forwarded the existing task worktree to `2a515f339`.
The dev APK build exposed a missing `BooruConfigX` extension import in
`TopicFeedManagementPage`, introduced by that commit's feed-member link actions.
Imported the existing config types library without changing behavior.

- Formatted the changed Dart file. Focused analysis passed with no errors or
  warnings; the existing `unawaited_futures` informational lint remains.
- `fvm flutter test --no-pub --concurrency=6 --reporter=expanded test/core/search/following_topics/topic_feed_management_page_test.dart`:
  **13 passed**, including narrow layouts and enlarged text.
- `fvm flutter build apk --debug --flavor dev --dart-define-from-file=env/dev.json --no-pub --android-project-arg=kotlin.compiler.execution.strategy=in-process`:
  **passed**. The explicit compiler strategy bypassed a local Kotlin daemon
  connection stall; it is a command-line workaround, not a repository change.
- Installed `build/app/outputs/flutter-apk/app-dev-debug.apk` on leased
  `emulator-5554` using Windows ADB. Maestro launched
  `com.timberpile.boorusama.dev` without clearing data; screen inspection
  confirmed the loaded Browse page, post grid and navigation controls. Left
  the app running and released the lease. This is launch verification only.
- Full integration regression and the remaining native/messenger acceptance
  criteria above remain pending. This follow-up does not qualify develop
  integration or complete the work item.

## Android prepared-image sharing fix and Signal limitation (2026-10-20)

Continued from `771cf5a7a` in the same task worktree. Reproduced the reported
Danbooru JPG sharing error on `emulator-5554`. Dart stages prepared images in
`cache/boorusama-share/boorusama_share_*.jpg`, but `OwnedImageTransfer` accepted
only generated GIFs from that directory. The native channel rejected the JPG
before opening Android's chooser; the share sheet's generic exception handler
then displayed the misleading no-compatible-target message.

The native handoff now accepts prepared supported images with the expected
filename prefix and matching MIME-derived extension. Canonical parent checks,
partial/empty-file rejection, independent owned copies and retention remain in
place. Added coverage for JPEG, PNG, GIF, WebP, AVIF and BMP, rejection of
unrelated/partial/mismatched sources, and native JPEG URI/caption/read-grant
retention after deleting the source. Corrected the existing caption test's
fixture to use the production preparation directory and filename prefix.

Verified the final runtime/test state committed with this record:

- Direct `javac` compilation of `OwnedImageTransfer.java` and
  `OwnedImageTransferTest.java`, followed by `java -cp <compiled-classes-and-JUnit>
  org.junit.runner.JUnitCore com.timberpile.boorusama.OwnedImageTransferTest`:
  **11 passed**. Before the fix, the new prepared-image test failed with
  `IllegalArgumentException: Image source is unavailable`.
- The dev APK build command from the launch follow-up above passed.
- `./gradlew :app:assembleDevDebugAndroidTest -Pkotlin.compiler.execution.strategy=in-process --console=plain`
  passed. Installed both APKs with Windows ADB on leased `emulator-5554`.
- `adb -s emulator-5554 shell am instrument -w -r -e class com.timberpile.boorusama.ImageClipboardChannelTest com.timberpile.boorusama.dev.test/androidx.test.runner.AndroidJUnitRunner`:
  **6 passed, 1 skipped**. The existing foreground system-clipboard assertion
  intentionally skips emulator hardware because its host clipboard bridge
  replaces URI clips. The first run exposed the invalid existing caption-test
  fixture; the complete class passed after correcting it.
- Maestro opened a live JPG's Share image action. Screen inspection confirmed
  Android's `Sharing image` chooser, image preview and installed targets,
  replacing the reproduced error. No message was sent. A final cleanup flow's
  viewer-only Share assertion failed because two Back actions returned to
  Browse; subsequent inspection confirmed the normal Browse page. Left the
  fixed app installed and running, and released the emulator lease.
- `git diff --check` passed. No Dart runtime changes or full integration suite
  run were needed for this scoped native fix. Integration and the remaining
  platform/messenger acceptance criteria remain open.

Signal's Android [link detector](https://github.com/signalapp/Signal-Android/blob/main/core/util-jvm/src/main/java/org/signal/core/util/Linkifier.kt)
recognizes HTTP(S), `www.` and bare-domain web links, rather than arbitrary
custom schemes. It cannot recognize the complete `boorusama://` address as a
single clickable link. The user reaffirmed that these links must not require a
hosted webpage. Kept the existing URI format and no-hosting contract; no claim
of Signal clickability or actual Signal delivery is made.

## Accepted local develop integration (2026-10-20)

The user accepted the current file-only MVP for integration into local
`develop`. The current behavior is defined by [the link-file MVP](../../bslink-mvp.md);
the raw-URI and image-plus-link sharing descriptions above are historical.
The user-reported Signal file-sharing result and known WhatsApp limitations in
that document remain distinct from automated validation.

Prepared a squash integration of source branch
`feature/POST-009-boorusama-links` at `7bb59ee85a962795bac06839f1ed46c837f23738`
with develop base `7d58c7d86786fe3f891cb2810f615fc9adef07d5` in the existing
isolated worktree. The merge had no conflicts and preserved the current
in-app updater. Regenerated merged translations using `./gen.sh i18n` and
formatted the 50 incoming Dart files with `fvm dart format` (21 changed).

The initial full run exposed a stale global manifest assertion and a hanging
icon pixel test. Scoped the strict export-MIME assertion to `ExportOpenActivity`
and added coverage that generic link-file VIEW handling remains restricted to
`.bslink` paths. Moved native image readback into `tester.runAsync`, preserving
the existing exact face-color and seam assertions. Both repaired files passed
directly: **11 tests**. The interrupted initial application run is not treated
as a passing integration gate.

Verified runtime/test candidate tree:
`fd1b636ecc7a366b1adab9035c0d1abc06187317`. Only documentation was updated
afterward, including alignment of the architecture's sharing description with
the accepted file-only MVP.

- `./scripts/run_regression_tests.sh`: fresh complete rerun **passed**, using
  the detected six physical cores. **4,212 application tests** and **1,467
  package/CLI tests across 13 packages passed**. The existing two `go_router`
  skips remain. Pull-request policy and Android release-script checks passed;
  repository Python tooling reported **72 passed**.
- `fvm flutter analyze --no-pub --no-fatal-infos lib/core/posts/links lib/core/posts/shares lib/core/backups/export_import/platform lib/core/developer_options/widgets.dart lib/core/search/following_topics lib/core/search/search/src/widgets/search_page_scaffold.dart test/core/posts/links test/core/posts/shares/share_boorusama_link_test.dart test/settings/developer_options_link_file_test.dart`:
  exit 0, no errors or warnings; 20 informational lints. The subsequent focused
  analysis of the two repaired test files also passed, with one informational
  lint.
- `fvm flutter build apk --debug --flavor dev --dart-define-from-file=env/dev.json --no-pub --android-project-arg=kotlin.compiler.execution.strategy=in-process`:
  **passed**, producing `build/app/outputs/flutter-apk/app-dev-debug.apk` for
  the combined candidate. No device was operated during this integration.
- `git diff --check` and `git diff --cached --check` passed. The develop ref
  remained at its original base until verification completed.

Integrated as one local Conventional Commit. No push, PR, release or remote
branch deletion was performed. The task record remains in
progress for the outstanding platform acceptance; retain the worktree and source
branch for that follow-up rather than deleting unfinished acceptance work.
