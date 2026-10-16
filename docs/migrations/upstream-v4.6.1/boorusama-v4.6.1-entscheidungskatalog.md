# Boorusama – Entscheidungskatalog zum echten Merge auf Upstream v4.6.1

**Stand:** 16. Oktober 2026 · **Status:** **68 von 68 Themen entschieden, 0 offen**, **lokale Implementierung durch Agenten am 2026-10-16 beauftragt**; noch keine Codeintegration und keine Freigabe für `develop`/Push/Release.

> Grundlage: `timberpile/Boorusama` `develop` auf `d4e15586f06192f0ff4315d36a3f61ae69a752d5`, Upstream `v4.6.1` auf `5b04bf6a164f028d41701299367d0dde74dde330`; gemeinsamer Vorfahr `2c0ac699184854d363833ea4a3205aef0895a92b`. Dateien aus dem hochgeladenen Git-Bundle lokal geprüft. Bei dieser Analyse wurden keine Laufzeitänderungen am Repository vorgenommen.

## Was wird hier verglichen?

- **150 Upstream-Commits** nach dem gemeinsamen Vorfahren, also Änderungen, die nicht schon über die gemeinsame Git-Ancestry im Fork sind. Sie können ältere Arbeiten vervollständigen oder rückgängig machen; nicht jeder Commit ist ein neues Feature.
- **Ca. 891 vom Upstream gegenüber dem Vorfahren geänderte Dateien** und **106 echte Git-Konfliktpfade** bei `git merge` ohne Sonderoption. Ein konfliktfreier Merge beweist keine semantische Kompatibilität.
- Der Fork hat bereits wichtige 4.6-Features **vor der Verzweigung** übernommen: PIN/App Lock, Wi-Fi-Downloads, erstes Favorite-Tag-Redesign, Kurumi und AVIF. Diese werden nicht als „neu“ erneut eingeplant.
- Zusätzlich schützt der Katalog Fork-only-Funktionen: UUID-Profile, Bookmark-Groups und Snapshot-Daten, Following/Pinned Searches, eigene Suche/Settings, Shared Cache, Exporte, Signierung.
- **Katalog-IDs bleiben stabil.** Entschiedene Themen folgen dem [verbindlichen Entscheidungsprotokoll](decisions.md), nicht den historischen Arbeitshypothesen. Offene Themen bedürfen weiterer Nutzerbestätigung.

## Ergebnis-/Entscheidungsregel

Für jedes Thema eines von **(a) vollständig übernehmen**, **(b) angepasst übernehmen**, **(c) Fork-Lösung beibehalten**, **(d) weglassen**. Danach: Zielverhalten, Datenmigration, Abhängigkeiten, Tests, Abnahmekriterien festlegen. Nichts gilt allein aufgrund eines Auto-Merges als fachlich akzeptiert.

## Übersicht

| Bereich | Themen | Nichttriviale Entscheidungen |
|---|---:|---:|
| Architektur, Datenschutz, Plattform und Toolchain | 18 | 16 |
| Netzwerk und Cloudflare | 6 | 6 |
| Downloads, Backups und Export | 8 | 8 |
| Booru-spezifische Änderungen | 10 | 10 |
| Posts, Grid, Viewer und Medien | 14 | 14 |
| Suche, Bedienung, Desktop und TV | 8 | 7 |
| Querschnitt: Schutz unserer Fork-Architektur | 4 | 4 |

**Summe:** 68 katalogisierte Einzelpunkte (65 Entscheidungen, 3 als trivial/obsolet/Testpflege eingestuft). Alle 150 Commits sind in mindestens einem Einzelpunkt referenziert.

## Nachvollziehbare Reihenfolge für die Besprechung

1. **Daten- und Startup-Sicherheit:** X01, X02, A01, X03, X04, A15. Ohne diese Entscheidungen ist ein Merge-Stand nicht sicher.
2. **Aktive Features/UX:** P01, P12, P13, A04, U01–U03, D01, N02; dann Site-Features.
3. **Stabilität/Plattform:** N03–N05, D02, B04, P08, A10, U04–U06.
4. **Rest/Automatik:** niedrig-riskante Bugfixes, i18n, CI, Tests, Dokumentation.

## Detaillierte Einzelpunkte

## Architektur, Datenschutz, Plattform und Toolchain

### A01 · App-Bootstrap, Runtime und Dependency Injection

**Status:** **ENTSCHIEDEN am 2026-10-15**, Umsetzung ausstehend · **Risiko:** 🔴 kritisch.

- **Bestätigter Beschluss:** angepasst übernehmen. Upstream-Bootstrap/Runtime/Dependency Injection (`BoorusamaBootstrapHost`, Production-Bootstrap, Runtime, AppScope, External Effects) als führenden einzigen Startup-Pfad übernehmen; ALLE Fork-Dienste und Startjobs (Profile/UUID, ImportRecoveryGate, DataMutationCoordinator, SearchRefreshLifecycle, Following, Backups, Cache, GIF-/Share-Cleanup, native Kanäle) korrekt integrieren.
- **Verifikation:** Cold start/Retry, alte Daten/Profile, Import/Restore, Following, Cache, Android/Desktop/Web; Headless-Flows A12.
- **Verbindliches Protokoll:** [A01](decisions.md#a01--app-bootstrap-runtime-und-dependency-injection).
- **Änderung in Upstream:** Neues `BoorusamaBootstrapHost`/`ProductionBoorusamaBootstrap`, `lib/main.dart`, Factory-/Service-Overrides und bessere headless Testbarkeit; umfangreicher 237-Dateien-Refactor.
- **Fork / potenzieller Konflikt:** Fork startet über `BoorusamaApp` und initialisiert zusätzliche Export-, Import-, Cache-, Profil- und Sync-Funktionen. Der Merge-Probelauf übernahm den neuen `main.dart`, ohne die alte Initialisierung vollständig zu übertragen.
- **Ursprüngliche Fragestellung:** Startup-Pfad behalten oder auf Upstream-Bootstrap migrieren? Welche Fork-Provider/Startjobs müssen garantiert ausgeführt werden?
- **Abnahme/Test:** Cold start, Backup-/Import-Provider, Cache-Initialisierung, Fehlerfall, Desktop/Web und alle Profile.
- **Upstream-Commits:** [`a3278c5d2`](https://github.com/khoadng/Boorusama/commit/a3278c5d2ecc3672fea63c68fb21c81a1db2bb07).
- **Betroffene Codepfade (Auswahl):** `lib/main.dart`, `lib/core/boorusama_app.dart`, `lib/core/bootstrap/boorusama_bootstrap.dart`, `lib/core/app_scope.dart`.
- **Bestätigter Merge-Konflikt in:** `lib/core/boorusama_app.dart`.

### A02 · Kurumi / Material-Cupertino-Paketmigration

**Status:** **ENTSCHIEDEN am 2026-10-15**, Umsetzung ausstehend · **Risiko:** 🟠 hoch.

- **Bestätigter Beschluss:** angepasst übernehmen. Kurumi-/Material-Cupertino-Migration, KurumiLikeButton, LinearProgressIndicator, PulseIndicator, PageIndicator und Kurumi-Kontextmenüs übernehmen; kein zusätzliches Redesign. ALLE Fork-spezifischen Actions und Long-Press-/Hold-and-Drag-/Rechtsklick-Interaktionen erhalten. **Der Agent erstellt NACH Umsetzung nur eine kurze priorisierte manuelle UI-Testliste für den Nutzer. Die manuellen Checks führt der Nutzer selbst durch, NICHT der Agent.** Automatisierte Tests/Builds macht der Agent weiterhin.
- **Verifikation:** Manuelle Liste mit konkreten betroffenen Screens: Post-Grid/Selection/Viewer/Toolbar, Bookmark-Groups, Pinned Searches/Following, Suche/Tag-Chips, Danbooru-Favorites, Share/GIF, Profile, Download-Actions, Desktop-Hover/Rechtsklick/Escape und mobile Menüs.
- **Verbindliches Protokoll:** [A02](decisions.md#a02--kurumi-material-cupertino-paketmigration).
- **Änderung in Upstream:** Kurumi trennt Material/Cupertino-Komponenten und ersetzt ältere UI-Abhängigkeiten; Formatierungen und teilweise geänderte Imports/Widgets.
- **Fork / potenzieller Konflikt:** Fork verwendet Kurumi bereits, hat aber eigene Menüs, Dialoge, Viewer- und UI-Komponenten. Beide Bäume nutzen in `.fvmrc` Flutter 3.47.2.
- **Ursprüngliche Fragestellung:** Übernehmen wir die zusätzlichen Kurumi-Komponenten und Widget-Semantik global oder nur für benötigte Upstream-Features?
- **Abnahme/Test:** Kompilierung aller Plattformen; Golden-/Widget-Checks für Popup, Dialog, Sliver, Viewer.
- **Upstream-Commits:** [`9f8ab7bca`](https://github.com/khoadng/Boorusama/commit/9f8ab7bcab67048be3bb865b98c47203d7b121b2), [`e7745aca8`](https://github.com/khoadng/Boorusama/commit/e7745aca83af95f38ac1d2e3f58fa23bf0b92234), [`6adb28be9`](https://github.com/khoadng/Boorusama/commit/6adb28be97b67181a1641df28d9b0c490e4e3f47).
- **Betroffene Codepfade (Auswahl):** `packages/kurumi/lib/kurumi.dart`, `packages/kurumi/lib/material.dart`, `pubspec.yaml`.
- **Bestätigter Merge-Konflikt in:** `packages/kurumi/lib/material.dart`, `pubspec.yaml`.

### A03 · Kurumi-Stabilität, Animationen und Overflow

**Status:** **ENTSCHIEDEN am 2026-10-15**, Umsetzung ausstehend · **Risiko:** 🟡 mittel.

- **Bestätigter Beschluss:** vollständig übernehmen, soweit regressionsfrei. Upstreams Kurumi-Fixes für Menüs, Fokus, Escape, Animationen, Overflow und Stabilität übernehmen; eigene Actions/Selection-Gesten nicht verlieren.
- **Verifikation:** Widget-/Build-Prüfungen und Benutzer-UI-Abnahme gemäß A02.
- **Verbindliches Protokoll:** [A03](decisions.md#a03--kurumi-stabilitat-animationen-und-overflow).
- **Änderung in Upstream:** Stabiler Widget-Tree, kein abgeschnittener Side-Menu-Titel, Checkmark-Animation beim Abwählen sauber abbrechen.
- **Fork / potenzieller Konflikt:** Kurumi ist im Fork verändert; auch kleine Framework-Fixes können semantisch kollidieren.
- **Ursprüngliche Fragestellung:** Diese isolierten Korrekturen übernehmen? UI-Verhalten und Animationen vergleichen.
- **Abnahme/Test:** Kurumi Widget-Tests, schmale Displays, große Schrift.
- **Upstream-Commits:** [`0ed1a49df`](https://github.com/khoadng/Boorusama/commit/0ed1a49df6e07787e89366ca931dd2f7b3504eef), [`485a728c9`](https://github.com/khoadng/Boorusama/commit/485a728c9802680b480ee949123624d6101cb463), [`c69b3e824`](https://github.com/khoadng/Boorusama/commit/c69b3e824d4acc4d60922ce78e391594846ff2c0).
- **Betroffene Codepfade (Auswahl):** `packages/kurumi/lib/src/components`.

### A04 · Responsives Settings-Navigationsmodell

**Status:** **ENTSCHIEDEN am 2026-10-15**, Umsetzung ausstehend · **Risiko:** 🟠 hoch.

- **Bestätigter Beschluss:** angepasst übernehmen. Upstreams responsive Settings-Navigation (neuer State, Unterseiten, Sidebar, kleine visuelle Änderungen) übernehmen. Vorhandene Fork-Settings Search, neue Kategorien/Einstellungen und **dynamische Titelgröße in der App-Top-Bar** unbedingt erhalten; kein abweichendes Fork-Redesign erzwingen.
- **Verifikation:** Settings-Suche samt Zielen, mobile/desktop, Resize in Unterseite, Zurück-/Escape-Navigation, Titelgröße.
- **Verbindliches Protokoll:** [A04](decisions.md#a04--responsives-settings-navigationsmodell).
- **Änderung in Upstream:** Upstream-eigene Settings-Navigation mit Navigation-State, adaptiven Routen und späteren Layout-/Back-Fixes.
- **Fork / potenzieller Konflikt:** Fork hat eigene `SettingsNavigationPane` und seit 14.10. eigene suchbare Settings-Navigation sowie zusätzliche Einstellungsbereiche.
- **Ursprüngliche Fragestellung:** Welches Navigationsmodell soll nach dem Merge gelten (Routing, Sidebar, Back, Suche, Deep Links)?
- **Abnahme/Test:** Compact und Wide, Backstack, Suche, Direktnavigation, Deep Links, Tastatur geöffnet.
- **Upstream-Commits:** [`1f2e90060`](https://github.com/khoadng/Boorusama/commit/1f2e90060765be4369a689522c463f740f254197), [`72c27ed64`](https://github.com/khoadng/Boorusama/commit/72c27ed64b10290bd5e1877a5fbe342572a3948d).
- **Betroffene Codepfade (Auswahl):** `lib/core/settings/src/pages/settings_page.dart`, `lib/core/settings/src/widgets/settings_navigation_pane.dart`.
- **Bestätigter Merge-Konflikt in:** `lib/core/settings/src/pages/settings_page.dart`.

### A05 · Upstream Settings Search wurde hinzugefügt und wieder revertiert

**Status:** **ENTSCHIEDEN am 2026-10-15**, Umsetzung ausstehend · **Risiko:** ⚪ niedrig.

- **Bestätigter Beschluss:** nicht übernehmen. Die kurzzeitig eingeführte und in Upstream v4.6.1 wieder entfernte Settings Search ignorieren. Ausschließlich die bestehende Fork-Settings-Search behalten. Grund für Revert ist nicht öffentlich verifiziert (Einführung `408666ef5`, Revert `685db1ad5`).
- **Verifikation:** Settings-Suche nach A04 vollständig nutzbar.
- **Verbindliches Protokoll:** [A05](decisions.md#a05--upstream-settings-search-wurde-hinzugefugt-und-wieder-revertiert).
- **Änderung in Upstream:** Temporäre Settings-Indexgenerierung und Suchoberfläche; 4.6.1 enthält diese Implementierung nicht mehr.
- **Fork / potenzieller Konflikt:** Fork hat eine eigene aktive Settings Search.
- **Ursprüngliche Fragestellung:** Keine produktbezogene Entscheidung, außer explizit gewünschte Einzelideen aus dem verworfenen Upstream-Code.
- **Abnahme/Test:** Settings-Suche bleibt nach dem Merge nutzbar.
- **Upstream-Commits:** [`408666ef5`](https://github.com/khoadng/Boorusama/commit/408666ef55f2b20f2e65d7eee21dcb01b0f018ca), [`685db1ad5`](https://github.com/khoadng/Boorusama/commit/685db1ad56712e00d4ef8dfe438114948ba6e86e).

### A06 · App-Lock: abweichende Privacy-Defaults

**Status:** **ENTSCHIEDEN am 2026-10-15**, Umsetzung ausstehend · **Risiko:** 🟠 hoch.

- **Bestätigter Beschluss:** vollständig übernehmen (Defaults). Upstream-Defaults übernehmen: App-Preview-Blur/Hide-App-Preview `false`, Lock-Timeout `30 Sekunden`. Bestehende vom Nutzer gespeicherte Werte beim Upgrade respektieren.
- **Verifikation:** Erstinstallation/Upgrade, vorhandene Settings, PIN/Biometrie, Lock/Preview.
- **Verbindliches Protokoll:** [A06](decisions.md#a06--app-lock-abweichende-privacy-defaults).
- **Änderung in Upstream:** Hide-App-Preview standardmäßig `false`; auf v4.6.1 steht außerdem Lock-Timeout-Default auf 30 Sekunden.
- **Fork / potenzieller Konflikt:** Fork besitzt PIN/Blur/Wi-Fi bereits, aber Hide-App-Preview-Default `true` und Lock-Timeout-Default `0`.
- **Ursprüngliche Fragestellung:** Welche Defaults und Migrationssemantik wollen wir für bestehende und neue Installationen?
- **Abnahme/Test:** Upgrade mit bestehenden gespeicherten Werten, neue Installation, biometrische und PIN-Lock-Flows.
- **Upstream-Commits:** [`c2d3b109e`](https://github.com/khoadng/Boorusama/commit/c2d3b109ef0e2124273858b17ed577e8bdaa1add).
- **Betroffene Codepfade (Auswahl):** `lib/core/settings/src/types/settings.dart`.

### A07 · Debug-Logging, Logspeicherung und Redaction

**Status:** **ENTSCHIEDEN am 2026-10-15**, Umsetzung ausstehend · **Risiko:** 🟠 hoch.

- **Bestätigter Beschluss:** 1:1 übernehmen. Upstreams persistentes Logging, Logansicht, Copy/Export, aktuelle Redaction-Defaults und übrige Konfiguration **1:1** integrieren. Keine vorgezogene Änderung an Privacy-/Redaction-Defaults; zukünftiges Fork-Logging-Work-Item baut darauf auf. Fork-Diagnosen erhalten.
- **Verifikation:** Startup-/Crash-Logging, Logpersistenz, Kopieren/Export, Rotation und bestehende Diagnosefunktionen.
- **Verbindliches Protokoll:** [A07](decisions.md#a07--debug-logging-logspeicherung-und-redaction).
- **Änderung in Upstream:** Neues persistentes Logging mit interaktiver Logansicht, URL-/Status-Hervorhebung, Copy; sensible Redaction in finaler Upstream-Konfiguration optional und standardmäßig aus.
- **Fork / potenzieller Konflikt:** Fork besitzt älteren Logger und zusätzliche Diagnose-/Cache-Funktionen; Startup-/Provider-Konflikte.
- **Ursprüngliche Fragestellung:** Persistente Logs? Aufbewahrungsfrist? Standardmäßig anonymisiert? Export inklusive Cookies/Auth-Tokens?
- **Abnahme/Test:** Credential-/Cookie-Test, Log-Datei-Rotation, Crash-/Startup-Pfade, Android/iOS/Desktop.
- **Upstream-Commits:** [`3bd433423`](https://github.com/khoadng/Boorusama/commit/3bd4334235a091c51e680c28ea852d3d07571a02), [`434a2e516`](https://github.com/khoadng/Boorusama/commit/434a2e516ecae2ce236d4c7592af62961e182a87), [`948af9448`](https://github.com/khoadng/Boorusama/commit/948af94483b7662d1de9a0fbfea7381019cd821a), [`d13fe53a3`](https://github.com/khoadng/Boorusama/commit/d13fe53a3b8cbbba481b4d2d436b124009941b8f).
- **Betroffene Codepfade (Auswahl):** `lib/core/debug`, `lib/foundation/loggers`.

### A08 · Typisierte Cloudflare-/DDoS-Diagnostics

**Status:** **ENTSCHIEDEN am 2026-10-15**, Umsetzung ausstehend · **Risiko:** 🟡 mittel.

- **Bestätigter Beschluss:** vollständig übernehmen. Upstreams typisierte Cloudflare-/DDoS-Diagnostics mit ausführlichen Challenge-/Solver-Status- und Fehlerereignissen in A07-Logging integrieren; Rule34-Fork-Recovery erhalten.
- **Verifikation:** Cloudflare Erfolg/Fehler, Loop-Vermeidung, lesbare Logs.
- **Verbindliches Protokoll:** [A08](decisions.md#a08--typisierte-cloudflare-ddos-diagnostics).
- **Änderung in Upstream:** Ausführliche Solver-/Challenge-Ereignisse, Polling- und Diagnostics-Logs, strukturierte Zustände.
- **Fork / potenzieller Konflikt:** Fork besitzt Rule34- und Cloudflare-Recovery sowie eigene Fehlerdiagnostik.
- **Ursprüngliche Fragestellung:** Welche Logs/Diagnosen in Debug-Screen übernehmen; welche Daten vor Persistenz bereinigen?
- **Abnahme/Test:** Cloudflare erfolgreich/fehlgeschlagen, sensitive query strings, kein Event-Spam.
- **Upstream-Commits:** [`480810b11`](https://github.com/khoadng/Boorusama/commit/480810b11a5a66b24be40bc8a80a2a56e681b90c), [`0def24717`](https://github.com/khoadng/Boorusama/commit/0def247178cedd1a058c3695a09b3c159ec3577d).
- **Betroffene Codepfade (Auswahl):** `lib/core/ddos/solver`, `lib/core/ddos/diagnostics`.

### A09 · Android-Cachepfade und DocumentsProvider

**Status:** **ENTSCHIEDEN am 2026-10-15**, Umsetzung ausstehend · **Risiko:** 🟡 mittel.

- **Bestätigter Beschluss:** angepasst übernehmen. Upstreams Cache-Locations-Settings und schreibgeschützten Android-DocumentsProvider übernehmen. Nur gültige, fertig gespeicherte Image-/Video-Cachedateien zeigen; keine Indizes, Partials, anderen privaten App-Dateien. An Fork-Package-ID/Native-Channels und **X04s normale Hash-Dateinamen** anpassen. Cache selbst nicht doppelt implementieren.
- **Verifikation:** Dateimanager-Öffnen/Kopieren, read-only, MIME, Android-Versionen, Cache-Clear/Eviction, Private-Data-Grenze.
- **Verbindliches Protokoll:** [A09](decisions.md#a09--android-cachepfade-und-documentsprovider).
- **Änderung in Upstream:** Cache-Dateiverzeichnisse in Settings anzeigen; Android Files kann per DocumentsProvider auf Cache zugreifen.
- **Fork / potenzieller Konflikt:** Fork hat eigene persistente Shared-Image-Cache-Pipeline mit LRU und unterschiedliche private Datenverzeichnisse.
- **Ursprüngliche Fragestellung:** Welche Caches sichtbar? Nur read-only? Wie schützen wir andere private App-Dateien?
- **Abnahme/Test:** Scoped Storage, Zugriffskontrolle, Cache-Eviction, Backup/Restore, mehrere Android-Versionen.
- **Upstream-Commits:** [`1e6a6607d`](https://github.com/khoadng/Boorusama/commit/1e6a6607dc7750a5c1e94d44531f8251fface3c6).
- **Betroffene Codepfade (Auswahl):** `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin`, `lib/core/settings/src/pages/data_and_storage_page.dart`.
- **Bestätigter Merge-Konflikt in:** `android/app/src/main/AndroidManifest.xml`, `lib/core/settings/src/pages/data_and_storage_page.dart`.

### A10 · Windows Embedded WebView, WebView-Plattformfähigkeit

**Status:** **ENTSCHIEDEN am 2026-10-15**, Umsetzung ausstehend · **Risiko:** 🟠 hoch.

- **Bestätigter Beschluss:** angepasst übernehmen. Windows-Embedded-WebView, Browser-Factories, WinHTTP und Unsupported-Platform-Fallbacks übernehmen; vorhandenes Fork-Cloudflare-/Browserverhalten bewahren.
- **Verifikation:** Windows Challenge/Login, Android/iOS/macOS, Navigation, Unsupported-Fallback.
- **Verbindliches Protokoll:** [A10](decisions.md#a10--windows-embedded-webview-webview-plattformfahigkeit).
- **Änderung in Upstream:** Windows-Embedded-Browser und WinHTTP-Adapter, abstrahierte Browser-Factories, Fallback bei nicht unterstützten WebView-Funktionen.
- **Fork / potenzieller Konflikt:** Fork hat eigene App-Service-Provider/Bootstrapping und Cloudflare-/Browser-Handling.
- **Ursprüngliche Fragestellung:** Windows offiziell unterstützen? Welche Browser-Funktionalität und Fallbacks für andere Plattformen?
- **Abnahme/Test:** Windows Login/Cloudflare, Android/iOS, Web nicht verfügbar, Navigation/Exit.
- **Upstream-Commits:** [`4c6138377`](https://github.com/khoadng/Boorusama/commit/4c6138377f9d5357b986584b8aee75d0b8d5dd66), [`8d8ca771b`](https://github.com/khoadng/Boorusama/commit/8d8ca771b393d18f31e21e21881f22f142179397).
- **Betroffene Codepfade (Auswahl):** `lib/foundation/browser`, `lib/core/http/client/src/data/winhttp_dio_adapter.dart`.

### A11 · Lokalisierung: Arabisch, Indonesisch, weitere Updates

**Status:** **ENTSCHIEDEN am 2026-10-15**, Umsetzung ausstehend · **Risiko:** 🟡 niedrig–mittel.

- **Bestätigter Beschluss:** vollständig übernehmen, mit Fork-Ergänzungen. Upstream-Sprachen/Übersetzungen einschließlich Arabisch, Indonesisch, Language-Switch-Fixes integrieren, ohne die zusätzlich im Fork eingeführten Keys/Strings oder Fallbacks zu verlieren.
- **Verifikation:** i18n-Generierung, JSON/Placeholders, RTL, Länder-Varianten, eigene Following-/Bookmark-/Settings-Texte.
- **Verbindliches Protokoll:** [A11](decisions.md#a11--lokalisierung-arabisch-indonesisch-weitere-updates).
- **Änderung in Upstream:** Locale-Ergänzungen, neue Übersetzungen aus Weblate, unbenutzte Keys entfernen, vollständige Locale beim Sprachwechsel erhalten.
- **Fork / potenzieller Konflikt:** Fork hat eigene Strings (Following, Bookmark-Groups, Settings Search); Lokalisierungsdateien teils unabhängig angepasst.
- **Ursprüngliche Fragestellung:** Sprachdateien zusammenführen, Key-Kollisionen und unübersetzte Fork-Keys fallbacken?
- **Abnahme/Test:** i18n CLI/Placeholders, Ländervarianten, RTL-Screens, JSON-Parsing.
- **Upstream-Commits:** [`bdec763aa`](https://github.com/khoadng/Boorusama/commit/bdec763aa3e7d36d774b2f64b7963f79329f9bdd), [`9ba59d05b`](https://github.com/khoadng/Boorusama/commit/9ba59d05b80c07b03e7e8696ee4c4ed8d068f14b), [`d13da93a3`](https://github.com/khoadng/Boorusama/commit/d13da93a3a6e2a8d9299d5a0ef91dd00422aa303), [`a891266bb`](https://github.com/khoadng/Boorusama/commit/a891266bb668caa65f846db9ee40f9b35c840c9e), [`02a28fe7d`](https://github.com/khoadng/Boorusama/commit/02a28fe7d7e94c12a94c926442681cc8d569e2d5), [`889592e57`](https://github.com/khoadng/Boorusama/commit/889592e57f5f22962158c2d9123f1db05f836260), [`e79abb5c0`](https://github.com/khoadng/Boorusama/commit/e79abb5c093aa7e1090653f2adf1b3e68b392328).
- **Betroffene Codepfade (Auswahl):** `packages/i18n/translations`, `packages/i18n/lib/src/locales.dart`.

### A12 · Headless Test-Harness und App-Flow-Tests

**Status:** **ENTSCHIEDEN am 2026-10-15**, Umsetzung ausstehend · **Risiko:** 🟠 mittel–hoch.

- **Bestätigter Beschluss:** angepasst übernehmen. Upstreams Headless-App-Test-Harness, Fake-Services und App-Flow-Tests mit A01-Runtime integrieren. Eigene Fork-Tests erhalten. Für visuelle/gestische A02-Abnahme schreibt Agent nur Nutzer-Checkliste; keine manuellen Geräte-Checks durch Agent.
- **Verifikation:** Startup, Suche, Bookmarks, Downloads, Network Recovery, Fork-Flows; deterministische Tests.
- **Verbindliches Protokoll:** [A12](decisions.md#a12--headless-test-harness-und-app-flow-tests).
- **Änderung in Upstream:** Neue App-Flow-Tests und Fake-Infrastruktur für Search, Bookmarks, Bulk Download, Network Recovery, Startup.
- **Fork / potenzieller Konflikt:** Fork hat viele eigene Integration-/Repository-Tests und eigene Startup-Architektur.
- **Ursprüngliche Fragestellung:** Welche Tests lassen sich portieren, ohne die ganze Runtime für Testbarkeit umzubauen?
- **Abnahme/Test:** Vollständige Testsuite und isolierte test/application-Suites, deterministische Provider.
- **Upstream-Commits:** [`c22d12fd6`](https://github.com/khoadng/Boorusama/commit/c22d12fd678db968af1356a21a3957ae3f3eda35).
- **Betroffene Codepfade (Auswahl):** `test/application`, `test/support`.

### A13 · NixOS-Paket und Development Shell

**Status:** **ENTSCHIEDEN am 2026-10-15**, Umsetzung ausstehend · **Risiko:** ⚪ niedrig.

- **Bestätigter Beschluss:** optional ohne Supportpflicht. NixOS-Flake, Entwicklungsshell und Paketierung nur soweit wartbar/kompatibel übernehmen; keine neue offizielle Release-Verpflichtung oder zusätzliche Wartungsinfrastruktur.
- **Verifikation:** `nix flake check` soweit verfügbar; übrige Build-Systeme unverändert.
- **Verbindliches Protokoll:** [A13](decisions.md#a13--nixos-paket-und-development-shell).
- **Änderung in Upstream:** Nix Flake, reproduzierbare Paketierung, Fonts und ARM64-Build-Fixes.
- **Fork / potenzieller Konflikt:** Fork hat eigene CI/CLI, aber keinen entsprechenden Nix-Baum.
- **Ursprüngliche Fragestellung:** Wollen wir Nix als unterstützte Build-/Release-Plattform?
- **Abnahme/Test:** nix flake check, Linux Desktop, Fonts, native Assets.
- **Upstream-Commits:** [`d3f3a62fa`](https://github.com/khoadng/Boorusama/commit/d3f3a62fa40fc7eadd2a63cd32e145f9cd3d5acd), [`038d1287c`](https://github.com/khoadng/Boorusama/commit/038d1287c04a260faea85e360c98f4baffb8fd97), [`e16ecd2c3`](https://github.com/khoadng/Boorusama/commit/e16ecd2c35236880eea7be4c27e3f957c6609143), [`2d621b683`](https://github.com/khoadng/Boorusama/commit/2d621b68335a62337075b53289f1f986f0631fcf), [`047a5a09e`](https://github.com/khoadng/Boorusama/commit/047a5a09e5e2ff397f23eee21f1cd54672cc80a2).
- **Betroffene Codepfade (Auswahl):** `flake.nix`, `nix/package.nix`, `docs/nix.md`.

### A14 · Release CI, native Assets, SDK und Build CLI

**Status:** **ENTSCHIEDEN am 2026-10-15**, Umsetzung ausstehend · **Risiko:** 🟠 hoch.

- **Bestätigter Beschluss:** selektiv übernehmen. Nützliche Upstream-CI-/native Assets-/SDK-/Build-CLI-Fixes übernehmen. Fork-Flavors, split-APKs, bestehende CI/Release-Workflows und Flutter-3.47.2-Pinning erhalten; zurückgenommene Upstream-Build-Fixes nicht unkritisch erneut übernehmen.
- **Verifikation:** Android-/Desktop-Builds, CLI, CI-Matrix, Release-Assets, Signierung gemäß A15.
- **Verbindliches Protokoll:** [A14](decisions.md#a14--release-ci-native-assets-sdk-und-build-cli).
- **Änderung in Upstream:** Windows CMake/NASM/Pfade, Native-Asset-Retries, Git longpaths, Smoke Runs, zentralisierte Toolchain, Android Resource-IDs. Ein Build-Fix wurde rückgängig gemacht.
- **Fork / potenzieller Konflikt:** Fork besitzt eigene Android split-APK-Signierung, eigene CI und Flutter 3.47.2.
- **Ursprüngliche Fragestellung:** Welche konkreten Toolchain-Fixes statt des gesamten Release-Workflows übernehmen?
- **Abnahme/Test:** CI Android+Windows+Linux+macOS+iOS soweit verfügbar, CLI-Tests, separate Smoke Run.
- **Upstream-Commits:** [`08088842c`](https://github.com/khoadng/Boorusama/commit/08088842c880bd124715e3d76b73c24945d8ea9a), [`dbfe54fc4`](https://github.com/khoadng/Boorusama/commit/dbfe54fc432738bcf59ee9179a9089f629d620bf), [`430747c1a`](https://github.com/khoadng/Boorusama/commit/430747c1af0153672863213a03f25c082a29e204), [`402c4eb67`](https://github.com/khoadng/Boorusama/commit/402c4eb67a1052ab1841592c4eeb5a6967de071c), [`a9821d53e`](https://github.com/khoadng/Boorusama/commit/a9821d53eb413ea46374ab09b07668b4ebe766f5), [`914ee5fa5`](https://github.com/khoadng/Boorusama/commit/914ee5fa51d33eeaa69ba8dc8c6dde171fadad58), [`899aabf6a`](https://github.com/khoadng/Boorusama/commit/899aabf6a26c22e438750319b74ac463a4af19ee), [`df4f705d8`](https://github.com/khoadng/Boorusama/commit/df4f705d810f2cdfc2f009c6d6082ab5fb61d2df), [`d1e7c99b4`](https://github.com/khoadng/Boorusama/commit/d1e7c99b4895404548a426274e076b3710d84f79), [`87a4fae44`](https://github.com/khoadng/Boorusama/commit/87a4fae4463529474a9d161fdd45fa2047831986), [`c184be942`](https://github.com/khoadng/Boorusama/commit/c184be94249a3768e4f4d672517230c62acfb7ae), [`db33523ff`](https://github.com/khoadng/Boorusama/commit/db33523ff960712518c3c3482e33f8d9b33048b6), [`c22d22e0d`](https://github.com/khoadng/Boorusama/commit/c22d22e0dfe9f3f521a3e495fafa69ba00d07364), [`f94243dcc`](https://github.com/khoadng/Boorusama/commit/f94243dccad0eace17d674df43934424ca591f39), [`b55d1adde`](https://github.com/khoadng/Boorusama/commit/b55d1addecaf59fb36cd72d5f5e6e5b75b629f84).
- **Betroffene Codepfade (Auswahl):** `.github/workflows/github-release.yml`, `packages/boorusama_cli`, `android/gradle.properties`, `scripts/toolchain.sh`.
- **Bestätigter Merge-Konflikt in:** `.github/workflows/github-release.yml`, `android/gradle.properties`.

### A15 · APK-Signing: permanenter Upstream-Key

**Status:** **ENTSCHIEDEN am 2026-10-15**, Umsetzung ausstehend · **Risiko:** 🔴 kritisch.

- **Bestätigter Beschluss:** Upstream-Signing NICHT übernehmen. Fork-App-ID `com.timberpile.boorusama`, Flavors, bestehende Release-Signatur, Keystore, Update-Manifest und Upgrade-Kompatibilität unverändert lassen. Upstream-Key keinesfalls übernehmen; etwaige Signing-CI-Fixes nur passend zur vorhandenen Fork-Signatur.
- **Verifikation:** Signer-Cert vor/nach Migration, installiertes Fork-APK upgraden, Paket-ID und Release/Manifest.
- **Verbindliches Protokoll:** [A15](decisions.md#a15--apk-signing-permanenter-upstream-key).
- **Änderung in Upstream:** Upstream signiert GitHub-APKs seit 4.6.1 mit einem neuen permanenten Release-Key.
- **Fork / potenzieller Konflikt:** Fork hat eigene Signatur, App-ID `com.timberpile.boorusama`, Icon/Flavor und Update-Manifest.
- **Ursprüngliche Fragestellung:** Auf keinen Fall Upstream-Key/App-ID/Release-Credentials übernehmen; eventuell Signing-CI-Prüfungen portieren?
- **Abnahme/Test:** Upgrade bestehender APK, signer certificate, Release Assets, Update-Manifest, build variants.
- **Upstream-Commits:** [`e6511bad5`](https://github.com/khoadng/Boorusama/commit/e6511bad5c6d44f9b574bb08e1eeef4ddaed4d23).
- **Betroffene Codepfade (Auswahl):** `.github/workflows/github-release.yml`, `android/app/build.gradle.kts`.
- **Bestätigter Merge-Konflikt in:** `.github/workflows/github-release.yml`, `android/app/build.gradle.kts`.

### A16 · Versionierung, Changelog und What’s-New-Popup

**Status:** **ENTSCHIEDEN am 2026-10-15**, Umsetzung ausstehend · **Risiko:** 🟡 mittel.

- **Bestätigter Beschluss:** angepasst übernehmen. Timberpile-Versionierung, eigene Release-History und Fork-Changelog beibehalten. Upstream-Fix für wiederkehrendes What's-New-Popup integrieren. Beschlossen: Bei integrierter Upstream-Basis `4.6.1` die erste Fork-Veröffentlichung `4.6.1-timberpile.1`, danach `.2`, `.3` usw. (pro Upstream-Basis Reset auf `.1`); Android Buildcode steigt global monoton (+190 als nächster Kandidat nach +189, sofern keine neueren Veröffentlichungen existieren).
- **Verbindlicher Nachtrag vom 2026-10-16:** **Additional binding version policy (approved 2026-10-16):** Every fork release name begins with the **exact upstream `MAJOR.MINOR.PATCH` release version actually integrated**. Use `<upstream-version>-timberpile.<N>+<build-number>`. **Reset `N` to 1** when the upstream base version changes; increment `N` for subsequent fork releases based on the same upstream version. Do not publish a `.0` release. The `+build-number` / Android `versionCode` is **globally monotonically increasing across upstream upgrades** and must exceed all previously shipped fork Android version codes / relevant store values (never reset it). With current `4.5.0-timberpile.5+189`, the first release based on upstream v4.6.1 is **`4.6.1-timberpile.1+190` if no intervening build/release occurred**; otherwise compute the next available build number from real release/store history. Keep `pubspec.yaml`, top `CHANGELOG.md` heading, `v<version-name>` GitHub tag, GitHub updater manifest, `PackageInfo`, Android Gradle `flutter.versionCode` and flavor-specific APK codes consistent. The existing `.agents/skills/prepare-release/SKILL.md` default (always increment old Timberpile suffix and preserve old upstream base) **must be updated during implementation** along with relevant release/checker tests. Preserve own Timberpile release history and What's-New fix. Setting a policy does not authorize publishing a new release or changing `develop` now.
- **Verifikation:** Popup einmalig, Upgrade `4.5.0-timberpile.5` → `4.6.1-timberpile.1`, version/build code monotonic, fork revision within same upstream base, reset with new upstream base, changelog/tag/manifest, parsed SemVer and Play/API compatibility.
- **Verbindliches Protokoll:** [A16](decisions.md#a16--versionierung-changelog-und-whats-new-popup).
- **Änderung in Upstream:** Upstream 4.6.0/4.6.1 Metadaten/Changelog; Fix für wiederkehrendes What’s-New-Popup.
- **Fork / potenzieller Konflikt:** Fork hat Version `4.5.0-timberpile.5`, eigene Release History und bereits eigene Changelog-Fixes.
- **Ursprüngliche Fragestellung:** Wie nennen wir die nächste Fork-Version? Werden Upstream-Release Notes getrennt dargestellt?
- **Abnahme/Test:** Migration alte Versionsnummer, Release Dialog nur einmal, Update-Manifest.
- **Upstream-Commits:** [`0adc367df`](https://github.com/khoadng/Boorusama/commit/0adc367df3c9a3862e9663049e1af0d90bf60d21), [`a9c31322b`](https://github.com/khoadng/Boorusama/commit/a9c31322bd4d60761218bedfd317ef18f8b69359), [`ffd7e47c5`](https://github.com/khoadng/Boorusama/commit/ffd7e47c5840a922b1c885d415a28984a6bf978a), [`bc63321ec`](https://github.com/khoadng/Boorusama/commit/bc63321ec125c5d54da165c9977580cdea46448f), [`e44fff71c`](https://github.com/khoadng/Boorusama/commit/e44fff71cd79dc4c581f6b6072a85e999a89df37), [`953fee30b`](https://github.com/khoadng/Boorusama/commit/953fee30bd78245cc9113a1dfc41a7953a7b2c3a), [`2a5818b57`](https://github.com/khoadng/Boorusama/commit/2a5818b570a58071959e9d877aa4d2a3c9c25a17), [`5a2a4e82e`](https://github.com/khoadng/Boorusama/commit/5a2a4e82e827785f0c296b600e44aae2247b90a4), [`5b04bf6a1`](https://github.com/khoadng/Boorusama/commit/5b04bf6a164f028d41701299367d0dde74dde330).
- **Betroffene Codepfade (Auswahl):** `CHANGELOG.md`, `pubspec.yaml`, `lib/core/changelogs/repo.dart`.
- **Bestätigter Merge-Konflikt in:** `CHANGELOG.md`, `pubspec.yaml`.

### A17 · Formatierung, Reverts ohne Nettoeffekt, Kleinst-Cleanup

**Status:** **ENTSCHIEDEN am 2026-10-15**, Umsetzung ausstehend · **Risiko:** ⚪ niedrig.

- **Bestätigter Beschluss:** Maintenance automatisch behandeln. Formatierungs-, Cleanup- und effektlose/revertierte Upstream-Änderungen ohne Produktentscheidung behandeln. Nur notwendige Lint-/Format-Fixes; unnötige Diffs und Wiederbelebung revertierter Features vermeiden.
- **Verifikation:** Analyzer, Formatter, Diff, Build.
- **Verbindliches Protokoll:** [A17](decisions.md#a17--formatierung-reverts-ohne-nettoeffekt-kleinst-cleanup).
- **Änderung in Upstream:** Großflächiges Formatieren, Aufräumen, unnötigen Abstand bzw. doppeltes `@override` entfernen.
- **Fork / potenzieller Konflikt:** Keine gewünschte Funktion; fork-spezifischer Code stark verändert.
- **Ursprüngliche Fragestellung:** Keine Produktentscheidung; bei Merge nur minimale Formatierungs-/Lint-Regressionskorrekturen.
- **Abnahme/Test:** format --output=none, analyzer, Diff-Prüfung.
- **Upstream-Commits:** [`cfb231254`](https://github.com/khoadng/Boorusama/commit/cfb231254634c8ef96873847c43f5983a5ea27ed), [`ab78dc3e3`](https://github.com/khoadng/Boorusama/commit/ab78dc3e338514bd39f2ce678ade2abd2c82b133), [`ee38cd592`](https://github.com/khoadng/Boorusama/commit/ee38cd592b4d6960d49025a52de433930b7441e7), [`372dca51c`](https://github.com/khoadng/Boorusama/commit/372dca51c760bb0d070c2d4b54c20c0407648b6c), [`3c72c200e`](https://github.com/khoadng/Boorusama/commit/3c72c200e1ecbf241feb09d1a3c932957720c84a).

### A18 · AVIF-Decoder-Kompatibilität im Web

**Status:** **ENTSCHIEDEN am 2026-10-15**, Umsetzung ausstehend · **Risiko:** 🟡 mittel.

- **Bestätigter Beschluss:** angepasst übernehmen. AVIF-Web-/Network-Decoder-Korrekturen übernehmen, bestehende AVIF-/Extended-Image-/Fork-Cache-Pipeline erhalten.
- **Verifikation:** AVIF Web/Android, Thumbnail/Original, Cache-Hit/Miss und Fallback.
- **Verbindliches Protokoll:** [A18](decisions.md#a18--avif-decoder-kompatibilitat-im-web).
- **Änderung in Upstream:** Upstream passt die neue `flutter_libavif`-Integration an Web-Umgebung und Network Decoder an.
- **Fork / potenzieller Konflikt:** Fork hat AVIF-Wechsel schon früher übernommen, aber eigene `extended_image`-/Caching-Pipeline.
- **Ursprüngliche Fragestellung:** Web-AVIF-Fallback/Decode-Logik portieren und Cache-Abstraktion erhalten?
- **Abnahme/Test:** AVIF in Web und Android, Thumbnail/Original, Cache-Hit/Miss.
- **Upstream-Commits:** [`72702e711`](https://github.com/khoadng/Boorusama/commit/72702e7110892d046826b53a25a70c39c1e72d56).
- **Betroffene Codepfade (Auswahl):** `packages/extended_image/lib/src`.

## Netzwerk und Cloudflare

### N01 · HTTP-Retry-After, Rate-Limiter und Admission-Locks

**Status:** **ENTSCHIEDEN am 2026-10-15**, Umsetzung ausstehend · **Risiko:** 🟠 hoch.

- **Bestätigter Beschluss:** angepasst übernehmen und redundant vereinfachen. **Fork-`ApiRequestCoordinator` behalten:** zentrale Origin-Quotas, parallele In-Flight-Limits, interaktive Priorität, Following/Preload/Bulk-Pacing und 429-Cooldowns. Upstreams Sliding-Window-Interceptor NICHT als zweite Warteschicht einführen. **Übernehmen:** `packages/retriable`-Fixes für `Retry-After` (Datum/Sekunden, insb. 503), konfigurierbare retrybare Statuscodes, korrektes Gesamttimeout und Abbruch. Alten, nach Aufrufstellenprüfung unbenutzten Sliding-Window-Interceptor samt unnötigen Tests entfernen; doppelte Parser konsolidieren. Zusätzliche Upstream-Site-Pacing-Regeln für Zerochan, Anime-Pictures, E-Shuushuu in unsere `ApiQuotaPolicy` prüfen/überführen, bestehende belegte Fork-Limits nicht blind ersetzen.
- **Verifikation:** 429/503 Retry-After und Zeitbudget, Parallelstart/Cancellation, keine Doppelwartezeiten, Danbooru/e621/Derpi/Zerochan, Anime-Pictures/E-Shuushuu, aktive vs. Following-/Bulk-Anfragen.
- **Verbindliches Protokoll:** [N01](decisions.md#n01--http-retry-after-rate-limiter-und-admission-locks).
- **Änderung in Upstream:** Konfigurierte Retry-Policies, `Retry-After`-Cooldowns und serialisierte Rate-Limit-Zulassung.
- **Fork / potenzieller Konflikt:** Fork priorisiert Browsing/Following-Requests und hat eigene Request-Koordination.
- **Ursprüngliche Fragestellung:** Wie integrieren wir Wartezeiten, Host-Limits und Browsing-Priorität, ohne Deadlocks?
- **Abnahme/Test:** 429/503, Retry-After als Datum/Sekunden, parallele Feeds/Downloads, Abbruch.
- **Upstream-Commits:** [`70b523938`](https://github.com/khoadng/Boorusama/commit/70b5239384cc86fba7c479c7ce688076508575cf), [`deca1064a`](https://github.com/khoadng/Boorusama/commit/deca1064aa68abcbbb1683408f305558bef08ee3).
- **Betroffene Codepfade (Auswahl):** `packages/retriable`, `lib/core/http/client/src/interceptors/sliding_window_rate_limit_interceptor.dart`.
- **Bestätigter Merge-Konflikt in:** `lib/core/http/client/src/interceptors/sliding_window_rate_limit_interceptor.dart`.

### N02 · Per-Profile Media-Host-Overrides

**Status:** **ENTSCHIEDEN am 2026-10-15**, Umsetzung ausstehend · **Risiko:** 🟠 hoch.

- **Bestätigter Beschluss:** angepasst übernehmen. Media-Host-Overrides pro Profil inkl. UI für Bilder/Videos/Downloads übernehmen. Header/Cookies/Auth NICHT ohne kontrollierte Origin-Grenzen zum Ersatzhost weitergeben; Source-/Profilidentität und Cache-Isolation bewahren.
- **Verifikation:** CDN-Wechsel, Previews/Original/Video/Download, Proxy, Auth-Leaks, Cache.
- **Verbindliches Protokoll:** [N02](decisions.md#n02--per-profile-media-host-overrides).
- **Änderung in Upstream:** Pro Profil Host-Austausch für Bild-/Video-/Download-Requests, Sicherheitsfilter für weitergereichte Header; Konfigurations-UI.
- **Fork / potenzieller Konflikt:** Im Fork nicht vorhanden; Medienzugriff läuft durch eigenen gemeinsamen Image-Cache, mit Source- und Profile-Identität.
- **Ursprüngliche Fragestellung:** Overrides für Cache-Key, Cookies, DNS/Proxies, Medien-Download und Preview? Stufe der UI-Kontrolle?
- **Abnahme/Test:** Original-/Ersatz-Host, Cookie-/Auth-Leakage, Download & Playback, Cache-Isolation.
- **Upstream-Commits:** [`cb5f9fade`](https://github.com/khoadng/Boorusama/commit/cb5f9fade8ed5c7e26d3f0811ef17f7187f73723).
- **Betroffene Codepfade (Auswahl):** `lib/core/configs/network/src/types/media_host_override.dart`, `lib/core/images/booru_image.dart`.
- **Bestätigter Merge-Konflikt in:** `lib/core/images/booru_image.dart`.

### N03 · Cloudflare: state-changing Requests nicht blind erneut senden

**Status:** **ENTSCHIEDEN am 2026-10-15**, Umsetzung ausstehend · **Risiko:** 🟠 hoch.

- **Bestätigter Beschluss:** vollständig übernehmen (Replay-Sicherheit). Upstream-Schutz vor blindem Wiederholen mutierender Requests nach Cloudflare-Challenge übernehmen. POST/PUT, Votes, Favorites, Comments nur bei explizit sicherer Idempotenz erneut senden; Fork-Request-Kontext/Rule34 berücksichtigen.
- **Verifikation:** Mutationen höchstens einmal, sichere GET-Recovery, Abbruch/Fehler.
- **Verbindliches Protokoll:** [N03](decisions.md#n03--cloudflare-state-changing-requests-nicht-blind-erneut-senden).
- **Änderung in Upstream:** HTTP-Recovery unterscheidet Request-Intent; POST/PUT/andere mutations können nicht unkontrolliert erneut abgesendet werden.
- **Fork / potenzieller Konflikt:** Fork hat eigene Rule34-403- und Cloudflare-Recovery mit Replays.
- **Ursprüngliche Fragestellung:** Welche Requests sind retrybar, und wie verhalten wir uns bei Favorite-/Vote-/Comment-Aktionen?
- **Abnahme/Test:** POST/Vote/Favorite nach Challenge maximal einmal, GET mit Clearance, Fehlerpfad.
- **Upstream-Commits:** [`94aa56361`](https://github.com/khoadng/Boorusama/commit/94aa56361ad31a902e7382396e958d27244cda35).
- **Betroffene Codepfade (Auswahl):** `lib/core/http/client/src/interceptors/dio_protection_interceptor.dart`, `packages/coreutils/lib/src/request_intent.dart`.
- **Bestätigter Merge-Konflikt in:** `lib/core/http/client/src/interceptors/dio_protection_interceptor.dart`.

### N04 · Cloudflare-Erkennung, Blockseiten, Redirects und Challenge-UX

**Status:** **ENTSCHIEDEN am 2026-10-15**, Umsetzung ausstehend · **Risiko:** 🟠 hoch.

- **Bestätigter Beschluss:** angepasst übernehmen. Upstream Cloudflare-Challenge-Erkennung, Blockseiten, Captcha-Bestätigung, Subdomain-Redirects, Loop-Vermeidung und Dialog-UX übernehmen; Fork Rule34-403-Recovery erhalten.
- **Verifikation:** 403/429, Captcha, Challenge-Redirect, kein unnötiges Dialog-Aufblitzen/Loop.
- **Verbindliches Protokoll:** [N04](decisions.md#n04--cloudflare-erkennung-blockseiten-redirects-und-challenge-ux).
- **Änderung in Upstream:** Erkennt umgestaltete Cloudflare-Challenges, akzeptiert Captcha in bestätigter Seite und Subdomain-Redirects, verhindert endlose Challenge-Loops und unnötiges Aufblitzen.
- **Fork / potenzieller Konflikt:** Fork hat gezielte Rule34-403-Recovery, Solver- und HTTP-Interceptors sind verändert.
- **Ursprüngliche Fragestellung:** Wie adaptieren wir die Schutz-Seiten-Erkennung ohne unsere Rule34-Wiederherstellung zu verlieren?
- **Abnahme/Test:** Cloudflare 403/429, Challenge-Subdomain, blockierte Seiten, Splash/Hang, Rule34.
- **Upstream-Commits:** [`99ee264db`](https://github.com/khoadng/Boorusama/commit/99ee264dbc2f9649d94b8757575e82b885623e0d), [`bcef3b5c1`](https://github.com/khoadng/Boorusama/commit/bcef3b5c1cf620ff3d67bfaef9e6d623391c3442), [`dc7b9cee9`](https://github.com/khoadng/Boorusama/commit/dc7b9cee911f28049333546c56379be8c51d955a), [`f82a62885`](https://github.com/khoadng/Boorusama/commit/f82a6288563d73e8da1943b7fed499d16f3611d7), [`b0a1d65d9`](https://github.com/khoadng/Boorusama/commit/b0a1d65d9e60131f010491f38877cfd5e5df7b60), [`399a4da47`](https://github.com/khoadng/Boorusama/commit/399a4da47587906a73a316f18c089254b58156d5).
- **Betroffene Codepfade (Auswahl):** `lib/core/ddos/solver`, `lib/core/ddos/handler/protection_handler.dart`.

### N05 · Clearance-Cookie und native WebView-Cookie-Bridge

**Status:** **ENTSCHIEDEN am 2026-10-15**, Umsetzung ausstehend · **Risiko:** 🟠 hoch.

- **Bestätigter Beschluss:** angepasst übernehmen. Upstream-WebView→HTTP-Cookie-Bridge Android/iOS/macOS übernehmen, ohne Fork-App-ID, Native Channels, Cookie-Origin-/Secure-/HttpOnly-Grenzen zu beeinträchtigen.
- **Verifikation:** Gelöste Challenges, Domain/Subdomains, Android/iOS/macOS, unsupported platforms.
- **Verbindliches Protokoll:** [N05](decisions.md#n05--clearance-cookie-und-native-webview-cookie-bridge).
- **Änderung in Upstream:** Cookies nach erfolgreich gelöster Challenge aus WebView und Native CookieManager lesen, für HTTP-Clients korrekt anwenden; Android/iOS/macOS-Kanäle.
- **Fork / potenzieller Konflikt:** Fork hat eigene App-ID/Package-Pfade und zusätzliche Native Channels für Export und Systemsteuerung.
- **Ursprüngliche Fragestellung:** Cookie-Bridge in welchen Plattformen aktiv? Wie werden Cookie-Domain, Secure/HttpOnly und Redirect-Origin behandelt?
- **Abnahme/Test:** Android, iOS, macOS, Cookies auf mehreren Subdomains, Plattform nicht unterstützt.
- **Upstream-Commits:** [`0b4dcfcc4`](https://github.com/khoadng/Boorusama/commit/0b4dcfcc40d22cff1464b34506a6b836f06d7586), [`0ad2e6465`](https://github.com/khoadng/Boorusama/commit/0ad2e646591aceac0ab726aec1213289e42311ac).
- **Betroffene Codepfade (Auswahl):** `android/app/src/main/kotlin`, `ios/Runner/AppDelegate.swift`, `lib/foundation/browser/webview_cookie_channel.dart`.
- **Bestätigter Merge-Konflikt in:** `ios/Runner/AppDelegate.swift`.

### N06 · HTTP/2-Window und automatisches Gzip

**Status:** **ENTSCHIEDEN am 2026-10-15**, Umsetzung ausstehend · **Risiko:** 🟡 mittel.

- **Bestätigter Beschluss:** angepasst übernehmen. HTTP/2-Window- und Gzip-Verbesserungen übernehmen; Fork-Priorisierung, HTTP1-/Plattform-Fallback und mobile Speichergrenzen erhalten.
- **Verifikation:** HTTP2/HTTP1, gzip, hohe Parallelität, wenig RAM.
- **Verbindliches Protokoll:** [N06](decisions.md#n06--http2-window-und-automatisches-gzip).
- **Änderung in Upstream:** Größere HTTP/2-Stream/Connection-Windows und komprimierte Responses.
- **Fork / potenzieller Konflikt:** Fork modifiziert Dio/HTTP2 für aktive Browser-Priorität und Site-Adapter.
- **Ursprüngliche Fragestellung:** Globale oder selektive Einstellung? Grenzen bei mobilen Verbindungen und problematischen Servern?
- **Abnahme/Test:** HTTP/2 Downloads/Lists, HTTP1 fallback, gzip/deflate, low-memory.
- **Upstream-Commits:** [`86a7ee6bb`](https://github.com/khoadng/Boorusama/commit/86a7ee6bbee7a730f9b8931c01919191bd2ad0c3).
- **Betroffene Codepfade (Auswahl):** `lib/core/http/client/src/providers/dio.dart`.

## Downloads, Backups und Export

### D01 · Download Sidecars: TXT-Tags und JSON-Metadaten

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟠 hoch.

- **Bestätigter Beschluss:** angepasst übernehmen. Optionales Download-Sidecar neben der tatsächlich gespeicherten Mediendatei (`<media>.txt` mit einem Tag pro Zeile oder `<media>.json` mit Tags, unverfälschter Herkunft/Site-ID sofern verfügbar, öffentlichen Quelllinks, tatsächlicher Qualität und tatsächlichem Dateinamen) implementieren. Globales Format `off` als Default; pro Bulk-Download-Task ein optionaler Override (Default/Off/TXT/JSON). Keine zusätzliche profilbezogene Einstellung. Einzel-, Bookmark- und Bulk-Downloads sowie Cache-Direktkopien über denselben sicheren, beobachtbaren Completion-Pfad integrieren. Sidecar-Daten als unveränderlichen Post-/Task-Snapshot vor dem Transfer einfrieren, damit Retry/Background-Recovery nicht auf UI-Provider angewiesen sind. Dateien ausschließlich nach bestätigter Transfer-Fertigstellung atomar publizieren; deduplizierte Tags sortiert ausgeben, vorhandene fremde/abweichende Sidecars nicht überschreiben, Konflikt als eigenständig reparierbaren Fehler anzeigen. Sidecar-Fehler dürfen die abgeschlossene Mediendatei nicht erneut herunterladen oder zerstören. Bei `skip if exists` eine vorhandene Mediendatei mitsamt Sidecar unverändert überspringen, auch wenn das Sidecar fehlt. Sensible Cookies/Auth-Header, signierte oder lokale API-/Datei-URLs nicht exportieren. Upstream-Storage/Callbacks/Recovery an Fork-Download-/Observer-/Lifecyclesystem anpassen. D07 entscheidet noch separat die genaue Herkunft der `sitePostId` in Sidecar/JSON.
- **Daten / Abhängigkeiten:** Erfordert voraussichtlich zusätzliche nullable Sidecar-Konfiguration in globalen Settings, Bulk-Task-/Download-Record-Snapshots und additive SQLite-Migration (Upstream Version 2); existierende DB-Records bleiben gültig. Sidecar-Status/Journaling muss Crash/Reboot/Retry ohne doppelte Abschluss-Events (D02) tragen. Keine Änderung am bestehenden Bookmark-/Post-Hive-Schema. Keine erneute lokale Media-Downloadaktion durch bloßen Sidecar-Retry.
- **Verifikation:** Default Off, TXT/JSON, Einzel/Bookmark/Bulk/Video-Cache-Kopie, Skip-if-exists mit/ohne Sidecar, Sidecar-Kollision, readonly/scoped storage, disk full, Crash vor/nach Download/Sidecar-Write, Headless Background-Callback, Recovery nach Restart, Retry nur Sidecar, 0/mehrere Tags, UTF-8/Zeilenumbrüche, URL-/Credential-Redaction und Post-Origin-Identität.
- **Verbindliches Protokoll:** [D01](decisions.md#d01-download-sidecars-txt-tags-und-json-metadaten).
- **Änderung in Upstream:** Optionale `.txt` Tags oder `.json` mit Post-ID, Quellen, Qualität und Dateiname; atomare Sidecar-Erzeugung, Bulk-Download/Storage-Integration.
- **Fork / potenzieller Konflikt:** Fork besitzt komplexere Download-/Share-/Export-Flows; Sidecar-Modul fehlt.
- **Ursprüngliche Fragestellung:** Globaler oder profilabhängiger Schalter? Sidecar bei Duplikaten, Fehlern, bestehenden Dateien und Backups?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Optional, default off; Upstream-Datenmodell unter Beibehaltung unserer Download-Pipeline adaptieren.
- **Abnahme/Test:** Einzel-/Bulk-Download, bereits existierende Datei, Retry, Storage Permissions, Hydrus, sensibles URL-Filtering.
- **Upstream-Commits:** [`86a16a20e`](https://github.com/khoadng/Boorusama/commit/86a16a20ee1327740316005b7946b8264fa70a19).
- **Betroffene Codepfade (Auswahl):** `lib/core/downloads/sidecar`, `lib/core/bulk_downloads/src/providers/bulk_download_notifier.dart`.
- **Bestätigter Merge-Konflikt in:** `lib/core/bulk_downloads/src/providers/bulk_download_notifier.dart`.

### D02 · Bulk-Download-Finalisierung und Benachrichtigungen

**Status:** **ENTSCHIEDEN am 2026-10-15**, Umsetzung ausstehend · **Risiko:** 🔴 kritisch.

- **Bestätigter Beschluss:** Finale Upstream-Completion (nicht den Zwischen-Revert) angepasst übernehmen: fehlgeschlagene Dateigrößenbestimmung tolerieren, Completion pro Session serialisieren, Statistik vor Cleanup sichern und max. 100 abgeschlossene Sessions im Runtime-State für Notifications erhalten. Fork-Lifecycle-Guards beibehalten; Crash-/Cleanup-Fehlerfenster idempotent/restartfähig absichern.
- **Verifikation:** Parallel-Events, Replays, Dateigrößenfehler, Race bei Cleanup/Status, Restart/Resume, korrekte Statistiken, Notification genau einmal und Completion-History.
- **Verbindliches Protokoll:** [D02](decisions.md#d02--bulk-download-finalisierung-und-benachrichtigungen).
- **Änderung in Upstream:** Upstream revertiert frühere deterministische Session-Finalisierung und baut Completion/Notification auf neuer Future-basierten Logik neu auf.
- **Fork / potenzieller Konflikt:** Fork **enthält** den später von Upstream revertierten Original-Fix; beide Varianten behandeln Race Conditions und Cleanup verschieden.
- **Ursprüngliche Fragestellung:** Welcher Algorithmus garantiert abgeschlossene Sessions, korrekte Dateigrößen und Benachrichtigungen bei Cleanup?
- **Frühere Arbeitshypothese (ersetzt durch obigen Beschluss):** Verhalten anhand beider Testsets vergleichen; neue Garantie integrieren, statt Fork-Implementierung blind zu ersetzen.
- **Abnahme/Test:** Task-Stream-Races, parallel completions, Hintergrund/Resume, Notification History und Fehlerfall.
- **Upstream-Commits:** [`ebdfb05d9`](https://github.com/khoadng/Boorusama/commit/ebdfb05d9bec5be5c6fd6dd3e5460cea8ce1e1a1), [`54b19cd4c`](https://github.com/khoadng/Boorusama/commit/54b19cd4cf77b3a75579a2b27aeccc1b1dc56ef5).
- **Betroffene Codepfade (Auswahl):** `lib/core/bulk_downloads/src/providers/bulk_download_notifier.dart`, `lib/core/download_activity`.
- **Bestätigter Merge-Konflikt in:** `lib/core/bulk_downloads/src/providers/bulk_download_notifier.dart`.

### D03 · Background Downloader Plugin-Update

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟡 niedrig–mittel.

- **Bestätigter Beschluss:** Plugin-Commit nach Verifikation übernehmen. Upstream wechselt beim git-basierten `khoadng/background_downloader` mit unveränderter Package-Version `9.6.1` von `e8ad9f9` auf `fd67fff9ee4ad4cdf415dc3285289cad9289cefe`. Commit-Diff/Native-/API-Kompatibilität vor Übernahme prüfen. Nur bei erfolgreicher Prüfung `pubspec_overrides.yaml` und Lockfile konsistent auf den neueren Commit aktualisieren; keinesfalls alte Fork-Callbacks, Cronet-Transport/Resumption, Android-Dateirechte oder Persistenzabläufe ersetzen. Mit D01, D02 und D04 als gemeinsamer Lifecycle-Integrationstest prüfen; bei Inkompatibilität dokumentiert beim alten Pin bleiben bis zur Lösung.
- **Daten / Abhängigkeiten:** Abhängigkeit/Lockfile-Git-Pin, keine geplante eigene Datenmigration. Platform-Plugin-/Native-Build-Verhalten gesondert prüfen.
- **Verifikation:** Android foreground/background, App-Neustart, Pause/Resume, Retry/Cancel, Notifications, Cronet, Cache-/Sidecar-Completion, Task-IDs, Android build und iOS/Desktop soweit unterstützt.
- **Verbindliches Protokoll:** [D03](decisions.md#d03-background-downloader-plugin-update).
- **Änderung in Upstream:** Version des Hintergrund-Downloader-Plugins aktualisiert.
- **Fork / potenzieller Konflikt:** Fork nutzt Cronet und eigene persistente Download-/Notification-Services.
- **Ursprüngliche Fragestellung:** Version übernehmen, wenn mit Fork-Flutter/Cronet/APK-Setup kompatibel?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Nur mit API-/Lockfile-Kompatibilitätscheck übernehmen.
- **Abnahme/Test:** Download in Background, Android Notifications, iOS, Restart.
- **Upstream-Commits:** [`669b8019f`](https://github.com/khoadng/Boorusama/commit/669b8019f80eaf8d0f40e268bbf8a29dc0808ddf).
- **Betroffene Codepfade (Auswahl):** `pubspec.lock`, `pubspec_overrides.yaml`.

### D04 · Download-Manager: injizierbarer Task-Client und Snapshot-Fix

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟡 mittel.

- **Bestätigter Beschluss:** vollständig übernehmen, Fork-Lifecycle bewahren. Den injizierbaren `DownloadTaskClient` für Pause/Resume/Retry/Cancel, Resumability sowie Pfad- und Dateigrößenabfragen nach Upstream-Konzept übernehmen, damit Download-Manager-Widgets und Notifier testbar sind; tatsächliches Enqueueing bleibt beim bestehenden Fork-Download-Service. Bei Task-Updates die existierende Gruppenliste vor Mutation kopieren (`[...?totalTasks[group]]`), statt alte State-Snapshots mutieren zu lassen. Doppeltes Schließen desselben Broadcast-StreamControllers abstellen: ein Provider besitzt/entsorgt den Controller; nach Upstream-Konzept optional zentraler `DownloadTaskEventIngress` veröffentlicht Ereignisse sowohl im Snapshot als auch im Stream. Fork-Retry-/Headers-/DDOS-/Notification-/Download-Activity-Integration bleibt erhalten.
- **Daten / Abhängigkeiten:** Neue schmale Provider-/Task-Interface-Schicht ohne Datenbankänderung, vorhandene Task-IDs und Notification-/State-Strukturen behalten. D02 und D03 berücksichtigen.
- **Verifikation:** Drei oder mehr Updates derselben Task erzeugen unveränderliche frühere Snapshots und vollständige Listener-Events, Dispose ohne double-close, Task-Ingress-Snapshot und Stream identisch, Retry/Cancel/Pause/Resume mit Fake-Client und Auth-/Bypass-Headern, parallele Updates/Grouped Tasks, FileSize-Ausfälle.
- **Verbindliches Protokoll:** [D04](decisions.md#d04-download-manager-injizierbarer-task-client-und-snapshot-fix).
- **Änderung in Upstream:** Downloader-Task-Interface für Testbarkeit; Task-Liste vor Statusupdate kopieren (Mutation/Iteration-Sicherheit).
- **Fork / potenzieller Konflikt:** Fork besitzt Download-Manager und eigene Download-Aktivitätslogik.
- **Ursprüngliche Fragestellung:** Abstraktion vollständig migrieren oder nur den Datenrennen-Fix übernehmen?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Listenkopie direkt portieren; Task-Client nur falls für Tests sinnvoll.
- **Abnahme/Test:** Schnelle parallele Updates, Retry/Cancel, Notifications, Manager-Filter.
- **Upstream-Commits:** [`bd2e22c22`](https://github.com/khoadng/Boorusama/commit/bd2e22c221bcfb1a8c8c0675afbab6763a3102c9), [`90657ee4e`](https://github.com/khoadng/Boorusama/commit/90657ee4ed73f9a4bf7f2277ed1750e2f8b5d4ff).
- **Betroffene Codepfade (Auswahl):** `lib/core/download_manager`.

### D05 · Anime-Pictures Bulk Download und Request-Pacing

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟡 mittel.

- **Bestätigter Beschluss:** angepasst übernehmen. Bulk Downloads für Anime-Pictures aktivieren, einschließlich Site-Capability und mehrseitiger Aufträge. Upstream-Konservativpacing (etwa 1 Request/Sekunde über den relevanten API-/Download-Link-Host) ausschließlich über unseren bestehenden `ApiRequestCoordinator`/sitebezogene N01-Quota abbilden, keinen zweiten `SlidingWindowRateLimitInterceptor` installieren. Den unbefristeten `_downloadUrlCache` aus `AnimePicturesClient` entfernen, da URLs/Session-Cookies veralten; den Fork-`AnimePicturesDownloadFileUrlExtractor` mit begrenztem 5-Minuten-Cache beibehalten, aber Sessionwechsel, Retry nach Auth-Fehler und Links mit begrenzter Gültigkeit verifizieren. Ein Retry soll frische signierte URLs/Cookies beziehen können. Identität/Profil-/Following-Boundaries, bestehende Bulk-Auftrags-Persistenz und Download-UI nicht regressieren.
- **Daten / Abhängigkeiten:** Site-Capability/Generated Booru-Config anpassen (Generator-Output nur nach Änderungen an Source-YAML neu erzeugen); N01-Quota priorisierte Request-Pacing/Retry-After, D02/D04 Download-Lifecycle. Keine zusätzliche eigenständige Rate-Limit-Schicht.
- **Verifikation:** Bulk über mehrere Seiten, rate/429/Retry-After, Link-Expire/Session-Wechsel, Parallel-Profile, Download-Cookie-Handling, vorhandene Cache-Treffer, Cancel/Pause/Resume, Seiten-Cursor und Result-Recovery.
- **Verbindliches Protokoll:** [D05](decisions.md#d05-anime-pictures-bulk-download-und-request-pacing).
- **Änderung in Upstream:** Bulk Download für Anime-Pictures aktivieren, konservatives Request-Pacing von API-/Download-Link-Anfragen.
- **Fork / potenzieller Konflikt:** Fork hat eigene Anime-Pictures-Adapter und Download-URL-Extraktion.
- **Ursprüngliche Fragestellung:** Gleiches Quotenmodell wie Upstream? Wie mit globalen Rate-Limits und Download-Vorgaben kombinieren?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Bulk Download übernehmen; über N01 koordinieren.
- **Abnahme/Test:** Mehrseitige Downloads, 429/Retry-After, gesperrte Links, Caching.
- **Upstream-Commits:** [`c5b79488c`](https://github.com/khoadng/Boorusama/commit/c5b79488c8d90b624cb17e8452d3b17e099be88f).
- **Betroffene Codepfade (Auswahl):** `lib/boorus/anime-pictures/client_provider.dart`, `packages/booru_clients/lib/src/anime-pictures`.

### D06 · Zerochan Bulk Download und URL-Auflösung

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟡 mittel.

- **Bestätigter Beschluss:** angepasst übernehmen. Explizite Sperre für Zerochan-Bulk-Downloads entfernen, sobald URL-Auflösung stabil integriert und getestet ist. API-Detail liefert vorzugsweise explizite `full`/`large`/`medium`/`small`-URLs und Dateigröße/Format; wenn Full fehlt oder JSON defekt ist, gezielt die Post-HTML-Seite lesen; Asiachan-Detail-API zuverlässig durch HTML-Fallback ersetzen. Quellen/Hosts validieren und Fehler/Redirects, 404/410 und temporäre Auth-/Rate-Limits unterscheiden. Pro Post `Preview`, `Sample`, `Original` klar unterstützen; **wenn `Original` explizit angefordert ist, niemals stillschweigend Preview/Sample als Original ausgeben**, sondern nicht auflösbar melden. Dedup gleichzeitiger URL-Requests und kurzer 5-Minuten-Cache analog Upstream übernehmen. Pacing konservativ ca. 1 Request/1,2 Sek über Fork-`ApiRequestCoordinator`, ohne neue Sliding-Window-Interceptor-Schicht; Fork-FileName-/Metadata-/Observer-/Bulk-Lifecycle erhalten.
- **Daten / Abhängigkeiten:** Erweiterte nullable Zerochan-DTO-Felder und PostData-/Adapter-Mapping, neuer Download-URL-Extractor und Source-Capabilities, Quality-basierte Single-Download-Action; N01/N03 und D02/D04 beachten. Cache nur bei gültigen URLs und an Site/Profile geknüpft.
- **Verifikation:** Zerochan + Asiachan API/HTML-Responses, fehlende Original-URL, 404/410, falsche HTML-Seite/Metatags, explicit original vs. degraded variant, Preview/Sample, Redirect/Authentication/429, per-Post-Parallel-Fetch, Cache/Expiry, Dateiname/Extension/Size und Bulk Skip/Retries.
- **Verbindliches Protokoll:** [D06](decisions.md#d06-zerochan-bulk-download-und-url-auflösung).
- **Änderung in Upstream:** Bulk Download für Zerochan reaktivieren, neue Datei-URL-Extraktion und Qualitätsauflösung.
- **Fork / potenzieller Konflikt:** Fork hat eigene Zerochan-Parser und Downloads, neue Bulk-Extractor-Module fehlen.
- **Ursprüngliche Fragestellung:** Welche Qualitätsstufen, Redirects und Auth-Situationen unterstützen?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Funktion vollständig übernehmen, Adapter an Fork-Download-Pipeline anpassen.
- **Abnahme/Test:** Preview/Sample/Original, Access Denied/Rate Limit, bereits vorhandene Files.
- **Upstream-Commits:** [`50980b8da`](https://github.com/khoadng/Boorusama/commit/50980b8da1368aa39a44051c78dee12dd4dff2ce).
- **Betroffene Codepfade (Auswahl):** `lib/boorus/zerochan`, `packages/booru_clients/lib/src/zerochan`.

### D07 · Quellseitige Post-IDs in Exporten statt nur int IDs

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟠 hoch.

- **Änderung in Upstream:** Exports sichern zusätzliche `sitePostId`-Information, damit nicht-numerische/andere Site-IDs erhalten bleiben; enthält außerdem einen Sankaku-Suggestion-Fix.
- **Fork / potenzieller Konflikt:** Fork hat eigene PostOrigin-/Snapshot- und Bookmark-Identität, daher gilt nicht automatisch die Upstream-Struktur.
- **Verifizierter Fork-Befund (2026-10-16):** Die aktuelle Bookmark-Backup-Quelle schreibt Format **v5** (Importer akzeptiert v4/v5): `BookmarkBackupCodec` exportiert `localId` (lokaler Bookmark-Schlüssel), `postId` (`int`, laufzeitinterner/kompatibler Post-Schlüssel), `snapshot` und `identity` (`site` + `postKey`). Sankaku-Postparser weist für alphanumerische Original-IDs einen synthetischen `Post.id` zu, speichert jedoch `SankakuPostData.sankakuId` als native ID; `SankakuPostCodec` serialisiert sie in `snapshot.custom.sankakuId` (Wert + numeric-Flag). Somit bleibt die echte Sankaku-Site-ID im vollständigen aktuellen Backup bereits erhalten. `PostOrigin` repräsentiert **Site/Profilkontext**, nicht die Post-ID. `BookmarkIdentity` kann `id:<siteId>`, für Pixiv aber z. B. `work-page:<illustId>:<pageIndex>` enthalten; ihr vollständiger Key ist keine direkt ausgebbare einfache Site-ID. Pixiv ist ein zusätzlicher Grenzfall: Pro Seite synthetischer `Post.id=illustId*1000+pageIndex`, während alle Seiten eine gemeinsame originale Illust-ID besitzen. Hive-Felder 15/16 bleiben nach X01 belegt. Im aktuellen `DownloadFileNameBuilder` ergibt `{id}` weiterhin `post.id.toString()`. **Auf neue Backup-Speicherung oder Verifikation der Site-ID per Site-API darf man hier nicht schließen.**
- **Bestätigter Beschluss (2026-10-16):** `Post.sitePostId: String?` (X02) liefert die echte Quell-Post-ID als String. Numerische Sites: echte numerische ID; Sankaku: originale numerische oder alphanumerische ID aus `SankakuPostData`; Pixiv: echte `illustId`, nicht synthetische `Post.id`. Bei unbekannter Original-ID `null`, kein künstlicher int-Fallback. Der bestehende Download-Dateinamen-Token **`{id}` wird wie bei Upstream auf `post.sitePostId` umgestellt**. Kein zusätzlicher `{site_post_id}`-Token. Das bisherige Dateinamensverhalten muss laut Nutzer nicht rückwärtskompatibel bleiben, weil Downloads im Fork noch kaum verwendet wurden. Pixiv benutzt bereits als **unverändertes Standardformat `{illust_id}_p{page}.{extension}`**, sodass mehrseitige Artworks eindeutig benannt sind; ein selbstdefiniertes Format nur mit `{id}` kann Seitenkollisionen verursachen, die über bestehende Skip-/Overwrite-Schutzregeln verhindert werden müssen. Bei fehlender echter ID: sicheren nicht als Site-ID ausgegebenen Fallback-Dateinamen oder verständlichen Fehler verwenden, keine synthetische ID als Original ausgeben.
- **Daten / Abhängigkeiten:** D01-JSON-Sidecars und externe Post-Links mit echter Site-ID; bestehende vollständige Bookmark-Snapshots (`custom.sankakuId`), `PostOrigin`, `BookmarkIdentity`, Profil-UUIDs, Backup-Importer v4/v5 und `BookmarksBackupSource` v5 erhalten. Kein redundantes `Bookmark.sitePostId`, kein neues Hive-Feld: 15 = `snapshotSchemaVersion`, 16 = `postSnapshot` (Upstream-Kollision Index 15 nicht übernehmen). Core-seitigen Getter ohne Sankaku-/Pixiv-spezifische direkte Core-Abhängigkeit modellieren.
- **Verifikation:** Danbooru/Gelbooru/Sankaku/Pixiv mit echten IDs für `{id}`; alphanumerische/missing Site-ID; Pixiv-Multi-Page-Default und eigene `{id}`-Only-Kollisionsvorlage; sichere Dateinamen bei unbekannter ID; unveränderte Hive 15/16 und Backup-v4/v5-Roundtrips; gleiche numerische ID auf unterschiedlichen Installationen; D01-Sidecar-ID/Link-Generator ohne synthetische IDs.
- **Verbindliches Protokoll:** [D07](decisions.md#d07-quellseitige-post-ids-in-exporten-statt-nur-int-ids).
- **Ursprüngliche Fragestellung:** In welches bestehende Feld gehört die Quell-ID; wann wird sie persistiert und exportiert?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Funktion übernehmen, **ohne** unsere PostIdentity/BookmarkIdentity zu ersetzen; mit X01 abstimmen.
- **Abnahme/Test:** Export/Import, mehrere Boorus gleicher numerischer ID, nicht-numerische IDs, Migration alter Daten.
- **Upstream-Commits:** [`216eb6e6d`](https://github.com/khoadng/Boorusama/commit/216eb6e6d43cef2581a110b66a8f1482d110e7b9).
- **Betroffene Codepfade (Auswahl):** `lib/core/posts/post/src/types/post.dart`, `lib/core/bookmarks/src/types/bookmark.dart`.
- **Bestätigter Merge-Konflikt in:** `lib/core/bookmarks/src/types/bookmark.dart`, `lib/core/posts/post/src/types/post.dart`.

### D08 · Favorite Tags direkt aus Storage exportieren

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟡 mittel.

- **Bestätigter Beschluss:** übernehmen. Für Favorite-Tag-Backups statt möglicherweise uninitialisiertem UI-State `ref.read(favoriteTagsProvider)` das persistente Repository über `await ref.read(favoriteTagRepoProvider.future)` und `await repo.getAll()` verwenden. Dies gilt auch für alle anderen relevanten vollständigen Backup-/Export-Flows, die derzeit direkt einen UI-Provider-Snapshot benutzen, und für Revision-/Auto-Backups. Bestehende Import-Semantik `repo.replaceAll(tags)` samt `ref.invalidate(favoriteTagsProvider)`, Versionsgrenzen und Label-/Raw-Query-Repräsentation erhalten. Explizite 'Export simple to clipboard'-UI-Funktion bleibt separat erhalten und darf nicht mit dem Full-Backup-Format verwechselt werden.
- **Daten / Abhängigkeiten:** Keine Backupschema-/Persistenzmigration allein wegen D08. X03-Profile-/Import-/Recovery-Invarianten und A12 Headless-Tests berücksichtigen.
- **Verifikation:** Kaltstart Full-Backup ohne Öffnen der Favorite-Tag-Page, zuvor nicht initialisiertes UI-State, mehrere Labels/Raw-Query/Unicode, Auto-/Server-/File-/Clipboard-Backup, vollständiger Roundtrip ohne doppelte Tags, Import ersetzt Tags unverändert; Provider-Invalidation nach Import.
- **Verbindliches Protokoll:** [D08](decisions.md#d08-favorite-tags-direkt-aus-storage-exportieren).
- **Änderung in Upstream:** Backup liest alle Favorite Tags aus dem Repository, nicht aus möglicherweise noch uninitialisiertem UI-Provider.
- **Fork / potenzieller Konflikt:** Fork hat erweiterten Backup-/Import-/Export-Flow und eigene Tags-Repositories.
- **Ursprüngliche Fragestellung:** Änderung sowohl im alten Backup als auch in den Fork-Exportpfaden übernehmen?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Ja, für alle relevanten Backup-Quellen auf vollständigen Datenbestand prüfen.
- **Abnahme/Test:** Kaltstart und Export ohne Tags-Page, mehrfache Labels, Roundtrip.
- **Upstream-Commits:** [`f93bdf0dd`](https://github.com/khoadng/Boorusama/commit/f93bdf0dd42c5eb0e8165d9070310a2aebfa32c1).
- **Betroffene Codepfade (Auswahl):** `lib/core/backups/sources/favorite_tags_source.dart`.

## Booru-spezifische Änderungen

### B01 · Sankaku-Metatags, Syntax-Highlighting und typed Suggestions

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟠 mittel–hoch.

- **Bestätigter Beschluss:** angepasst übernehmen. Sankaku-spezifische Metatag-Definitionen (u. a. `rating`, `date`, `order`, `user`, `pool`, `fav`), Parser, typed Autocomplete-Suggestions und sichere Abbildung der Quellwerte übernehmen. Metatag-Präfixe erkennbar hervorheben, aber die UI in das geplante siteübergreifende Search-Options-Interface einfügen; keine parallele/alte Upstream-Search-Bar bauen. Raw-Syntax und sitespezifische Möglichkeiten bleiben hinter der gemeinsamen Schnittstelle.
- **Abhängigkeiten:** Geplanter gemeinsamer Search-UX-Umbau; B02 und die bestehenden Fork-Suchzustände.
- **Verifikation:** Tag- vs. Metatag-Vorschläge, `fav`/`user`/`pool`, Highlighting, Raw-Query, Leer-/Alias-/unbekannte Werte und neuer Search-UX-Flow, keine Regression in Suche/Tag-Chips.
- **Verbindliches Protokoll:** [B01](decisions.md#b01-sankaku-metatags-syntax-highlighting-und-typed-suggestions).
- **Änderung in Upstream:** Sankaku-Metatags erhalten separate Kategorisierung/Suggestions und syntaktische Highlighting-Regeln.
- **Fork / potenzieller Konflikt:** Fork baut die Tag-Suche und siteübergreifende Abstraktion um; eigener Search-Bar-Code.
- **Ursprüngliche Fragestellung:** Welche Metatags gehören in unser allgemeines Search-Options-Interface, welche sind Sankaku-spezifisch?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Parser/Backend-Support übernehmen; UX in das geplante vereinheitlichte Search Interface integrieren.
- **Abnahme/Test:** Sankaku `rating`, `date`, sort/exclude, getrennte Tag- und Metatag-Vorschläge.
- **Upstream-Commits:** [`216eb6e6d`](https://github.com/khoadng/Boorusama/commit/216eb6e6d43cef2581a110b66a8f1482d110e7b9), [`2569eaeeb`](https://github.com/khoadng/Boorusama/commit/2569eaeeb6ea01ea35386ffc8bab858dcbd1d75d).
- **Betroffene Codepfade (Auswahl):** `lib/boorus/sankaku/tags/metatags.dart`, `lib/boorus/sankaku/search/tag_query_composer.dart`.

### B02 · Sankaku-Exclusion und Datumsfilter normalisieren

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟡 mittel.

- **Bestätigter Beschluss:** übernehmen (site-adaptiert). Sankaku-Exclusion-Restriktionen verständlich übersetzen und nur für Sankaku einzelne gültige `date:YYYYMMDD`/`date:YYYY-MM-DD`-Tokens in einen API-konformen Tagesbereich übersetzen. Eine explizite Range, Operatoren, ungültige Datumsangaben und die sichtbare Raw-Query nicht unkontrolliert umschreiben; Normalisierung unmittelbar im Site-Query-Composer/Adapter.
- **Abhängigkeiten:** B01, B05; gemeinsamer Search-Composer darf keine Sankaku-Syntax auf andere Sites anwenden.
- **Verifikation:** Exclusion-Fehler/Limit-Codes, gültige/ungültige Daten, Tages-/Jahreswechsel, Leap-Day, Range und Vergleich Raw-Eingabe zu gesendetem Query.
- **Verbindliches Protokoll:** [B02](decisions.md#b02-sankaku-exclusion-und-datumsfilter-normalisieren).
- **Änderung in Upstream:** Klarere Fehlermeldungen bei Exclusion-Restriktionen; Einzeldatum in API-tauglichen Tageszeitraum umschreiben.
- **Fork / potenzieller Konflikt:** Fork hat eigene Search-Syntax-Handling-Änderungen.
- **Ursprüngliche Fragestellung:** Direkte API-Normalisierung pro Site oder über die neue allgemeine Search-Abstraktion?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Funktionale Fixes übernehmen, Syntaxauflösung im Site-Adapter belassen.
- **Abnahme/Test:** Datum mit Zeitzonen, Ausschlussbegrenzungen, rohe Query.
- **Upstream-Commits:** [`18216f412`](https://github.com/khoadng/Boorusama/commit/18216f4123586634f0756e7d5b20673638711766), [`6ad672075`](https://github.com/khoadng/Boorusama/commit/6ad672075306e5621a4dde519ad124da0b19f8cb).
- **Betroffene Codepfade (Auswahl):** `lib/boorus/sankaku`.

### B03 · Sankaku-Tag-Kategorien vollständig erhalten, Duplikate entfernen

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟡 mittel.

- **Bestätigter Beschluss:** angepasst übernehmen. Alle bekannten Sankaku-Kategorien einschließlich Studio (`2`), Genre (`5`), Medium (`8`) und Meta (`9`) korrekt site-spezifisch zuordnen (generisches Fork-`TagCategory.fromLegacyId(5)` wäre für Sankaku falsch). Unbekannte Kategorien ohne stillen Verlust erhalten und doppelte API-Tag-Einträge nach echter ID bzw. Name+Kategorie konsistent deduplizieren; sinnvollere Counts übernehmen. Bestehende Fork-`PostRecord`/`PostOrigin`-/Snapshot-/Bookmark-Datenformate behalten, ggf. erweiterten Detailtag-Satz ohne persistente Schemaänderung bereitstellen.
- **Abhängigkeiten:** X01/X02/X03 und Fork-Tag-Modell, keine Upstream-Postmodelle blind ersetzen.
- **Verifikation:** Kategorien 0/1/2/3/4/5/8/9/unbekannt, doppelte Namen/IDs/Counts, Tag-Farben und Filter, Bookmark-Snapshot-Roundtrip, alte Daten.
- **Verbindliches Protokoll:** [B03](decisions.md#b03-sankaku-tag-kategorien-vollständig-erhalten-duplikate-entfernen).
- **Änderung in Upstream:** Alle Tag-Kategorien parsen und beim Post-Mapping deduplizieren.
- **Fork / potenzieller Konflikt:** Fork erweitert Tag- und Post-Datenmodelle; nur teilweiser Gleichstand.
- **Ursprüngliche Fragestellung:** Sind alle upstream Tag-Kategorien sinnvoll und stabil auf unsere Farben/Tag-Gruppen abbildbar?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Parsing-Fixtures und Category-Mapping übernehmen, bestehendes Fork-Tagmodell erhalten.
- **Abnahme/Test:** Kategorien, doppelte Namen mit abweichenden Counts, Bookmark-Snapshot-Roundtrip.
- **Upstream-Commits:** [`d0fde834a`](https://github.com/khoadng/Boorusama/commit/d0fde834a413658bb50db150636c481c88a88222), [`396ae059e`](https://github.com/khoadng/Boorusama/commit/396ae059e9e5576aa0172df7fabf823963c03e92).
- **Betroffene Codepfade (Auswahl):** `lib/boorus/sankaku/posts/parser.dart`, `lib/boorus/sankaku/tags`.
- **Bestätigter Merge-Konflikt in:** `lib/boorus/sankaku/posts/parser.dart`.

### B04 · Sankaku-Auth: API-Header, invalid credentials, Session-Recovery

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟠 hoch.

- **Bestätigter Beschluss:** angepasst übernehmen. Bestehende Dio-Optionen/Interceptors/Header beim Sankaku-API-Header-Merge erhalten. Login-Response vor Token-Speicherung streng validieren. Bei erkennbar abgelaufenem/ungültigem Token GET-Requests höchstens einmal nach kontrollierter Neuanmeldung wiederholen; gleichzeitige Logins pro Client zusammenfassen, nur das tatsächlich abgelehnte Token invalidieren und Client-/Profile-Isolation bewahren. Mutierende Favorites/POST/DELETE nicht blind wiederholen, sondern Fehler melden und neue Auth für spätere Nutzeraktionen ermöglichen. Wenn Auto-Reauth scheitert, bestehende Profil-Login-UX verwenden; Tokens/Credentials nie loggen.
- **Abhängigkeiten:** N01/N03/N04/N05; bestehendes Fork-Profil- und Credential-Modell, kein Cross-Origin-Auth-Leak.
- **Verifikation:** Ungültige Credentials/Tokenformat, 401/API-Auth-Code, gleichzeitige GETs, erneute Ablehnung, Profilwechsel, Cookie/Header-Erhalt, Favoriten ohne Doppelmutation, Cancellation/Rate-Limit und Credential-Redaction.
- **Verbindliches Protokoll:** [B04](decisions.md#b04-sankaku-auth-api-header-invalid-credentials-session-recovery).
- **Änderung in Upstream:** Client-Optionen beim API-Header-Merge bewahren; Auth-Responses validieren; abgelaufene Sessions recovern; Login-Rejections korrekt anzeigen.
- **Fork / potenzieller Konflikt:** Fork nutzt eigenes Profil-/Auth-Modell, zusätzliche Favorite-Integration.
- **Ursprüngliche Fragestellung:** Welche Recovery ist automatisch und wann muss neu authentifiziert werden?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Fixes übernehmen, bestehende Token-/Credential-Speicherung und Auth-Prompts nutzen.
- **Abnahme/Test:** Falsche Daten, abgelaufenes Cookie, mehrere Profile, Rate Limit, keine Credentials in Logs.
- **Upstream-Commits:** [`829ec71fb`](https://github.com/khoadng/Boorusama/commit/829ec71fbaedbc60fff7d98fe1b40c494a130ebe), [`6ad691a6d`](https://github.com/khoadng/Boorusama/commit/6ad691a6de23d8a44c46d02bf3640997dbb618f4), [`6762d00f2`](https://github.com/khoadng/Boorusama/commit/6762d00f2e4ac6efc99bf969bd15a335f6767437), [`8757eb295`](https://github.com/khoadng/Boorusama/commit/8757eb2953d41716bc7c8fb3a028b71fb3f03e2c).
- **Betroffene Codepfade (Auswahl):** `packages/booru_clients/lib/src/sankaku/sankaku_client.dart`, `lib/boorus/sankaku/sankaku_repository.dart`.
- **Bestätigter Merge-Konflikt in:** `lib/boorus/sankaku/sankaku_repository.dart`, `packages/booru_clients/lib/src/sankaku/sankaku_client.dart`.

### B05 · Sankaku-Suchlimits korrekt erklären

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** ⚪ niedrig.

- **Bestätigter Beschluss:** vollständig übernehmen (in Fork-Fehler-UI). Sankaku-Codes für anonyme/Account-Tag-Limits in verständliche lokalisierte Meldungen übersetzen und an den Fork-Error-Layer anbinden. Bestehendes Verhalten bei unbekannten Serverfehlern als Fallback behalten.
- **Abhängigkeiten:** B02 sowie vorhandener Error-Translator/i18n.
- **Verifikation:** Anonyme/Account-Limits, bereits durch B02 erfasste Exclusion-Limits, lokalisierte Meldungen, unbekannte Fehler und Retry.
- **Verbindliches Protokoll:** [B05](decisions.md#b05-sankaku-suchlimits-korrekt-erklären).
- **Änderung in Upstream:** API-Fehler zu Tag-Limits in verständliche Fehlermeldungen übersetzen.
- **Fork / potenzieller Konflikt:** Fork hat Suchfehler-/Translation-Layer.
- **Ursprüngliche Fragestellung:** Site-Meldung übernehmen und in unsere Error-UI einhängen?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Ja, sofern die Fehlermeldung der aktuellen API entspricht.
- **Abnahme/Test:** Grenzwert überschritten, lokalisierte Fehlermeldung, Retry.
- **Upstream-Commits:** [`5b495f1ad`](https://github.com/khoadng/Boorusama/commit/5b495f1adec13643ee83307bb2b68eb0272766b2).
- **Betroffene Codepfade (Auswahl):** `lib/boorus/sankaku/errors/error_translator.dart`.

### B06 · Shimmie2: Medienformate und Favorite-Fallback

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟡 mittel.

- **Bestätigter Beschluss:** angepasst übernehmen. Dateiformate aus `ext`, Filename und Datei-URL robust normalisieren (ohne Punkt, lowercase). Den serverseitigen Favorite-Status bei unterstützter Erweiterung und angemeldetem Nutzer ergänzen, aber optional und möglichst asynchron nach dem eigentlichen Post-Laden: Die Timeline darf bei Ausfall, fehlender Auth oder langsamer Favorite-API nicht blockiert werden. Späte Ergebnisse mit bereits erfolgten Nutzeraktionen bzw. aktuellem Favorite-Cache zusammenführen statt überschreiben; Fehler als Soft-Failure behandeln, bekannte Auth-Probleme sinnvoll sichtbar machen.
- **Abhängigkeiten:** Fork-Favorite-Repository/Cache und Shimmie2-Feature-Capabilities.
- **Verifikation:** Erkennung verschiedener Medienextensions/URL-Formate, fehlende Extension, GraphQL/REST, 100er-ID-Batches, Favoritenabfrage mit/ohne Login, Serverfehler/Timeout, schnelle Favorite-Mutation während laufender Abfrage.
- **Verbindliches Protokoll:** [B06](decisions.md#b06-shimmie2-medienformate-und-favorite-fallback).
- **Änderung in Upstream:** Dateiformate genauer erkennen, Favorite-State zuverlässig abfragen; wenn Favorite-API fehlschlägt, Listings trotzdem laden.
- **Fork / potenzieller Konflikt:** Fork hat Shimmie2-Client, Parsing und eigene Favoriten-Änderungen.
- **Ursprüngliche Fragestellung:** Welche Fehler sind soft failures, welche Auth-Fehler?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Fixes übernehmen und Seite nie wegen eines optionalen Favorite-States blockieren.
- **Abnahme/Test:** API teilweise offline, verschiedene Media-Extensions, Auth abgelaufen.
- **Upstream-Commits:** [`2d4f8484b`](https://github.com/khoadng/Boorusama/commit/2d4f8484ba62db8e5c5386825934b1bcc30455cf), [`d79ef1fcc`](https://github.com/khoadng/Boorusama/commit/d79ef1fcc9f59b07933e76681b6c033e12327460).
- **Betroffene Codepfade (Auswahl):** `lib/boorus/shimmie2`, `packages/booru_clients/lib/src/shimmie2`.

### B07 · Gelbooru v2: Kommentar-Voting und Cursor-Pagination

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟠 mittel–hoch.

- **Bestätigter Beschluss:** angepasst übernehmen. Upstream-Gelv2-Comment-Page-Keys, Rule34-HTML-Kommentarparser/Score und cursorbasierte Pagination kompatibel zu Fork-Comment-/Postmodell übernehmen. **Upstream implementiert nur Kommentar-Upvotes, keine Downvotes**; keine Downvote-UI behaupten oder erfinden. Voting nur bei expliziter Site-Capability und gültiger Session anzeigen, mutierenden Upvote-GET trotz HTTP-Verb als Mutation behandeln (kein automatischer Replay nach Challenge/Retry), Auth- und Fehlerfälle sichtbar machen. Andere Gelv2-Sites behalten ihre vorhandenen Kommentar-Fetchpfade.
- **Abhängigkeiten:** N03/N04, B08, Fork-Comment-/Selection-UI, Site-Capabilities.
- **Verifikation:** Rule34-HTML/Script-Scores, Kommentare/Quotes, Cursor vorwärts/Ende, wiederholte Requests/Sortwechsel, login/no-login, Score- und Action-Fehler, POST-ID-Zuordnung, keine Doppelvotes unter 403/Cloudflare.
- **Verbindliches Protokoll:** [B07](decisions.md#b07-gelbooru-v2-kommentar-upvote-und-cursor-pagination).
- **Änderung in Upstream:** Kommentar-Upvote (kein Downvote) und Cursor-basierte Navigation in Gelbooru-v2-Clients.
- **Fork / potenzieller Konflikt:** Fork hat eigenen Comment-/Post-Kontext und Rule34-Gelv2-Sonderfälle.
- **Ursprüngliche Fragestellung:** Für welche Gelv2-Sites ist Voting erlaubt, wie bestimmen wir Capabilities und Auth?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Funktion übernehmen, im Site-Feature-Interface capability-abhängig machen.
- **Abnahme/Test:** Mit/ohne Login, Cursor vor/zurück, API-Antwortvarianten und Rule34.
- **Upstream-Commits:** [`f459e9922`](https://github.com/khoadng/Boorusama/commit/f459e99220e4ac5b449c033d1d60a0b672ea2b58).
- **Betroffene Codepfade (Auswahl):** `lib/boorus/gelbooru_v2/comments`, `packages/booru_clients/lib/src/gelbooru_v2`.

### B08 · Gelbooru v2: Kommentar-Sortierung

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟡 mittel.

- **Bestätigter Beschluss:** übernehmen, gemeinsam mit B07. Auf Sites, deren Comment-Capabilities es explizit vorsehen (Upstream: Rule34), `Newest`/`Oldest` über unterstützte Request-Sortierung anbieten (für Rule34 `comments_direction`-Cookie); bestehende Session-Cookies sicher mergen. Änderung nur innerhalb der aktuellen Kommentaransicht merken, ohne neue persistente Profileinstellung; Pagination/Cursor beim Umschalten vollständig zurücksetzen. Keine Optionen auf nicht unterstützten Sites zeigen.
- **Abhängigkeiten:** B07 und Site-Feature-/Sort-Capabilities.
- **Verifikation:** Newest/Oldest, Cookie-Isolation, Cursor-Reset, schnelle Sortwechsel und verspätete Requests, einzelne Seite und Reload.
- **Verbindliches Protokoll:** [B08](decisions.md#b08-gelbooru-v2-kommentar-sortierung).
- **Änderung in Upstream:** Server-/Client-Sortoptionen für Kommentare je nach API-Variante.
- **Fork / potenzieller Konflikt:** Fork nutzt eigenen Gelbooru-v2-Comment-Provider.
- **Ursprüngliche Fragestellung:** Welche Sortmodi anzeigen, Site-Capability und Persistenz pro Profil?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Sortoptionen nur anbieten, wenn der jeweilige Server sie unterstützt.
- **Abnahme/Test:** Cursor+Sort, unbekannte Parameternamen, Reload.
- **Upstream-Commits:** [`43619dd49`](https://github.com/khoadng/Boorusama/commit/43619dd495d5cb79425845521f0a0e0de030670d).
- **Betroffene Codepfade (Auswahl):** `lib/boorus/gelbooru_v2/comments`, `packages/booru_clients`.

### B09 · Nozomi: korrekte Tag-Counts und HTTP-Range-Encoding

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟡 niedrig–mittel.

- **Bestätigter Beschluss:** angepasst übernehmen. Nozomi-Tag-Counts aus Postindex-Dateigrößen statt Search-Buckets bestimmen; gezielte Byte-Range-Requests mit `Accept-Encoding: identity`, Behandlung 200/206/404/416 sowie Content-Range und Cache/Fallback korrekt übernehmen. Gleichzeitige Count-Lookups drosseln und mit dem Fork-`ApiRequestCoordinator` koordinieren, damit parallele Autosuggestions und Following keine unnötigen Host-Requests verursachen.
- **Abhängigkeiten:** N01; Nozomi-Client/Rate-Policy des Forks.
- **Verifikation:** Byte-Größe/4, partial/full Responses, fehlender Content-Range, 404/416/0, Range+gzip, Cache, Limits/429, parallele Suggestions und Cancellation.
- **Verbindliches Protokoll:** [B09](decisions.md#b09-nozomi-korrekte-tag-counts-und-http-range-encoding).
- **Änderung in Upstream:** Tag-Counts aus Index-Größen statt Search-Buckets; Range-Requests senden `Accept-Encoding: identity`.
- **Fork / potenzieller Konflikt:** Fork unterstützt Nozomi bereits.
- **Ursprüngliche Fragestellung:** Direkter Cherry-pick möglich? Prüfen, ob Site-Client im Fork abweicht.
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Als isolierten Adapter-Fix übernehmen.
- **Abnahme/Test:** Tag-Count-Fixtures, Status 200/206/416, komprimierte Antworten.
- **Upstream-Commits:** [`7880a020f`](https://github.com/khoadng/Boorusama/commit/7880a020fc7ba968351ee5256d3685c347d4eca0), [`5a4498f78`](https://github.com/khoadng/Boorusama/commit/5a4498f78dbce67aa43c0d3d01c4fc8d31784a23).
- **Betroffene Codepfade (Auswahl):** `packages/booru_clients/lib/src/nozomi`.

### B10 · Rule34: JSON-Post-API auf api.rule34.xxx

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟠 hoch.

- **Bestätigter Beschluss:** angepasst übernehmen, erst nach Verifikation aktivieren. Rule34-Listing-Endpoint nach gezielten Live-API-Tests auf `https://api.rule34.xxx/index.php?page=dapi&s=post&q=index&json=1` umstellen, da der Fork diesen Host bislang nur für Post-Details verwendet. Profil- und Site-Identität, Auth-/Cookie-Origin-Grenzen, Parsing, Pagination, Rate-Limits sowie eigene Rule34-403-/Cloudflare-Recovery erhalten. Bei Inkompatibilität zuerst Ursache bewerten, keinen ungetesteten Hostwechsel erzwingen.
- **Abhängigkeiten:** N01/N02/N04/N05; aktuelles `boorus.yaml`-Rule34-Profil.
- **Verifikation:** JSON-Post-Listen/Details, Pagination/Filter/Limit, mit und ohne Login, CORS/Redirect, 403-Challenge, Rate-Limit/429, Content-Shape, Cross-Host-Auth und Cache-Isolation; Live-Verifikation ist noch nicht erfolgt.
- **Verbindliches Protokoll:** [B10](decisions.md#b10-rule34-json-post-api-auf-apirule34xxx).
- **Änderung in Upstream:** Override für `posts` auf `https://api.rule34.xxx/index.php?page=dapi&s=post&q=index&json=1`.
- **Fork / potenzieller Konflikt:** Fork nutzt bisher `rule34.xxx/index.php?...` und hat besondere 403-Challenge-Recovery.
- **Ursprüngliche Fragestellung:** Welcher API-Host funktioniert zuverlässiger und wie verhalten sich Cookies, Suche und Profile?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Endpoint nach Live-API-Tests übernehmen; mit N02/N04 abstimmen.
- **Abnahme/Test:** Posts, Pagination, Auth, Error-403, Domain-/Cache-Isolation, Rate Limits.
- **Upstream-Commits:** [`5972548ec`](https://github.com/khoadng/Boorusama/commit/5972548ecd6e32622b8476776490251d61d6a099).
- **Betroffene Codepfade (Auswahl):** `packages/booru_clients/boorus.yaml`.
- **Bestätigter Merge-Konflikt in:** `packages/booru_clients/boorus.yaml`.

## Posts, Grid, Viewer und Medien

### P01 · Zwei Quick Actions auf Post-Thumbnails

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟠 hoch.

- **Bestätigter Beschluss:** Zwei pro Profil konfigurierbare verschiedene Quick Actions samt adaptiver Platzierung übernehmen, aber die Origin-gebundene Fork-`defaultActionButton`-Auflösung (Danbooru-spezifischer Favorite-Build und Mixed-Booru-Posts) erhalten; Selection hat Vorrang, Legacy-Einzelaction verlustfrei migrieren, kleine Kacheln nur primäre Action; Series-Karten nicht blind pro Einzelpost mutieren.
- **Verifikation:** Primary/Secondary/None; Post-Origin-spezifische Default-Builds, Legacy-Profile, kleines Grid/Selection, Score-/Hover-Overlays und Keyboard P14.
- **Verbindliches Protokoll:** [P01](decisions.md#p01-zwei-quick-actions-auf-post-thumbnails).
- **Änderung in Upstream:** Per Profil primäre + sekundäre Action (`favorite`, `bookmark`, `download`, `artist`/default) mit adaptivem Button-Layout.
- **Aktualisierter Fork-Befund (2026-10-16; P01 bleibt offen):** `PostGridItem` löst seine `PostGridItemAdditions.quickActionButton` per `post.origin` und passendem `BooruPostPresentation` auf und übergibt ihn als `defaultActionButton` an `DefaultImagePreviewQuickActionButton`. Nur bei der im Profil gewählten Standardaktion wird dieser sitespezifische Button verwendet; andernfalls gewählte Bookmark/Download/Artist-Actions gehen vor. `DanbooruPostGridPresentation` liefert z. B. `DanbooruQuickFavoriteButton` mit Banned-Status-Handling. Dieses Forwarding wurde am 2026-09-24 durch den [Unified-Post-Pipeline-Commit `c00ac614f`](https://github.com/timberpile/Boorusama/commit/c00ac614f8fb5849e57f924b6bfeaaf8a22a057c) eingeführt und muss bei P01 vollständig erhalten bleiben; Zwei-Actions-UI wurde am 2026-10-16 mit dem oben beschriebenen Forwarding ausdrücklich bestätigt.
- **Fork / potenzieller Konflikt:** Fork zeigt bisher eine Quick Action und hat eigene Grid-Overlays, Selection und geplantes Series Grouping.
- **Ursprüngliche Fragestellung:** Welche Actions und Positionen? Wann werden sie bei Selection, Hover und Series-Karten angezeigt?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Feature übernehmen, aber Layout/Hit-Targets und Post-Grid-Integration im Fork gestalten.
- **Abnahme/Test:** Kleine Grids, große Schrift, Hold-and-Drag Selection, Favoriten-APIs, Keyfocus.
- **Upstream-Commits:** [`26ad35202`](https://github.com/khoadng/Boorusama/commit/26ad352026bb4187e399dfab422c76427aca8655).
- **Betroffene Codepfade (Auswahl):** `lib/core/configs/listing`, `lib/core/posts/listing/src/widgets/default_image_quick_actions.dart`.

### P02 · Profile mit unbekannten Thumbnail-Actions/Media-Host-Regeln behalten

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟠 hoch.

- **Bestätigter Beschluss:** angepasst übernehmen. Optionale unbekannte/ungültige Thumbnail-Action-Werte und Media-Host-Overrides beim Einlesen tolerant behandeln, ohne das Profil als Ganzes zu verwerfen; bei Import/Restore nachvollziehbare Validierungswarnungen anbieten. Existierende Profil-UUIDs und übrige Daten stets behalten. Unbekannte, semantisch nicht auswertbare Werte, soweit technisch sicher möglich, für Forward-Compatibility im Originaldatensatz erhalten; andernfalls nur die betroffene Option mit dokumentiertem Fallback behandeln.
- **Daten / Abhängigkeiten:** Keine Änderung an Profil-UUIDs oder Identitäten. Die noch offene P01-Konfigurationsmigration sowie N02-Media-Host-Regeln müssen das Fallback- und Warnmodell gemeinsam nutzen.
- **Verifikation:** Alte/neue Profil-JSONs; unbekannte Action, fehlender/ungültiger Host oder Datentyp, doppelte Aktionen, Restore ohne Profilverlust und sichtbare Import-Warnungen.
- **Verbindliches Protokoll:** [P02](decisions.md#p02-profile-mit-unbekannten-thumbnail-actionsmedia-host-regeln-behalten).
- **Änderung in Upstream:** Defensive Deserialisierung ignoriert unbekannte Action-Werte und ungültige Host-Regeln statt gesamtes Profil zu verwerfen.
- **Fork / potenzieller Konflikt:** Fork hat Profil-UUIDs und Import-Mapping mit eigenen Validierungen.
- **Ursprüngliche Fragestellung:** Welche Konfigurationsfehler tolerieren wir und wie informieren wir Nutzer beim Import?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Profil nie wegen optionalem neuen Feature verlieren; Validierungswarnung statt Datenverlust.
- **Abnahme/Test:** Forward-/Backward-Profile-Import, unknown enum, invalid hostname, doppelte Actions.
- **Upstream-Commits:** [`1d8c879f4`](https://github.com/khoadng/Boorusama/commit/1d8c879f406d54df86c25d334ace0ada98846886).
- **Betroffene Codepfade (Auswahl):** `lib/core/configs/config/src/types/booru_config.dart`, `lib/core/configs/listing/src/types/thumbnail_actions.dart`.

### P03 · Bildladefehler: Tap-to-Retry nur bei passenden Error-Widgets

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟡 mittel.

- **Bestätigter Beschluss:** angepasst übernehmen. Endgültige Upstream-Variante mit explizitem `ExtendedImageController.reload()` statt früherem flächendeckendem `GestureDetector` verwenden. In Fork-Grid und Post-Viewer gut sichtbaren, fokussierbaren Retry-Button im `ErrorPlaceholder` anbieten; Tippen auf restliche Kachel muss weiterhin den Post öffnen und Selection-/Hold-Gesten respektieren. Der Fork-`ProgressivePostImage` hat eine eigene Kandidaten-/Generations-Loading-Pipeline und muss einen separaten kontrollierten Retry des fehlgeschlagenen Ziel-/Fallback-Requests ermöglichen, ohne ein bereits erfolgreich dekodiertes niedrigeres Bild zu verlieren. Kein automatisches endloses Retry oder unkontrolliertes Disk-Cache-Löschen.
- **Daten / Abhängigkeiten:** Keine persistente Migration; `packages/extended_image`-API und Fork-Progressive-Loader/Shared-Cache entsprechend anpassen. X04-Cache-Invarianten erhalten.
- **Verifikation:** Primary/Fallback/Progressive-Fehler, Zielbild-Neuladen mit gehaltenem Placeholder, Retry nach 403/Timeout/invalidierter Datei, Kachel-Tap vs. Retry-Button, Selection/Long-Press, Accessibility/Keyboard und keine dauernde Request-Schleife.
- **Verbindliches Protokoll:** [P03](decisions.md#p03-bildladefehler-tap-to-retry-nur-bei-passenden-error-widgets).
- **Änderung in Upstream:** Upstream stellt zunächst tap-to-retry für Custom-Error-Widgets her und nimmt später pauschale implicit Retry-Gestures zurück.
- **Fork / potenzieller Konflikt:** Fork verwendet Custom Error-UI und Shared Image Cache.
- **Ursprüngliche Fragestellung:** Soll ein Thumbnail-/Viewer-Fehler direkt per Tap retryen oder über sichtbaren Button?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Explizite, zuverlässige Retry-Affordance erhalten; keine unsichtbaren Gestures, die Post-Open abfangen.
- **Abnahme/Test:** Failed preview, viewer tap/hold, retry mit neuen Cache-Keys.
- **Upstream-Commits:** [`afdff42e3`](https://github.com/khoadng/Boorusama/commit/afdff42e344a585439bef34893bc2cbaa8e706df), [`58e4a0607`](https://github.com/khoadng/Boorusama/commit/58e4a06075faa8c07d8129dfdfa19156a4981a50).
- **Betroffene Codepfade (Auswahl):** `packages/extended_image/lib/src/extended_image.dart`.
- **Bestätigter Merge-Konflikt in:** `packages/extended_image/lib/src/extended_image.dart`.

### P04 · Post-Grid: Refresh während laufendem Fetch nicht verlieren

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟡 mittel.

- **Bestätigter Beschluss:** Fork-Race-/Refresh-Queue behalten und gezielt ergänzen. Bestehenden `PostGridController` mit `_refreshPending`, `_pendingMaintainPage`, `_pendingPreserveSelection` und `_queuedRefreshWaiters` unverändert als einzige Refresh-Queue erhalten. Upstreams Latest-Result-Schutz ergänzen: Wenn während des laufenden Fetchs eine neue Suche/ein Refresh/ein Profilwechsel vorgemerkt wird, die veraltete Antwort nicht zwischenzeitlich in den sichtbaren Grid-State übernehmen, sondern danach den neuesten Stand laden und erst dessen Ergebnis veröffentlichen. Fehler veralteter Passes nicht als endgültige UI-Fehler anzeigen, wenn der zuletzt angeforderte Pass erfolgreich war; aber echte letzte Fehler und wartende Future-Aufrufer korrekt behandeln. Keine zusätzliche Upstream-Refresh-Queue oder Selection-Reset einführen.
- **Daten / Abhängigkeiten:** Keine Datenmigration; Bezug auf Following Topics, automatische Suchänderungen, Profilwechsel und P05-X03-Bookmark-Library-Gate.
- **Verifikation:** Getaktete, konkurrierende Fetches/Refreshes, alte Antwort nicht gerendert, spätester Query/Profil-Snapshot gewinnt, Fetch-Fehler vor erfolgreichem Folgepass, maintainPage, preserveSelection, Wartende Future, Dispose, Duplicate-Fetches/Loading-State.
- **Verbindliches Protokoll:** [P04](decisions.md#p04-post-grid-refresh-während-laufendem-fetch-nicht-verlieren).
- **Änderung in Upstream:** `PostGridController` merkt sich Refresh-Anfragen und führt sie nach dem aktuellen Fetch aus.
- **Fork / potenzieller Konflikt:** Fork hat Prefetch, adaptive Timings und Following/Subscription-Feeds.
- **Ursprüngliche Fragestellung:** Wie mit manuellem Refresh, automatischer Feed-Aktualisierung und bestehendem Request-Scheduling kombinieren?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Race-Fix übernehmen, mit Cancel/Dedup-Mechanismen des Forks verbinden.
- **Abnahme/Test:** gleichzeitiger Fetch+Refresh, maintainPage, kein Doppelabruf oder UI-Hang.
- **Upstream-Commits:** [`828ddbdb7`](https://github.com/khoadng/Boorusama/commit/828ddbdb75afd02fe14cf8182774a3ef67c9128f).
- **Betroffene Codepfade (Auswahl):** `lib/core/posts/listing/src/widgets/post_grid_controller.dart`.
- **Bestätigter Merge-Konflikt in:** `lib/core/posts/listing/src/widgets/post_grid_controller.dart`.

### P05 · Bookmark-Library nach Bookmark-Mutation aktualisieren

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟡 mittel.

- **Bestätigter Beschluss:** Fork-Lösung behalten. Keinen zusätzlichen Upstream-Bookmark-Listener einbauen: Der Fork lauscht bereits auf `bookmarkProvider` und koordiniert Sichtbarkeitswechsel/Selection über `BookmarkViewRefreshGate`. Diesen einzigen autoritativen Refreshpfad behalten; nur nützliche Upstream-Regressionstests ergänzen.
- **Daten / Abhängigkeiten:** Keine API-/Datenmigration. Überschneidet sich mit dem verbindlichen X03-Beschluss.
- **Verifikation:** Bookmark hinzugefügt/gelöscht, Undo, Group-Switch, Sortierung, Filter, Details-Overlay und Selection-Stabilität; nur ein sichtbarer Refresh pro Mutation.
- **Verbindliches Protokoll:** [P05](decisions.md#p05-bookmark-library-nach-bookmark-mutation-aktualisieren).
- **Änderung in Upstream:** Listener aktualisiert sichtbare Bookmark-Liste nach Änderungen.
- **Fork / potenzieller Konflikt:** Fork hat lokale Bookmark-Groups, Default Group, Undo und eigene asynchrone Library-Services.
- **Ursprüngliche Fragestellung:** An bestehendes Change-Event- / Selection-Modell anbinden oder Upstream-Listener zusätzlich verwenden?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Nur ein autoritatives Update-Signal, um doppelte Refreshes/Selection-Resets zu vermeiden.
- **Abnahme/Test:** Bookmark hinzufügen/entfernen, Gruppenwechsel, Undo, aktive Filter/Sort.
- **Upstream-Commits:** [`3f4ce2bd4`](https://github.com/khoadng/Boorusama/commit/3f4ce2bd4f0f94c116b2262fa9418809710278a8).
- **Betroffene Codepfade (Auswahl):** `lib/core/bookmarks/src/widgets/bookmark_scroll_view.dart`.
- **Bestätigter Merge-Konflikt in:** `lib/core/bookmarks/src/widgets/bookmark_scroll_view.dart`.

### P06 · GIF-Autoplay respektiert Qualitätseinstellungen

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟡 niedrig–mittel.

- **Bestätigter Beschluss:** angepasst übernehmen. GIF-Autoplay-Setting bei allen Grid-Qualitätsstufen einschließlich `original` respektieren: Bei deaktiviertem Autoplay nur eine statische Vorschau laden; bei aktivem Autoplay die nach Site tatsächlich verfügbare animierte URL entsprechend Qualität/Fallback wählen. Wichtig: Statische kleinere GIF-Thumbnails sind keine garantierten niedrig aufgelösten *animierten* GIF-Varianten; Danbooru liefert häufig statische 180/360/720-Varianten und die animierte Original-GIF. Eine fehlende animierte Preview nicht erfinden; im Viewer gelten dessen eigene Qualität-/Abspielregeln.
- **Daten / Abhängigkeiten:** Fork-spezifische Danbooru-Variant-URL-Auflösung und generischen Thumbnail-Resolver erhalten; keine persistente Migration.
- **Verifikation:** Danbooru/andere Boorus, automatische/low/high/highest/original-Qualität × autoplay/static, verfügbares/unverfügbares Sample, URL und Aspect Ratio, GIF-Animation bei deaktiviertem Autoplay im Grid.
- **5-MiB-Originaldateigrößen-Limit (2026-10-16, bestätigt):** Automatische animierte GIF-URLs im Grid (auch `sample`) nur laden bei aktiviertem GIF-Autoplay und positivem, bekanntem `post.fileSize` des Originals ≤ `5 * 1024 * 1024`. Originalgröße > Limit oder unbekannt/0: statische Vorschau unabhängig von `Highest`, keine zusätzliche HEAD-Anfrage. `VariantDto` bietet keine Sample-Dateigröße; damit kann `sample` die Schranke nicht umgehen. Bestehende Qualitäts-/Variantenwahl für erlaubte kleine GIFs respektieren; expliziter Viewer/Downloads ausgenommen. Tests für exakten Grenzwert, unbekannten Wert und mögliche Animations-/Decoder-Kosten.
- **Korrektur / Laufzeitbeobachtung (2026-10-16):** Bei **manuell Highest** und Danbooru-GIFs in normalen/großen Grids wird die `sample`-Variante aufgelöst, welche animiert sein kann (vom Nutzer bestätigt). Bei Automatic wählt der GIF-Spezialpfad unabhängig von `resolvedImageQuality` 180/360/720; Automatic+Large ergibt bislang 720 und ist NICHT automatisch Highest. Bei aktiviertem Autoplay das animierte Highest-Sample beibehalten, bei deaktiviertem Autoplay auch dort statisch anzeigen. Die Upstream-Korrektur erfasst generische GIFs, aber der Danbooru-Highest-Pfad braucht zusätzliche Fork-Anpassung; keine implizite Änderung der Auto-Grid-Stufen.
- **Verbindliches Protokoll:** [P06](decisions.md#p06-gif-autoplay-respektiert-qualitätseinstellungen).
- **Änderung in Upstream:** GIF-Autoplay-Setting greift auch bei alternativen Bildqualitäten.
- **Fork / potenzieller Konflikt:** Fork trennt Preview-/Post-Qualitäten und hat GIF-Export-/Trim-Tools.
- **Ursprüngliche Fragestellung:** Fix in unsere Quality-Resolver übertragen?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Ja, falls nicht bereits durch eigene Quality-Änderungen behoben.
- **Abnahme/Test:** GIF preview/sample/original, Energie-/Datenspar-Setting.
- **Upstream-Commits:** [`e4d645630`](https://github.com/khoadng/Boorusama/commit/e4d6456309c93f050b3a5d311ea4e2a60e0a7663).
- **Betroffene Codepfade (Auswahl):** `lib/core/posts`, `lib/boorus`.

### P07 · Video-Thumbnail bis zum ersten gerenderten Frame anzeigen

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟡 mittel.

- **Bestätigter Beschluss:** angepasst übernehmen. Video-Thumbnail/Poster bis zum tatsächlichen Rendering des ersten Frames anzeigen und anschließend nahtlos freigeben. First-Frame-Status für jeden Quell-/Engine-Wechsel zurücksetzen und ältere asynchrone Signale anhand Generation/Source-ID ignorieren; bei fehlgeschlagener First-Frame-Benachrichtigung einen sichtbaren Fehler-/Fallbackzustand bereitstellen, keinen dauerhaft verdeckten Player. Fork-Video-Viewer, Cache und Hero-/Thumbnail-Logik erhalten.
- **Daten / Abhängigkeiten:** `BooruPlayer`-fähige First-Frame-Signale für unterstützte Engines; nur Runtime-State, keine Migration.
- **Verifikation:** Langsame Initialisierung, Cache/Stream, MPV/MediaKit/video_player/WebView, schnelle URL-Wechsel, First-Frame-/Player-Fehler, dispose und Reinitialize, Overlay/Transition.
- **Verbindliches Protokoll:** [P07](decisions.md#p07-video-thumbnail-bis-zum-ersten-gerenderten-frame-anzeigen).
- **Änderung in Upstream:** Video-Placeholder verschwindet erst, wenn Player tatsächlich einen Frame gerendert hat.
- **Fork / potenzieller Konflikt:** Fork hat Post-Viewer- und Video-Thumbnail-Anpassungen.
- **Ursprüngliche Fragestellung:** Welche Quelle für Placeholder und Fade-Transition nutzen?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Perceived-performance-Fix übernehmen.
- **Abnahme/Test:** langsamer Decoder, Wiederaufnahme aus Cache, Video-Player-Wechsel.
- **Upstream-Commits:** [`2003c0c1e`](https://github.com/khoadng/Boorusama/commit/2003c0c1eb2cf6b3ef0939b33adf1b575fcae8f9).
- **Betroffene Codepfade (Auswahl):** `lib/core/videos/player/src/widgets/video_player.dart`.

### P08 · WebView-Video aus Cache-Datei und Cleanup-Schutz

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟠 hoch.

- **Bestätigter Beschluss:** angepasst übernehmen, Video-Cache-Lifetime schützen. Upstreams WebView-Wiedergabe lokaler Cache-Dateien mit kleiner lokaler HTML-Seite, MIME-Erkennung aus `VideoSource`, eingeschränktem lokalen Datei-Zugriff und sicherer serieller Bereinigung alter temporärer WebView-Seiten übernehmen; den bisherigen fehleranfälligen Base64/10-MiB-Fallback vermeiden. Fork-`VideoCacheManager` bislang ohne garantierten Usage-Schutz für aktive Videodateien: während Player/WebView-Dateizugriffes Eviction, Expiration und explizites Cache-Leeren gegen diese Videodatei absichern (kurzlebige, pro Datei referenzierte Nutzung/Lease). Beim Video-/Engine-Wechsel, Error und Dispose freigeben; ggf. zur Löschung vorgemerkte Dateien anschließend bereinigen. Keine Image-Cache-Generations zurückbringen und kein dauerhaftes Leasing über den Wiedergabezeitraum hinaus. Bei beschädigter/fehlender Cache-Datei sauber auf Remote-Streaming zurückfallen, ohne Auth/Cookies an unberechtigte Datei-/Origin-Kontexte zu geben.
- **Daten / Abhängigkeiten:** Cache-Lifetime ist separate Video-Cache-Verwaltung (`packages/cache_manager/lib/src/video_cache_manager.dart`), nicht X04-Image-Cache. Lokale `CachedVideoSource` muss gültigen Pfad bekommen; temporäre HTML-Dateien werden verlässlich beim Schließen/Start bereinigt; kein Persistenzschema erforderlich.
- **Verifikation:** Kleine/große/unbekannt große gecachte Videos, WebView Android/iOS/macOS, parallele Player, Cache-Eviction und Clear während Playback, Expiration, Video-/Engine-/Source-Wechsel, lokale Seite und Datei-Race, Stale-Cleanup beim Start, Streaming-Fallback, File-Read-Grenzen.
- **Verbindliches Protokoll:** [P08](decisions.md#p08-webview-video-aus-cache-datei-und-cleanup-schutz).
- **Änderung in Upstream:** WebView spielt lokale Cache-Dateien; Cleanup löscht keine gerade verwendeten Cached Pages.
- **Fork / potenzieller Konflikt:** Fork hat geteilten Cache und separate Video-Cache-Verwaltung/Viewer-Gesten.
- **Ursprüngliche Fragestellung:** Wie werden Dateihandles, Lebenszeit und Eviction mit unserer Cache-Pipeline koordiniert?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Race-/Data-Loss-Fixes übernehmen, Cache-Eigentümer und Locking explizit integrieren.
- **Abnahme/Test:** Eviktion während Playback, WebView vs MPV, Wechsel Posts, große Videos.
- **Upstream-Commits:** [`f3d8acaa0`](https://github.com/khoadng/Boorusama/commit/f3d8acaa0a765b6d2957ddd36f68a1aa944fa328), [`0f71409de`](https://github.com/khoadng/Boorusama/commit/0f71409dea3775ae1dd033bcf7fc27bb008888a0).
- **Betroffene Codepfade (Auswahl):** `lib/core/videos/engines`, `lib/core/videos/cache`.

### P09 · Kurumi InteractiveViewer: Bild-Pan vs Page-Swipe

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟠 hoch.

- **Bestätigter Beschluss:** angepasst übernehmen, Fork-Gesten erhalten. Bei unzoomed Bild (Zoom nahe 1x) sollen horizontale/vertikale PageView-Swipes statt `InteractiveViewer`-Panning gewinnen; bei vergrößertem Bild soll Pan/Pinch funktionieren. Upstreams Zoom-abhängiges `panEnabled` und die `ScaleGestureRecognizer.panCausesAcceptance`-Arbitration soweit notwendig integrieren. Vendored Flutter-3.47.2-Widget/Recognizer nur übernehmen, wenn eine kleinere kompatible Lösung am gepinnten Flutter nicht robust ausreicht. Sämtliche Fork-Funktionen erhalten: Double-Tap-Classic/Fit-Cycle, Snap-Zoom-to-Fit, Bildgrenzen, Auto-Comic-Strip, Original-on-Zoom sowie `ZoomEdgePageGesture` mit 160-dp-Edge-Pull, Retry-/Load-More-/Page-Actions. Panning und Page-Swiping nicht gleichzeitig aktivieren oder Pointer-Events doppelt konsumieren.
- **Daten / Abhängigkeiten:** Keine Persistenz; A02-Kurumi-Migration und gepinnte Flutter-Version beachten, mögliche vendored Dateien nur gezielt und mit klarer Upgrade-Strategie.
- **Verifikation:** Schneller Flick bei 1x horizontal/vertikal auf Android-Slop, Pinch-Zoom, Pan bei >1x, Edge-Pull/160-dp-Schwelle, geändertes Zoom/Media-Representation während Gesture, Mouse/Touch/Stylus, Rotation, Double-Tap, Original-on-Zoom, Selection und Zoom-Hardwaretest.
- **Verbindliches Protokoll:** [P09](decisions.md#p09-kurumi-interactiveviewer-bild-pan-vs-page-swipe).
- **Änderung in Upstream:** Flutter 3.47.2 InteractiveViewer vendored; unzoomed Images sollen Page-Swipes nicht abfangen.
- **Fork / potenzieller Konflikt:** Fork hat eigenes Zoom-/Edge-Drag-/Swipe-Verhalten inklusive „Original on Zoom“.
- **Ursprüngliche Fragestellung:** Welche Geste gewinnt bei Zoom=1, Zoom>1, Edge-Drag, Swipe und Selection?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Nur kompatibles Gesture-Arbitration-Verhalten portieren, Tests unserer Viewer-Gesten priorisieren.
- **Abnahme/Test:** Pan/Swipe über Zoomstufen, Portrait/Landscape, Mouse/Touch.
- **Upstream-Commits:** [`62e36f7e5`](https://github.com/khoadng/Boorusama/commit/62e36f7e5c7d40a3b5daa383a7c67ca420cb1cd3), [`c6b25213c`](https://github.com/khoadng/Boorusama/commit/c6b25213c3478abedf5c82c41dd9dd92a93a1bbe).
- **Betroffene Codepfade (Auswahl):** `packages/kurumi/lib/src/components/interactive_viewer.dart`, `lib/core/posts/details_pageview`.
- **Bestätigter Merge-Konflikt in:** `packages/kurumi/lib/src/components/interactive_viewer.dart`.

### P10 · Volume Keys im Post Viewer korrekt konsumieren

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟡 niedrig–mittel.

- **Bestätigter Beschluss:** vollständig übernehmen (mit aktiviertem Viewer-Gate). Bei eingeschalteter `volumeKeyViewerNavigation`, tatsächlich sichtbarem und nicht expandiertem Post-Viewer, Lauter (+) zur Navigation zum nächsten Post und Leiser (-) zum vorherigen Post verwenden und alle zugehörigen Key-Down-/Repeat-/Up-Ereignisse als verarbeitet (`true`) zurückgeben, auch am ersten oder letzten Post. Bei ausgeschalteter Funktion, verborgenem Viewer und Expand-Mode die Keys unbehandelt (`false`) lassen, damit reguläre Systemlautstärke funktioniert. Navigation selbst nicht ungewollt bei Key-Up/Repeat mehrfach auslösen; bestehende `isKeyPressed`-Down-Gestenerkennung und eventuelle Android-/Hardware-Limits bewahren. Während dieses optionalen Modus gilt Post-Navigation auch bei Videoposts.
- **Daten / Abhängigkeiten:** Keine Persistenz-/Schemaänderung, vorhandene Setting/Global-Keyboard-Handler beibehalten.
- **Verifikation:** Key-Down/Repeat/Up, erster/letzter Post, Viewer sichtbar/verborgen, Setting an/aus, Expand-Mode, Video/Bild, Systemlautstärke außerhalb des Viewers, kein doppeltes Navigieren.
- **Verbindliches Protokoll:** [P10](decisions.md#p10-volume-keys-im-post-viewer-korrekt-konsumieren).
- **Änderung in Upstream:** Beim Post-Navigieren genutzte Lautstärketasten werden als verarbeitet markiert.
- **Fork / potenzieller Konflikt:** Fork hat eigene Viewer-Gesten und Volume-Key-Einstellung.
- **Ursprüngliche Fragestellung:** Soll Systemlautstärke nur beeinflusst werden, wenn Viewer-Navigation aktiv?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Nur im aktivierten Viewer-Modus konsumieren.
- **Abnahme/Test:** Lautstärke außerhalb Viewer, Android Volume bei Video.
- **Upstream-Commits:** [`de755c0d2`](https://github.com/khoadng/Boorusama/commit/de755c0d20570d4c9e2c6d4b718517514178af44).
- **Betroffene Codepfade (Auswahl):** `lib/core/posts/details/src/widgets/volume_key_page_navigator.dart`.

### P11 · Videosteuerung: Zeit-Overflow und Media-Play/Pause-Key

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟡 niedrig–mittel.

- **Bestätigter Beschluss:** übernehmen (Fork-Player berücksichtigen). Video-Zeitanzeigen nicht länger auf fixe 40 px beschränken (minimale Breite und sichere flexible Darstellung). Media-Play/Pause/Toggle-Hardwaretasten nur auf den aktuell sichtbaren/fokussierten Video-Post routen; bei Bild-Posts, Hidden Playern und Textfokus nicht unerwartet abspielen. Vorhandene Player-Engine- und Viewer-Shortcuts erhalten.
- **Daten / Abhängigkeiten:** Keine Persistenz. Keyboard-Shortcut-Routing bei U04/U05/U06 auf Konflikte prüfen.
- **Verifikation:** Lange Zeiten/schmale Screens, Text-Scaling, MediaPlay/MediaPause/MediaPlayPause, Bildpost vs. Videopost, Fokus/Seitenwechsel, unterschiedliche Engines.
- **Verbindliches Protokoll:** [P11](decisions.md#p11-videosteuerung-zeit-overflow-und-media-playpause-key).
- **Änderung in Upstream:** Zeit-Text darf wachsen; Play/Pause per Medien-Hardwaretaste.
- **Fork / potenzieller Konflikt:** Fork hat eigene Post-Detail-Toolbar und Player-Engines.
- **Ursprüngliche Fragestellung:** Hotkeys und Controls an unsere Controls binden?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Ja, sofern mit Focus-/Routing-System kompatibel.
- **Abnahme/Test:** Schmale Player, Keyboard/Remote, Player-Engine-Wechsel.
- **Upstream-Commits:** [`c65a81074`](https://github.com/khoadng/Boorusama/commit/c65a81074f123eed5efbe368a8a44985dd8340cf), [`72bafb43d`](https://github.com/khoadng/Boorusama/commit/72bafb43d3e5063749ce663277201b01ea644a54).
- **Betroffene Codepfade (Auswahl):** `lib/core/posts/details/src/widgets/video_controls.dart`, `lib/core/posts/details/src/widgets/post_details_controller.dart`.

### P12 · Hover Preview nur über Info-Badge öffnen; Long Press erhalten

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟠 hoch.

- **Bestätigter Beschluss:** angepasst übernehmen. Hover-Preview nicht über die gesamte Thumbnail-Fläche, sondern über ein gezieltes Info-Badge öffnen, das bei Pointer-Hover bzw. passend fokussierter Keyboard-Navigation sichtbar wird. Gesten-/Hit-Test-Fixes für Long-Press, Right-Click und Hold-and-Drag übernehmen, Selection vor Preview-Badge priorisieren und bei Tastatureingaben Preview sauber schließen. Badge-Positionierung mit noch offenem P01 (bis zu zwei Quick Actions) und Series-Gruppenkarten abstimmen; keine neue unruhige permanente Overlay-Reihe.
- **Daten / Abhängigkeiten:** Nur UI/Interaktion, keine neuen persistenten Felder. Bestehenden `tooltipDisplayMode` respektieren.
- **Verifikation:** Desktop Hover/Badeg-Tap, Touch Long-Press, Rechtsklick, Hold-and-Drag-Selection, Keyboard/Escape/Textinput, enge Grid-Kacheln, Series-Karte, disabled Tooltip.
- **Verbindliches Protokoll:** [P12](decisions.md#p12-hover-preview-nur-über-info-badge-öffnen-long-press-erhalten).
- **Änderung in Upstream:** Nicht mehr gesamte Thumbnail-Fläche als Hover-Preview; gezieltes Info-Badge; Hover schließt bei Keypress; Longpress/Rightclick öffnet Menü wieder.
- **Fork / potenzieller Konflikt:** Fork hat Kontextmenüs/Selection über Hold-and-Drag sowie eigene Grid-Karten.
- **Ursprüngliche Fragestellung:** Möchten wir ein Info-Badge oder bestehendes Hover? Wo liegt Badge bei zwei Quick Actions/Series-Karten?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Getrennte Designentscheidung nach P01 und Context-Menu-Review; sichere Longpress-Fixes übernehmen.
- **Abnahme/Test:** Mouse Hover, Touch Longpress, Drag Selection, Keyboard, Series Tile.
- **Upstream-Commits:** [`e04b3bfd1`](https://github.com/khoadng/Boorusama/commit/e04b3bfd186e8b5b88ab704189e23178ae26d098), [`5da94c1df`](https://github.com/khoadng/Boorusama/commit/5da94c1dfa6a39ef34c21c6ba1d171267ee06928), [`5feaa3dcf`](https://github.com/khoadng/Boorusama/commit/5feaa3dcf0a5069afab3f95594b3935fe08f7150).
- **Betroffene Codepfade (Auswahl):** `lib/core/posts/listing/src/widgets/post_preview.dart`, `lib/core/posts/listing/src/_internal/raw_post_grid.dart`.

### P13 · Post-/Tag-Kontextmenüs auf Kurumi migrieren

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟠 hoch.

- **Bestätigter Beschluss:** angepasst übernehmen (A02). Post-/Tag-Kontextmenüs über Kurumi vereinheitlichen und Keyboard/Right-Click/Long-Press/Back/Escape sowie konsistente Darstellung übernehmen. ALLE Fork-Menüaktionen, Favoriten-/Bookmarks-/Following-/Gruppenaktionen, Untermenüs, Kontext-/Selection-Priorität und bestehende Tap-through-/Dismiss-Fixes behalten. Upstreams große Migration nicht pauschal über die Fork-`KurumiContextMenuPageController`- und `CustomContextMenuOverlay`-Erweiterungen legen; dieselbe Menükomponente mit kompatiblen Funktionen verwenden.
- **Daten / Abhängigkeiten:** Keine persistente Migration, A02-Kurumi-/Menü-Migration koordinieren; Anchor-Dependency-Fix nur im kompatiblen Lockfile-Stand anwenden.
- **Verifikation:** Post/Tag/Grid/Selection, Long-Press, Right-Click, Untermenüs, ESC/Back, Keyboard-Rückfokus, outside click, RTL/kompakt/Tag-Cloud und Overlay-Schichtreihenfolge.
- **Verbindliches Protokoll:** [P13](decisions.md#p13-post-tag-kontextmenüs-auf-kurumi-migrieren).
- **Änderung in Upstream:** Ersetzt alte Context Menus durch Kurumi; bei Tag Cloud sichert eine Abhängigkeitsanpassung die Popup-Größe.
- **Fork / potenzieller Konflikt:** Fork hat `CustomContextMenuOverlay`, weitere Actions (Following, Bookmark Groups) und eigene Menu-Dismiss-Fixes.
- **Ursprüngliche Fragestellung:** Kurumi als einheitliche Menükomponente verwenden, aber alle Fork-Actions/Shortcuts erhalten?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Kurumi wo kompatibel übernehmen, Fork-Actions und Tap-through-Schutz als Pflicht.
- **Abnahme/Test:** Longpress/Rightclick, Tap outside, Undo, Compact, RTL, Selection.
- **Upstream-Commits:** [`8ca15fcff`](https://github.com/khoadng/Boorusama/commit/8ca15fcff2e461488bc4ced314700196d421deb5), [`1e480b775`](https://github.com/khoadng/Boorusama/commit/1e480b7751a359931c53057e86a42ff56a1c6672).
- **Betroffene Codepfade (Auswahl):** `lib/core/posts/post/src/context_menu.dart`, `lib/core/widgets/custom_context_menu_overlay.dart`, `packages/kurumi/lib/src/components/context_menu.dart`.
- **Bestätigter Merge-Konflikt in:** `packages/kurumi/lib/src/components/context_menu.dart`.

### P14 · Keyboard-Fokus auf Quick Favorite/Bookmark-Buttons

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟡 mittel.

- **Bestätigter Beschluss:** übernehmen, abgestimmt auf P01/A02. Sichtbare Quick Favorite-/Bookmark-Buttons und weitere Thumbnail-Actions mit klarer Semantik, fokussiertem Zustand und Enter/Space-Aktivierung versehen. Bei maximal zwei Aktionen eine logisch nachvollziehbare Reihenfolge und Pfeil-/Tab-Navigation anbieten, ohne Kachelöffnung, Grid-Selection, Scroll-/Hold-and-Drag-Gesten zu übernehmen oder unsichtbare Buttons fokussierbar zu machen.
- **Daten / Abhängigkeiten:** Kein Datenmodell/Schema. Abhängig vom noch offenen Layout P01 und A02-Focus-/Kurumi-Änderungen.
- **Verifikation:** Keyboard/TV Focus/Enter/Space/Arrow/Tab, Scroll mit Recycling, Selection, Hidden/Disabled Actions, kleine Kacheln und visuelle Focus-Indication.
- **Verbindliches Protokoll:** [P14](decisions.md#p14-keyboard-fokus-auf-quick-favoritebookmark-buttons).
- **Änderung in Upstream:** Kleine interaktive Overlays auf Thumbnail sind mit Keyboard erreichbar.
- **Fork / potenzieller Konflikt:** Fork verwendet eigene Thumbnail-Action und Post-Selection.
- **Ursprüngliche Fragestellung:** Fokusreihenfolge für Card plus bis zu zwei Quick Actions?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Buttons erreichbar, aber Keyboard-Bedienung darf Grid-Selection nicht behindern.
- **Abnahme/Test:** Tab/Arrow, Fokus nach Scroll, Favorite/Bookmark Toggle.
- **Upstream-Commits:** [`d1047aa89`](https://github.com/khoadng/Boorusama/commit/d1047aa890c64b3baa575e0ca16f50b4724e6826).
- **Betroffene Codepfade (Auswahl):** `lib/core/posts/listing`, `packages/kurumi/lib/src/components`.

## Suche, Bedienung, Desktop und TV

### U01 · Suche oberhalb Soft-Keyboard bedienbar

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟠 hoch.

- **Bestätigter Beschluss:** angepasst übernehmen. Upstream-Fixes für Suche bei eingeblendeter Soft-Keyboard übernehmen: Search-Overlay innerhalb tatsächlich verfügbarem Platz positionieren (`fitToAvailableSpace` oder gleichwertige adaptive Platzierung), `MediaQuery.viewInsets.bottom` bei Top-/Bottom-Search korrekt einbeziehen und Liste/Inputs scrollbar halten. Die noch geplante kompakte, einheitliche Fork-Suche mit termbezogenem Raw Editor, automatischer Suche und Tag-/Metatag-Vorschlägen darf nicht durch alte Upstream-UI ersetzt werden. Texteingabe, vorhandene Chips und Vorschlagsauswahl bleiben bei 320dp, Landscape, Rotation und großem Text sichtbar; nicht unnötig das Keyboard schließen.
- **Daten / Abhängigkeiten:** Gemeinsamer Search-UX-Umbau, B01–B05, U03; Profile-/Search-Session und A02-UI-Komponenten erhalten.
- **Verifikation:** Phone Small/Normal/Landscape; Top- und Bottom-Position; Keyboard offen, 1.5–2× Schrift, Rotation, Suggestion-Auswahl, termbezogener Raw Editor und sichtbare aktive Chips; Upstream Headless-Keyboard-Flow adaptieren.
- **Verbindliches Protokoll:** [U01](decisions.md#u01-suche-oberhalb-soft-keyboard-bedienbar).
- **Änderung in Upstream:** Layout und Overlay-Handling für Search mit eingeblendeter Bildschirmtastatur verbessert.
- **Fork / potenzieller Konflikt:** Fork baut bereits kompakte Search-Bar, Raw Editor, Tag-Vorschläge und ausgewählte Tags um.
- **Ursprüngliche Fragestellung:** Wie verhalten sich Suggestion-Liste und Raw Editor bei geringer Höhe?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Funktionales Keyboard-Fix in den endgültigen Fork-Suchfluss übertragen.
- **Abnahme/Test:** 320dp Breite, Tastatur offen, Textscaling 1.5–2, Scroll/Vorschläge.
- **Upstream-Commits:** [`a00d41f3a`](https://github.com/khoadng/Boorusama/commit/a00d41f3a7a1e81954e718ab1144183426a1ab89).
- **Betroffene Codepfade (Auswahl):** `lib/core/search/search/src/widgets/search_page_scaffold.dart`, `lib/core/search/search/src/widgets/booru_search_bar.dart`.
- **Bestätigter Merge-Konflikt in:** `lib/core/search/search/src/widgets/search_page_scaffold.dart`.

### U02 · Search History als Full-Height-Sheet + Tests

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟡 mittel.

- **Bestätigter Beschluss:** übernehmen. Search History auf Telefon als scrollkontrolliertes Bottom Sheet (`isScrollControlled: true`) mit sinnvoll nutzbarer Höhe zeigen; Liste scrollbar, Tastatur/Insets berücksichtigen und auf weitere UI-Navigation responsiv reagieren. Bestehende Filter-/History-/Pinned-Search-/Following- und Suchzustand-Wiederherstellung erhalten, keine eigene History-Datenmigration. Upstreams Flow-Tests adaptieren.
- **Daten / Abhängigkeiten:** Fork SearchHistory-Route und SearchProfileSession; U01/U03 sowie neuer Search-UX-Einstieg.
- **Verifikation:** Viele Historieneinträge, Suche/Filter, Auswahl übernimmt Query korrekt, Keyboard/Back/Escape, Route-Return, Sheet bei niedriger Höhe; keine doppelte Search-Action.
- **Verbindliches Protokoll:** [U02](decisions.md#u02-search-history-als-full-height-sheet-tests).
- **Änderung in Upstream:** Search-History-Sheet beansprucht nutzbare volle Höhe; Journey-Test für Historienfluss.
- **Fork / potenzieller Konflikt:** Fork hat zusätzliche Pinned Searches und Following, überarbeitet Suchoberfläche.
- **Ursprüngliche Fragestellung:** Sheet-Größe und Einstieg unter der neuen Search-Bar festlegen?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Nützliche Höhe übernehmen, passende Tests portieren.
- **Abnahme/Test:** Tastatur, Zurück, Suchbegriff übernehmen, Pinned Search.
- **Upstream-Commits:** [`e53cdf3b3`](https://github.com/khoadng/Boorusama/commit/e53cdf3b31560cd4607431381b316b8e29349b11), [`3726d75c7`](https://github.com/khoadng/Boorusama/commit/3726d75c7eb14ea170e06e497b09198f4a9c4c71).
- **Betroffene Codepfade (Auswahl):** `lib/core/search/histories`, `test/application/search_history_flow_test.dart`.

### U03 · Tag-Suggestions per Tastatur fokussieren und hervorheben

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟠 hoch.

- **Bestätigter Beschluss:** angepasst übernehmen. Vorschlagsliste als fokuserhaltende Kurumi-Listbox oder gleichwertigen gemeinsamen Mechanismus anbinden: Up/Down bewegt sichtbares Highlight, Enter wählt aktiven Vorschlag, Escape löscht zunächst nur den Highlight-Zustand, während der Textfokus im Suchfeld bleibt; danach greifen Search-/Layer-Back-Regeln. Das Listen-Highlight ist semantisch markiert und scrollt ins Sichtfeld. Keyboard-Navigation konsistent für Desktop, Hardware-Keyboard/TV und für Raw-Editor des einzelnen Suchbegriffs; keine doppelte Fokusmarkierung um Input/Bar, keine Tastenevents in verdeckte Screens durchlassen. Tag- und Metatag-Einträge des zukünftigen allgemeinen Search-Options-Interface unterstützen.
- **Daten / Abhängigkeiten:** B01, geplanter Suchumbau, U01, U04–U06, A02-Kurumi; kein zweiter Search-Controller/Legacy-Chip-Editor.
- **Verifikation:** Vorwärts/rückwärts/reversed Suggestions, Up/Down/Enter/Escape, Auswahlliste bei Filteränderung, Tab/Shift-Tab, Fokus bleibt im Feld, Raw-Query und Single-Term-Editor, mit/ohne Keyboard; Scroll-to-highlight; keine Tastaturaktion an verdeckter Seite.
- **Verbindliches Protokoll:** [U03](decisions.md#u03-tag-suggestions-per-tastatur-fokussieren-und-hervorheben).
- **Änderung in Upstream:** Suchbar zeichnet einen einzelnen Focus-Ring; Suggestions werden beim Tippen hervorgehoben; Tastaturevents erreichen nicht die verdeckte Seite; Desktop-Raw-Query-Tests.
- **Fork / potenzieller Konflikt:** Fork plant siteübergreifende Tag-/Metatag-Vorschläge und editierbare Einzel-Search-Chips.
- **Ursprüngliche Fragestellung:** Wird Navigation mit Pfeilen/Enter/Escape genauso auf Phone/Desktop angewendet?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Keyboard-UX übernehmen, Tag-Suggestion-Komponenten an unsere Suchabstraktion anpassen.
- **Abnahme/Test:** Typed suggestions, raw syntax, Enter/Suggestion-Auswahl, Fokuswechsel, Overlay.
- **Upstream-Commits:** [`f7174bab4`](https://github.com/khoadng/Boorusama/commit/f7174bab405360103c48659b1c5bb72cbcd2bd61), [`e1ad37e1e`](https://github.com/khoadng/Boorusama/commit/e1ad37e1eddbb12106930e2ec983536863b5511b), [`7f5693c84`](https://github.com/khoadng/Boorusama/commit/7f5693c847ea0a88acb1fd12ff05057e0a6e5bb5).
- **Betroffene Codepfade (Auswahl):** `lib/core/search/search`, `packages/kurumi/lib/src/components/search_bar.dart`.

### U04 · TV-Remote- und Tastaturnavigation auf gesamter App

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟠 mittel–hoch.

- **Bestätigter Beschluss:** angepasst übernehmen; TV Best-Effort. Gemeinsame directional Focus-Navigation (D-Pad/Pfeiltasten), sichtbare Focus-Rings erst bei Keyboard-/Remote-Bedienung, Scroll-to-focused-Item und vernünftige Navigation über FocusScopes/Drawer/Sidebar/Toolbar/Viewer/Dialoge übernehmen. Upstreams `KurumiDirectionalFocusAction`, Ring-/Focus-Utilities, Key-Handling und Test-Harness nur in Fork-kompatibler Form integrieren; Touch-/Mouse-Navigation ungestört lassen und keine unabsichtliche Aktivierung versteckter Controls. TV/Remote zunächst ausdrücklich **Best-Effort**, keine neue offiziell unterstützte TV-Plattform samt Release-/Support-Versprechen.
- **Daten / Abhängigkeiten:** A02, P01/P13/P14, U03/U05/U06 und bestehende Fork-Navigation/Panel-Auswahl.
- **Verifikation:** D-Pad+Enter+Back über Start/Browse/Profiles/Search/Settings/Viewer/Dialogs, Focus-Scope-Wechsel, Scroll-Reveal, nicht sichtbar/offstage, Input-Editing vs. Fokus, Touch/Mouse-Wechsel, Ring nur bei Keyboard; autom. Headless-Flows.
- **Verbindliches Protokoll:** [U04](decisions.md#u04-tv-remote-und-tastaturnavigation-auf-gesamter-app).
- **Änderung in Upstream:** Directional Focus, Focus Rings, Menüs/Dialoge, Layout Manager, Original-Image Viewer für TV-/Remote erreichbar; App-Flow-Tests.
- **Fork / potenzieller Konflikt:** Fork fokussiert Touch/Mobile und eigenes Pane-/Sidebar-Navigationsmodell.
- **Ursprüngliche Fragestellung:** TV als offiziell unterstützte Plattform oder Best-Effort? Wie aktivieren wir Focus Rings?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Navigation beibehalten als Accessibility-Gewinn, ohne Phone-Touch zu verschlechtern.
- **Abnahme/Test:** D-Pad/Remote, Mouse/Touch-Wechsel, Focus Scope, TV Back.
- **Upstream-Commits:** [`e80eb1210`](https://github.com/khoadng/Boorusama/commit/e80eb1210a2327dfae4eba4866a1e7cfe472dfd8), [`00feb4d99`](https://github.com/khoadng/Boorusama/commit/00feb4d9923b49a931b7b0a24a9ac6f262214cc0), [`1e3b00c3a`](https://github.com/khoadng/Boorusama/commit/1e3b00c3a8e9c9cc43b947bb42501c2e33b30bf0), [`41d0121ce`](https://github.com/khoadng/Boorusama/commit/41d0121cee07c3533042f86e0b256663a9f7134d), [`7895ce70e`](https://github.com/khoadng/Boorusama/commit/7895ce70e7b520ddd8cefe3ef640de3679ee4fde).
- **Betroffene Codepfade (Auswahl):** `packages/kurumi/lib/src/components/focus_ring.dart`, `lib/core/app.dart`.
- **Bestätigter Merge-Konflikt in:** `lib/core/app.dart`.

### U05 · Desktop Tab-Reihenfolge und Fokusgrenzen

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟡 mittel.

- **Bestätigter Beschluss:** angepasst übernehmen. Pane-bezogene Tab-/Shift+Tab-Reihenfolge und FocusTraversalGroup/FocusPane sinnvoll in bestehender Sidebar, Profile-Switcher, Settings-Suche, Suchergebnissen, Browse/Post-Viewer und Dialogen etablieren. Sichtbar-fokussierte Elemente gegenüber Offstage-/Scroll-Bereich priorisieren; bei Keyboard-only Interaktion Ring zeigen, nach Mouse/Touch ausblenden; beim Schließen von Dialog/Popover Fokus an den aufrufenden Control zurückgeben. Flache und verschachtelte Navigationsbereiche nicht als zufällige Focus-Scopes behandeln; aktuelle Fork-Settings-/Sidebar-Architektur erhalten.
- **Daten / Abhängigkeiten:** U04/U06, Fork Settings-Suche und responsive Settings-Panes (A04), P14.
- **Verifikation:** Tab/Shift+Tab und Directional Arrows über Pane-Grenzen, lange Settings-Listen, Explore/Viewer sichtbare Controls, Focus Return nach Dialog/Sheet, Dynamic Layout/Routing/Scroll und große Textskalierung.
- **Verbindliches Protokoll:** [U05](decisions.md#u05-desktop-tab-reihenfolge-und-fokusgrenzen).
- **Änderung in Upstream:** Tab bleibt in Pane, Focus Ring erst bei Keyboard, Explore/Post-Details nur sichtbare Ziele, Arrows folgen aktuellem Control, Mouse-Fokus aktualisiert, Textfield zeichnet eigenen Ring.
- **Fork / potenzieller Konflikt:** Fork besitzt eigens angepasste Navigation, Browse/Post Viewer und Sidebar.
- **Ursprüngliche Fragestellung:** Welche Fokus-Scopes sind logisch (Sidebar, Profile, Search, Posts, Dialoge)?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Fokusregeln adaptieren, damit UX über Tastatur konsistent wird.
- **Abnahme/Test:** Desktop Tab/Shift+Tab, Mouse Click, Touch, Dialog-Pop, Scroll, Large Text.
- **Upstream-Commits:** [`a555bbb3d`](https://github.com/khoadng/Boorusama/commit/a555bbb3db20d9b8c29c3c1b7d87c2b0d8546d20), [`e95a71f85`](https://github.com/khoadng/Boorusama/commit/e95a71f85d7982a797a89b0879a42e1c55d46253), [`5f57df699`](https://github.com/khoadng/Boorusama/commit/5f57df699e940fb8256aa74bdac46d2979246141), [`58254b441`](https://github.com/khoadng/Boorusama/commit/58254b441040ec4c6187018a46c4366511e3e7f0), [`84286ddc1`](https://github.com/khoadng/Boorusama/commit/84286ddc1e3da8e7cae71783c5e21641015635ae), [`d7041c4d4`](https://github.com/khoadng/Boorusama/commit/d7041c4d42b3470c45ab4ed29bbe1e3e73093aa8), [`f31f551be`](https://github.com/khoadng/Boorusama/commit/f31f551bedd31b2c75fcddf354e682b07bae5e69).
- **Betroffene Codepfade (Auswahl):** `packages/kurumi`, `lib/core/posts`, `lib/core/settings`.

### U06 · Escape-Handling, Menu Selection und Layer-Hierarchie

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟠 mittel–hoch.

- **Bestätigter Beschluss:** angepasst übernehmen. Mit einem Fork-kompatiblen `KurumiDismissible`/BackHandler oder gleichwertig eine einzige ordentliche Keyboard-Escape/Android-Back-Präzedenz für ineinanderliegende Layer aufbauen: zuerst aktives Submenü/Popup/Popover, dann Dialog/Sheet, dann Search-Editing-/Suggestion-State, anschließend aktive Selection, zuletzt Route/Screen; tatsächliche Router-/PopScope-/Modal-Grenzen (inklusive nicht dismissbarer oder Dirty-Form-State) respektieren. Nur eine Ebene pro Tastendruck schließen; Fokus bei Schließen auf Auslöser zurückgeben und Key-Events nicht an verdeckte Seiten durchreichen. Fork-Kontextmenüs, MultiSelection- und Tap-through-Schutz erhalten, mit P13-A02-Kurumi abstimmen.
- **Daten / Abhängigkeiten:** U03–U05, P13, bestehende Fork-Router und `CustomContextMenuOverlay`-/`KurumiContextMenuPageController`-Erweiterungen.
- **Verifikation:** Verschachteltes Submenü/Popover in Dialog/Sheet, Escape/Android Back, Selection+Search, non-dismissable Dialog, Routing mehrfacher Navigators, kein doppelt konsumiertes Escape, Focus-Return, kein Tap-through auf Post.
- **Verbindliches Protokoll:** [U06](decisions.md#u06-escape-handling-menu-selection-und-layer-hierarchie).
- **Änderung in Upstream:** Anchored Menus schließen mit Escape, fokussierte Menüzeile hervorgehoben; innerste offene Kurumi-Layer zuerst; Escape folgt Back.
- **Fork / potenzieller Konflikt:** Fork verwendet Custom-Kontextmenüs, neue Navigation und Multiselection.
- **Ursprüngliche Fragestellung:** Reihenfolge: Popup → Sheet → Search → Selection → Screen; wie verhält sich Android Back?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Einheitliche Layer-Prioritäten definieren, dann Back-/Escape-Semantik synchronisieren.
- **Abnahme/Test:** Verschachtelte Menüs, Keyboard, Popover, Dialoge, Auswahlscreen.
- **Upstream-Commits:** [`3ff8b054e`](https://github.com/khoadng/Boorusama/commit/3ff8b054e558c77fd94a0419b33526d7e6d9c829), [`b925a581b`](https://github.com/khoadng/Boorusama/commit/b925a581bd361ca710d27a3e95c1eb315f9be62f), [`2d6d9f6e6`](https://github.com/khoadng/Boorusama/commit/2d6d9f6e6dacf60a52f8d0b62e7d27b8318b707c), [`76a8485de`](https://github.com/khoadng/Boorusama/commit/76a8485de122438d3f70c74de5c69bd1c8ea8987).
- **Betroffene Codepfade (Auswahl):** `packages/kurumi/lib/src/components/popup_menu.dart`, `lib/core/router.dart`.
- **Bestätigter Merge-Konflikt in:** `packages/kurumi/lib/src/components/popup_menu.dart`.

### U07 · Favorite Tags auf großen Screens im Dialog statt Sheet

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** 🟡 niedrig–mittel.

- **Bestätigter Beschluss:** übernehmen (Fork-Labels bewahren). Favorite-Tag-Editor auf Phones wie bisher als Bottom Sheet mit Keyboard/Inset-Schutz und ab größerem Kurumi-Screen-Breakpoint als zentrierten Dialog mit ca. 520px Maximalbreite anzeigen. Inhalt unabhängig von Keyboardhöhe und erweiterten Optionen scrollbar machen, Add/Edit/Raw-Query und sämtliche vorhandenen Fork-Label-Optionen/Warnungen/Aktionen ohne Funktionsverlust bewahren. Konsistent mit Fork-Breakpoints und anderen Einstellungenmodals gestalten.
- **Daten / Abhängigkeiten:** Fork Favorite-Tag-Management und Label-Verwaltung, U01/U04/U06.
- **Verifikation:** Phone/Tablet/Desktop, Keyboard offen/zu, großer Text, wechselnde Advanced-Options und Label-Chips, fehlerhafte/duplizierte Tags, Submit/Cancel/Escape und State-Restoration.
- **Verbindliches Protokoll:** [U07](decisions.md#u07-favorite-tags-auf-großen-screens-im-dialog-statt-sheet).
- **Änderung in Upstream:** Editor öffnet sich auf breiten Screens als Dialog, auf Phones als Bottom Sheet.
- **Fork / potenzieller Konflikt:** Fork hat Favorite-Tag-Management schon erweitert und zusätzliche Label-Aktionen.
- **Ursprüngliche Fragestellung:** Welche Breakpoints/Modals passen zum Fork-Design?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Responsive Verhalten übernehmen, ohne bestehende Label-Funktionen zu ersetzen.
- **Abnahme/Test:** Wide/Mobile, Tastatur geöffnet, Dialog ohne Overflow.
- **Upstream-Commits:** [`20e750618`](https://github.com/khoadng/Boorusama/commit/20e750618847bbb0a84391cca0b2440667ab18e7).
- **Betroffene Codepfade (Auswahl):** `lib/core/tags/favorites/src/pages/edit_favorite_tag_sheet.dart`.

### U08 · Regressionstests und Flakiness-Fixes nachziehen

**Status:** **ENTSCHIEDEN am 2026-10-16**, Umsetzung ausstehend · **Risiko:** ⚪ niedrig.

- **Bestätigter Beschluss:** test-only, zusammen mit Feature-Übernahme. Upstreams Testabsichten (Info-Badge-Hover nach P12 und Bulk-Dry-Run-/Session-Status nach D02) übernehmen, jedoch an aktuelle Fork-Widgets, APIs und bestehende kontrollierte Clock-/Completion-Signale anpassen statt unkontrollierte feste Sleeps oder flakey Polling-Schleifen zu duplizieren. Keine eigenständige UI-/Produktlogik und keine neue Persistenz durch U08; Tests erst zusammen mit den betreffenden Migrationsänderungen aktualisieren.
- **Daten / Abhängigkeiten:** P12, D02, Fork-Regressionstests und Runner/Headless-Flows (A12).
- **Verifikation:** Hover öffnet Preview nur über Info-Badge, schließen via Keyboard/Maus/Selection; Bulk Dry Run/Resume/Status ohne wall-clock-race, idempotente Session-Lifecycle-Tests und kontrollierte Futures/Events.
- **Verbindliches Protokoll:** [U08](decisions.md#u08-regressionstests-und-flakiness-fixes-nachziehen).
- **Änderung in Upstream:** Aktualisiert Hover-Preview-Test und entfernt fragile Warte-/Timing-Annahme bei Bulk-Dry-Run.
- **Fork / potenzieller Konflikt:** Fork hat bereits eigene deterministische Testsuite und Runner-Fixes.
- **Ursprüngliche Fragestellung:** Betroffene Testabsichten an neue UI und unsere kontrollierten Clocks anpassen?
- **Frühere Arbeitshypothese (durch Beschluss ersetzt):** Teständerungen nur bei Übernahme der korrespondierenden Funktionen.
- **Abnahme/Test:** Post Preview UI und Bulk Dry Run.
- **Upstream-Commits:** [`71b41b8a0`](https://github.com/khoadng/Boorusama/commit/71b41b8a0f5574975f1cae673ac9cedde5b594ed).
- **Betroffene Codepfade (Auswahl):** `test/application`, `test/bulk_downloads`.

## Querschnitt: Schutz unserer Fork-Architektur

### X01 · Hive-Feldindex 15: echte Schema-Kollision bei Bookmarks

**Status:** **ENTSCHIEDEN am 2026-10-15**, Umsetzung ausstehend · **Risiko:** 🔴 kritisch. Siehe [verbindliches Entscheidungsprotokoll](decisions.md#x01--bookmark-hive-feldindex--ursprüngliche-site-post-id).

- **Änderung in Upstream:** Upstream führt `BookmarkHiveObject.sitePostId` an Hive-Feldindex **15** ein.
- **Fork / potenzieller Konflikt:** Fork nutzt Index **15** bereits für `snapshotSchemaVersion` und **16** für `postSnapshot`; hier darf kein unverändertes generiertes Upstream-Adapter-Schema übernommen werden.
- **Beschluss:** Fork-Indizes 15/16 unverändert lassen. Die Quell-ID nach Möglichkeit aus bereits persistierten Post-/Snapshot-Daten ableiten. Keine direkte Übernahme von Upstreams `sitePostId` auf Index 15.
- **Entschiedene Abhängigkeit X02:** `Post.sitePostId` als Getter, kein zusätzlicher Hive-Index; Original-ID aus vorhandenem Post-/Snapshot-Kontext ableiten.
- **Abnahme/Test:** Echte alte SQLite/Hive/Backup-Testfixtures, Upgrades, Crash-Safety und Restore.
- **Upstream-Commits:** [`216eb6e6d`](https://github.com/khoadng/Boorusama/commit/216eb6e6d43cef2581a110b66a8f1482d110e7b9).
- **Betroffene Codepfade (Auswahl):** `lib/core/bookmarks/src/data/hive/bookmark_hive_object.dart`, `lib/core/hive/hive_adapters.g.yaml`.
- **Bestätigter Merge-Konflikt in:** `lib/core/bookmarks/src/data/hive/bookmark_hive_object.dart`, `lib/core/hive/hive_adapters.g.yaml`.

### X02 · Post-Identity/Origin vs Upstream sitePostId

**Status:** **ENTSCHIEDEN am 2026-10-15**, Umsetzung ausstehend · **Risiko:** 🔴 kritisch.

- **Bestätigter Beschluss:** angepasst übernehmen. `Post.sitePostId` als gemeinsamen `String?`-Getter einführen. Für numerische Boorus die originale numerische ID als String, für Sankaku die ggf. alphanumerische Original-ID aus `SankakuPostData`, bei unbekannter Original-ID `null` statt künstlichem Fallback. `PostOrigin`, `BookmarkIdentity` und Snapshots nicht umbauen; keine neuen Hive-Felder.
- **Verifikation:** Download-`{id}`, JSON-Sidecars, Links, Bookmark-Speichern/Export und Backup/Restore; Sankaku mit numerischen/alphanumerischen/fehlenden IDs; zwei Sites mit gleicher Post-Zahl.
- **Verbindliches Protokoll:** [X02](decisions.md#x02--post-identityorigin-vs-upstream-sitepostid).
- **Änderung in Upstream:** Upstream erweitert `Post` mit quellseitiger `sitePostId` und exportiert sie.
- **Fork / potenzieller Konflikt:** Fork verwendet `PostOrigin`, `StoredPostSnapshot`, `BookmarkIdentity`, Profile-UUIDs und einen Unified-Post-Pipeline-Ansatz.
- **Ursprüngliche Fragestellung:** Wie soll die quellseitige ID in unsere persistente Identität eingebettet werden, ohne globale IDs zu verwechseln?
- **Abnahme/Test:** Zwei gleiche numerische IDs auf unterschiedlichen Sites, Cross-Site-Recovery, Import alte Version.
- **Upstream-Commits:** [`216eb6e6d`](https://github.com/khoadng/Boorusama/commit/216eb6e6d43cef2581a110b66a8f1482d110e7b9).
- **Betroffene Codepfade (Auswahl):** `lib/core/posts/post/src/types/post.dart`, `lib/core/posts/post/src/types/post_origin.dart`.
- **Bestätigter Merge-Konflikt in:** `lib/core/posts/post/src/types/post.dart`.

### X03 · Fork-Export/Import, Profile-UUIDs und Following erhalten

**Status:** **ENTSCHIEDEN am 2026-10-15**, Umsetzung ausstehend · **Risiko:** 🔴 kritisch.

- **Bestätigter Beschluss:** Fork-Architektur bewahren; kompatible Headless-Factory-/Picker-/Navigation-/Backup-Boundaries über A01/A12 adaptieren. Keine Änderung an UUIDs, Hive/Identity, Ordnern, Pinned Searches und Following. Kein zweiter Bookmark-Refresh-Listener; Upstream-Speicher-Fix für Favorite Tags erst mit separat offenem D08.
- **Verifikation:** Vollständiger Legacy-/aktueller Backup-Roundtrip, Profile-UUID, verschachtelte Ordner, Following/Pinned Searches, Bookmark-Selection/Undo, Cold-Start und Recovery.
- **Verbindliches Protokoll:** [X03](decisions.md#x03--fork-exportimport-profile-uuids-und-following-bewahren).
- **Änderung in Upstream:** Upstream verändert App-Initialisierung, Backup-Quellen und Bookmark-Provider neben neuen Tests.
- **Fork / potenzieller Konflikt:** Fork besitzt neu gestalteten Backup-/Import-Flow, UUID-Profile, verschachtelte Bookmark-/Pinned-Folder und Following Feeds.
- **Ursprüngliche Fragestellung:** Welche Merge-Auflösungen dürfen diese Fork-Features niemals ersetzen oder rückabwickeln?
- **Frühere Arbeitshypothese (ersetzt durch obigen Beschluss):** Alles Fork-spezifische als harte Invariante behandeln, Upstream-Änderungen nur kompatibel adaptieren.
- **Abnahme/Test:** Full Export/Import Roundtrip, Feed-Aktualisierung, Bookmark Folder/Undo, Profilwechsel.
- **Upstream-Commits:** [`a3278c5d2`](https://github.com/khoadng/Boorusama/commit/a3278c5d2ecc3672fea63c68fb21c81a1db2bb07), [`3f4ce2bd4`](https://github.com/khoadng/Boorusama/commit/3f4ce2bd4f0f94c116b2262fa9418809710278a8), [`f93bdf0dd`](https://github.com/khoadng/Boorusama/commit/f93bdf0dd42c5eb0e8165d9070310a2aebfa32c1).
- **Betroffene Codepfade (Auswahl):** `lib/core/backups/export_import`, `lib/core/search/subscriptions`, `lib/core/configs`, `lib/core/bookmarks`.

### X04 · Shared Post/Image Cache und Download-Lifecycle beibehalten

**Status:** **ENTSCHIEDEN am 2026-10-15**, Umsetzung ausstehend · **Risiko:** 🔴 kritisch.

- **Bestätigter Beschluss:** angepasst übernehmen / Cache gezielt vereinfachen. Den gemeinsamen persistenten Fork-Image-Cache mit URL-MD5-Hash, Origin-Isolation, LRU, Quotas, Journal, Checkpoints und Performance-Fixes behalten. Physische `.generation_`-Dateien und langfristige File-Leases entfernen; Cache-Dateiname = URL-Hash. Einzigartige temporäre Downloads erst nach erfolgreichem Schreiben sicher/atomar veröffentlichen; falls gültige Datei bereits da ist, konkurrierendes Ergebnis verwerfen. Ungültige Dateien entfernen und neu laden. Image-Sharing nutzt eine eigene Temp-Kopie im existierenden Betriebssystem-Cache-Unterordner `boorusama-share` (ggf. `share_plus`), bestehende Bereinigung alter Dateien (>24 h beim App-Start) wiederverwenden; keinen neuen Cleanup-Service erfinden. Video-Cache und Download-Observer/Lifecycle erhalten.
- **Verifikation:** Parallele Cache-Misses, partielle/fehlgeschlagene Downloads, Invalidierung, Cache-Clear während Anzeige/Share, Race mit Eviction, Restart/Index/LRU, Limits, Cross-Site-Isolation, Temp-Cleanup und A09.
- **Verbindliches Protokoll:** [X04](decisions.md#x04--shared-postimage-cache-und-download-lifecycle-beibehalten).
- **Änderung in Upstream:** Upstream erweitert Media-Host-, Download-, Video-/Cache-, Post-Refresh- und Image-Pfade.
- **Fork / potenzieller Konflikt:** Fork hat geteilten persistenten LRU-Cache, Checkpoint-Optimierungen, Image-Origin-Isolation und eigene Download-Observer.
- **Ursprüngliche Fragestellung:** Welche Komponente ist Eigentümer von Cache-Key, Quota, Lifetime und Deduplication nach dem Merge?
- **Abnahme/Test:** Cache Checkpoints, Eviction, Cross-Site Identität, Replay, Background Download.
- **Upstream-Commits:** [`1e6a6607d`](https://github.com/khoadng/Boorusama/commit/1e6a6607dc7750a5c1e94d44531f8251fface3c6), [`86a16a20e`](https://github.com/khoadng/Boorusama/commit/86a16a20ee1327740316005b7946b8264fa70a19), [`cb5f9fade`](https://github.com/khoadng/Boorusama/commit/cb5f9fade8ed5c7e26d3f0811ef17f7187f73723), [`2003c0c1e`](https://github.com/khoadng/Boorusama/commit/2003c0c1eb2cf6b3ef0939b33adf1b575fcae8f9), [`828ddbdb7`](https://github.com/khoadng/Boorusama/commit/828ddbdb75afd02fe14cf8182774a3ef67c9128f), [`f3d8acaa0`](https://github.com/khoadng/Boorusama/commit/f3d8acaa0a765b6d2957ddd36f68a1aa944fa328), [`0f71409de`](https://github.com/khoadng/Boorusama/commit/0f71409dea3775ae1dd033bcf7fc27bb008888a0).
- **Betroffene Codepfade (Auswahl):** `lib/core/images`, `lib/core/cache`, `lib/core/posts`, `lib/core/downloads`.

## Anhang A – Lückenlose Zuordnung der 150 Upstream-Commits

Jeder Commit ist hier in Upstream-Reihenfolge aufgeführt und auf mindestens einen Entscheidungsgegenstand abgebildet. Ein Commit-Link ist zur Codeprüfung gedacht; bei mehreren IDs ist die Änderung bereichsübergreifend. Wieder zurückgenommene Änderungen sind entsprechend gekennzeichnet.

| Nr. | SHA | Commit-Beschreibung | Katalogpunkt(e) |
|---:|---|---|---|
| 1 | [`480810b11`](https://github.com/khoadng/Boorusama/commit/480810b11a5a66b24be40bc8a80a2a56e681b90c) | feat: add more logging for ddos solver | A08 |
| 2 | [`1e6a6607d`](https://github.com/khoadng/Boorusama/commit/1e6a6607dc7750a5c1e94d44531f8251fface3c6) | feat(settings): show cache locations and expose Android caches in Files | A09, X04 |
| 3 | [`3bd433423`](https://github.com/khoadng/Boorusama/commit/3bd4334235a091c51e680c28ea852d3d07571a02) | feat(debug): add credential redaction and persistent sensitive log capture | A07 |
| 4 | [`669b8019f`](https://github.com/khoadng/Boorusama/commit/669b8019f80eaf8d0f40e268bbf8a29dc0808ddf) | fix: bump bg downloader version | D03 |
| 5 | [`0def24717`](https://github.com/khoadng/Boorusama/commit/0def247178cedd1a058c3695a09b3c159ec3577d) | feat(debug): add typed protection diagnostics | A08 |
| 6 | [`72702e711`](https://github.com/khoadng/Boorusama/commit/72702e7110892d046826b53a25a70c39c1e72d56) | fix: make libavif web aware | A18 |
| 7 | [`86a16a20e`](https://github.com/khoadng/Boorusama/commit/86a16a20ee1327740316005b7946b8264fa70a19) | feat(downloads): support tags and JSON metadata sidecars | D01, X04 |
| 8 | [`ebdfb05d9`](https://github.com/khoadng/Boorusama/commit/ebdfb05d9bec5be5c6fd6dd3e5460cea8ce1e1a1) | Revert "fix(downloads): finalize bulk activity deterministically" | D02 |
| 9 | [`c2d3b109e`](https://github.com/khoadng/Boorusama/commit/c2d3b109ef0e2124273858b17ed577e8bdaa1add) | fix: default to false for hide app preview | A06 |
| 10 | [`54b19cd4c`](https://github.com/khoadng/Boorusama/commit/54b19cd4cf77b3a75579a2b27aeccc1b1dc56ef5) | fix(downloads): preserve bulk completion notifications after session cleanup | D02 |
| 11 | [`2d4f8484b`](https://github.com/khoadng/Boorusama/commit/2d4f8484ba62db8e5c5386825934b1bcc30455cf) | fix(shimmie2): resolve media formats and restore favorite state | B06 |
| 12 | [`434a2e516`](https://github.com/khoadng/Boorusama/commit/434a2e516ecae2ce236d4c7592af62961e182a87) | fix(debug): capture full logs by default and make credential redaction optional | A07 |
| 13 | [`948af9448`](https://github.com/khoadng/Boorusama/commit/948af94483b7662d1de9a0fbfea7381019cd821a) | feat(debug): highlight log URLs and status codes with readable query parameters | A07 |
| 14 | [`d13fe53a3`](https://github.com/khoadng/Boorusama/commit/d13fe53a3b8cbbba481b4d2d436b124009941b8f) | feat: make log entry copiable | A07 |
| 15 | [`cb5f9fade`](https://github.com/khoadng/Boorusama/commit/cb5f9fade8ed5c7e26d3f0811ef17f7187f73723) | feat: add per-profile media host overrides | N02, X04 |
| 16 | [`afdff42e3`](https://github.com/khoadng/Boorusama/commit/afdff42e344a585439bef34893bc2cbaa8e706df) | fix(images): restore tap-to-retry for custom error widgets | P03 |
| 17 | [`70b523938`](https://github.com/khoadng/Boorusama/commit/70b5239384cc86fba7c479c7ce688076508575cf) | fix(retriable): honor Retry-After and configured retry policies | N01 |
| 18 | [`26ad35202`](https://github.com/khoadng/Boorusama/commit/26ad352026bb4187e399dfab422c76427aca8655) | feat: support two adaptive thumbnail quick actions per profile | P01 |
| 19 | [`216eb6e6d`](https://github.com/khoadng/Boorusama/commit/216eb6e6d43cef2581a110b66a8f1482d110e7b9) | fix: preserve site post IDs in exports and handle Sankaku metatag suggestions | D07, B01, X01, X02 |
| 20 | [`2569eaeeb`](https://github.com/khoadng/Boorusama/commit/2569eaeeb6ea01ea35386ffc8bab858dcbd1d75d) | feat: add Sankaku metatag highlighting and typed search suggestions | B01 |
| 21 | [`deca1064a`](https://github.com/khoadng/Boorusama/commit/deca1064aa68abcbbb1683408f305558bef08ee3) | fix: serialize rate-limit admission and support Retry-After cooldowns | N01 |
| 22 | [`c5b79488c`](https://github.com/khoadng/Boorusama/commit/c5b79488c8d90b624cb17e8452d3b17e099be88f) | feat: enable Anime-Pictures bulk downloads with request pacing | D05 |
| 23 | [`18216f412`](https://github.com/khoadng/Boorusama/commit/18216f4123586634f0756e7d5b20673638711766) | fix: explain Sankaku exclusion search restrictions | B02 |
| 24 | [`6ad672075`](https://github.com/khoadng/Boorusama/commit/6ad672075306e5621a4dde519ad124da0b19f8cb) | fix: normalize Sankaku single-date searches to day ranges | B02 |
| 25 | [`de755c0d2`](https://github.com/khoadng/Boorusama/commit/de755c0d20570d4c9e2c6d4b718517514178af44) | fix: consume volume keys used for viewer navigation | P10 |
| 26 | [`bdec763aa`](https://github.com/khoadng/Boorusama/commit/bdec763aa3e7d36d774b2f64b7963f79329f9bdd) | l10n: translations update from Hosted Weblate (#693) | A11 |
| 27 | [`0adc367df`](https://github.com/khoadng/Boorusama/commit/0adc367df3c9a3862e9663049e1af0d90bf60d21) | docs: update changelog | A16 |
| 28 | [`08088842c`](https://github.com/khoadng/Boorusama/commit/08088842c880bd124715e3d76b73c24945d8ea9a) | ci: update release builds to Flutter 3.44.6 | A14 |
| 29 | [`9ba59d05b`](https://github.com/khoadng/Boorusama/commit/9ba59d05b80c07b03e7e8696ee4c4ed8d068f14b) | fix(l10n): remove unsued keys | A11 |
| 30 | [`0ed1a49df`](https://github.com/khoadng/Boorusama/commit/0ed1a49df6e07787e89366ca931dd2f7b3504eef) | fix: keep widget tree stable | A03 |
| 31 | [`2003c0c1e`](https://github.com/khoadng/Boorusama/commit/2003c0c1eb2cf6b3ef0939b33adf1b575fcae8f9) | fix: keep video thumbnail visible until the first frame renders | P07, X04 |
| 32 | [`dbfe54fc4`](https://github.com/khoadng/Boorusama/commit/dbfe54fc432738bcf59ee9179a9089f629d620bf) | ci: install native build tools for release builds | A14 |
| 33 | [`430747c1a`](https://github.com/khoadng/Boorusama/commit/430747c1af0153672863213a03f25c082a29e204) | ci: enable Git long paths for Windows dependencies | A14 |
| 34 | [`402c4eb67`](https://github.com/khoadng/Boorusama/commit/402c4eb67a1052ab1841592c4eeb5a6967de071c) | ci: support Windows-only runs with native build diagnostics | A14 |
| 35 | [`a9821d53e`](https://github.com/khoadng/Boorusama/commit/a9821d53eb413ea46374ab09b07668b4ebe766f5) | ci: use Visual Studio CMake for Windows native builds | A14 |
| 36 | [`914ee5fa5`](https://github.com/khoadng/Boorusama/commit/914ee5fa51d33eeaa69ba8dc8c6dde171fadad58) | ci: exclude Strawberry compiler tools from Windows builds | A14 |
| 37 | [`899aabf6a`](https://github.com/khoadng/Boorusama/commit/899aabf6a26c22e438750319b74ac463a4af19ee) | ci: expose installed NASM and preserve build tool paths | A14 |
| 38 | [`df4f705d8`](https://github.com/khoadng/Boorusama/commit/df4f705d810f2cdfc2f009c6d6082ab5fb61d2df) | fix: reuse stuff | A14 |
| 39 | [`408666ef5`](https://github.com/khoadng/Boorusama/commit/408666ef55f2b20f2e65d7eee21dcb01b0f018ca) | feat(settings): make app and booru settings searchable | A05 |
| 40 | [`a9c31322b`](https://github.com/khoadng/Boorusama/commit/a9c31322bd4d60761218bedfd317ef18f8b69359) | docs: update changelog | A16 |
| 41 | [`ffd7e47c5`](https://github.com/khoadng/Boorusama/commit/ffd7e47c5840a922b1c885d415a28984a6bf978a) | docs: update changelog | A16 |
| 42 | [`9f8ab7bca`](https://github.com/khoadng/Boorusama/commit/9f8ab7bcab67048be3bb865b98c47203d7b121b2) | chore: migrate to Flutter 3.47 | A02 |
| 43 | [`e7745aca8`](https://github.com/khoadng/Boorusama/commit/e7745aca83af95f38ac1d2e3f58fa23bf0b92234) | refactor(ui): migrate to standalone Material and Cupertino packages | A02 |
| 44 | [`6adb28be9`](https://github.com/khoadng/Boorusama/commit/6adb28be97b67181a1641df28d9b0c490e4e3f47) | refactor(ui): replace legacy UI dependencies with Kurumi components | A02 |
| 45 | [`d13da93a3`](https://github.com/khoadng/Boorusama/commit/d13da93a3a6e2a8d9299d5a0ef91dd00422aa303) | l10n: translated using Weblate (Portuguese (Brazil)) | A11 |
| 46 | [`a891266bb`](https://github.com/khoadng/Boorusama/commit/a891266bb668caa65f846db9ee40f9b35c840c9e) | l10n: translated using Weblate (Indonesian) | A11 |
| 47 | [`a3278c5d2`](https://github.com/khoadng/Boorusama/commit/a3278c5d2ecc3672fea63c68fb21c81a1db2bb07) | refactor: make the app headless friendly | A01, X03 |
| 48 | [`cfb231254`](https://github.com/khoadng/Boorusama/commit/cfb231254634c8ef96873847c43f5983a5ea27ed) | style: format all | A17 |
| 49 | [`ab78dc3e3`](https://github.com/khoadng/Boorusama/commit/ab78dc3e338514bd39f2ce678ade2abd2c82b133) | chore: cleanup | A17 |
| 50 | [`685db1ad5`](https://github.com/khoadng/Boorusama/commit/685db1ad56712e00d4ef8dfe438114948ba6e86e) | Revert "feat(settings): make app and booru settings searchable" | A05 |
| 51 | [`1f2e90060`](https://github.com/khoadng/Boorusama/commit/1f2e90060765be4369a689522c463f740f254197) | feat(settings): add responsive navigation | A04 |
| 52 | [`ee38cd592`](https://github.com/khoadng/Boorusama/commit/ee38cd592b4d6960d49025a52de433930b7441e7) | style: format all | A17 |
| 53 | [`bc63321ec`](https://github.com/khoadng/Boorusama/commit/bc63321ec125c5d54da165c9977580cdea46448f) | docs: update changelog | A16 |
| 54 | [`d3f3a62fa`](https://github.com/khoadng/Boorusama/commit/d3f3a62fa40fc7eadd2a63cd32e145f9cd3d5acd) | build(nix): add NixOS package and development environment | A13 |
| 55 | [`d1e7c99b4`](https://github.com/khoadng/Boorusama/commit/d1e7c99b4895404548a426274e076b3710d84f79) | fix(build): retry Flutter after native asset changes | A14 |
| 56 | [`87a4fae44`](https://github.com/khoadng/Boorusama/commit/87a4fae4463529474a9d161fdd45fa2047831986) | fix(build): retry repeated Flutter native asset changes | A14 |
| 57 | [`038d1287c`](https://github.com/khoadng/Boorusama/commit/038d1287c04a260faea85e360c98f4baffb8fd97) | fix(nix): handle immutable native asset inputs | A13 |
| 58 | [`e16ecd2c3`](https://github.com/khoadng/Boorusama/commit/e16ecd2c35236880eea7be4c27e3f957c6609143) | fix(nix): bundle fonts for Linux runtime | A13 |
| 59 | [`2d621b683`](https://github.com/khoadng/Boorusama/commit/2d621b68335a62337075b53289f1f986f0631fcf) | fix(nix): shorten embedded revision on ARM64 | A13 |
| 60 | [`047a5a09e`](https://github.com/khoadng/Boorusama/commit/047a5a09e5e2ff397f23eee21f1cd54672cc80a2) | fix(nix): preload bundled fonts before startup | A13 |
| 61 | [`50980b8da`](https://github.com/khoadng/Boorusama/commit/50980b8da1368aa39a44051c78dee12dd4dff2ce) | feat(zerochan): reenable bulk download | D06 |
| 62 | [`c184be942`](https://github.com/khoadng/Boorusama/commit/c184be94249a3768e4f4d672517230c62acfb7ae) | fix(build): discard failed Flutter platform output | A14 |
| 63 | [`db33523ff`](https://github.com/khoadng/Boorusama/commit/db33523ff960712518c3c3482e33f8d9b33048b6) | Revert "fix(build): discard failed Flutter platform output" | A14 |
| 64 | [`4c6138377`](https://github.com/khoadng/Boorusama/commit/4c6138377f9d5357b986584b8aee75d0b8d5dd66) | fix(platform): handle unsupported WebView features | A10 |
| 65 | [`02a28fe7d`](https://github.com/khoadng/Boorusama/commit/02a28fe7d7e94c12a94c926442681cc8d569e2d5) | Merge pull request #701 from weblate/weblate-boorusama-app | A11 |
| 66 | [`c22d22e0d`](https://github.com/khoadng/Boorusama/commit/c22d22e0dfe9f3f521a3e495fafa69ba00d07364) | ci: add all-platform smoke run option | A14 |
| 67 | [`f94243dcc`](https://github.com/khoadng/Boorusama/commit/f94243dccad0eace17d674df43934424ca591f39) | ci: centralize release toolchain setup | A14 |
| 68 | [`d0fde834a`](https://github.com/khoadng/Boorusama/commit/d0fde834a413658bb50db150636c481c88a88222) | fix(sankaku): preserve all post tag categories | B03 |
| 69 | [`b55d1adde`](https://github.com/khoadng/Boorusama/commit/b55d1addecaf59fb36cd72d5f5e6e5b75b629f84) | fix(android): enable non-final resource ids | A14 |
| 70 | [`396ae059e`](https://github.com/khoadng/Boorusama/commit/396ae059e9e5576aa0172df7fabf823963c03e92) | fix(sankaku): deduplicate post tags | B03 |
| 71 | [`829ec71fb`](https://github.com/khoadng/Boorusama/commit/829ec71fbaedbc60fff7d98fe1b40c494a130ebe) | fix(sankaku): preserve client options when applying API headers | B04 |
| 72 | [`6ad691a6d`](https://github.com/khoadng/Boorusama/commit/6ad691a6de23d8a44c46d02bf3640997dbb618f4) | fix(sankaku): reject invalid authentication responses | B04 |
| 73 | [`5b495f1ad`](https://github.com/khoadng/Boorusama/commit/5b495f1adec13643ee83307bb2b68eb0272766b2) | fix(sankaku): clarify search tag limit errors | B05 |
| 74 | [`6762d00f2`](https://github.com/khoadng/Boorusama/commit/6762d00f2e4ac6efc99bf969bd15a335f6767437) | fix(sankaku): recover from expired authentication | B04 |
| 75 | [`f459e9922`](https://github.com/khoadng/Boorusama/commit/f459e99220e4ac5b449c033d1d60a0b672ea2b58) | feat(gelv2): add comment voting and cursor pagination | B07 |
| 76 | [`43619dd49`](https://github.com/khoadng/Boorusama/commit/43619dd495d5cb79425845521f0a0e0de030670d) | feat(gelv2): add comment sorting | B08 |
| 77 | [`58e4a0607`](https://github.com/khoadng/Boorusama/commit/58e4a06075faa8c07d8129dfdfa19156a4981a50) | fix: remove tap to retry implicit behavior | P03 |
| 78 | [`8d8ca771b`](https://github.com/khoadng/Boorusama/commit/8d8ca771b393d18f31e21e21881f22f142179397) | feat: add webview support for window | A10 |
| 79 | [`828ddbdb7`](https://github.com/khoadng/Boorusama/commit/828ddbdb75afd02fe14cf8182774a3ef67c9128f) | fix(posts): queue refresh requested during in-flight fetch | P04, X04 |
| 80 | [`485a728c9`](https://github.com/khoadng/Boorusama/commit/485a728c9802680b480ee949123624d6101cb463) | fix(kurumi): prevent side menu title overflow | A03 |
| 81 | [`bd2e22c22`](https://github.com/khoadng/Boorusama/commit/bd2e22c221bcfb1a8c8c0675afbab6763a3102c9) | refactor(download-manager): add injectable task client | D04 |
| 82 | [`90657ee4e`](https://github.com/khoadng/Boorusama/commit/90657ee4ed73f9a4bf7f2277ed1750e2f8b5d4ff) | fix(download-manager): copy task list before updating | D04 |
| 83 | [`3f4ce2bd4`](https://github.com/khoadng/Boorusama/commit/3f4ce2bd4f0f94c116b2262fa9418809710278a8) | fix(bookmarks): refresh library after bookmark changes | P05, X03 |
| 84 | [`c22d12fd6`](https://github.com/khoadng/Boorusama/commit/c22d12fd678db968af1356a21a3957ae3f3eda35) | test: add application flow suites | A12 |
| 85 | [`e4d645630`](https://github.com/khoadng/Boorusama/commit/e4d6456309c93f050b3a5d311ea4e2a60e0a7663) | fix(posts): respect gif autoplay setting at all image qualities | P06 |
| 86 | [`7880a020f`](https://github.com/khoadng/Boorusama/commit/7880a020fc7ba968351ee5256d3685c347d4eca0) | fix(nozomi): get tag counts from index sizes instead of search buckets | B09 |
| 87 | [`5a4498f78`](https://github.com/khoadng/Boorusama/commit/5a4498f78dbce67aa43c0d3d01c4fc8d31784a23) | fix(nozomi): request identity encoding for index range requests | B09 |
| 88 | [`86a7ee6bb`](https://github.com/khoadng/Boorusama/commit/86a7ee6bbee7a730f9b8931c01919191bd2ad0c3) | fix(http): enable larger HTTP/2 windows and gzip | N06 |
| 89 | [`62e36f7e5`](https://github.com/khoadng/Boorusama/commit/62e36f7e5c7d40a3b5daa383a7c67ca420cb1cd3) | chore(kurumi): vendor flutter interactive viewer 3.47.2 | P09 |
| 90 | [`c6b25213c`](https://github.com/khoadng/Boorusama/commit/c6b25213c3478abedf5c82c41dd9dd92a93a1bbe) | fix(kurumi): let page swipes win over unzoomed image pans | P09 |
| 91 | [`f3d8acaa0`](https://github.com/khoadng/Boorusama/commit/f3d8acaa0a765b6d2957ddd36f68a1aa944fa328) | fix(videos): play cached videos from file in webview | P08, X04 |
| 92 | [`889592e57`](https://github.com/khoadng/Boorusama/commit/889592e57f5f22962158c2d9123f1db05f836260) | fix(i18n): preserve full locale when switching languages | A11 |
| 93 | [`94aa56361`](https://github.com/khoadng/Boorusama/commit/94aa56361ad31a902e7382396e958d27244cda35) | fix(ddos): avoid replaying state-changing requests in challenge | N03 |
| 94 | [`99ee264db`](https://github.com/khoadng/Boorusama/commit/99ee264dbc2f9649d94b8757575e82b885623e0d) | fix(ddos): stop reopening challenges that leave the client blocked | N04 |
| 95 | [`e79abb5c0`](https://github.com/khoadng/Boorusama/commit/e79abb5c093aa7e1090653f2adf1b3e68b392328) | l10n: translations update from Hosted Weblate (#705) | A11 |
| 96 | [`72c27ed64`](https://github.com/khoadng/Boorusama/commit/72c27ed64b10290bd5e1877a5fbe342572a3948d) | fix(settings): polish responsive layout and navigation | A04 |
| 97 | [`e80eb1210`](https://github.com/khoadng/Boorusama/commit/e80eb1210a2327dfae4eba4866a1e7cfe472dfd8) | feat(tv): support remote and keyboard navigation | U04 |
| 98 | [`a00d41f3a`](https://github.com/khoadng/Boorusama/commit/a00d41f3a7a1e81954e718ab1144183426a1ab89) | fix(search): keep search usable above the soft keyboard | U01 |
| 99 | [`e53cdf3b3`](https://github.com/khoadng/Boorusama/commit/e53cdf3b31560cd4607431381b316b8e29349b11) | fix(search): open search history as a full-height sheet | U02 |
| 100 | [`3726d75c7`](https://github.com/khoadng/Boorusama/commit/3726d75c7eb14ea170e06e497b09198f4a9c4c71) | test(search): cover search history journeys | U02 |
| 101 | [`bcef3b5c1`](https://github.com/khoadng/Boorusama/commit/bcef3b5c1cf620ff3d67bfaef9e6d623391c3442) | fix(ddos): detect restyled cloudflare challenge pages | N04 |
| 102 | [`372dca51c`](https://github.com/khoadng/Boorusama/commit/372dca51c760bb0d070c2d4b54c20c0407648b6c) | fix: remove the redudant spacing | A17 |
| 103 | [`00feb4d99`](https://github.com/khoadng/Boorusama/commit/00feb4d9923b49a931b7b0a24a9ac6f262214cc0) | fix(tv): make menus, dialogs and layout manager remote friendly | U04 |
| 104 | [`1e3b00c3a`](https://github.com/khoadng/Boorusama/commit/1e3b00c3a8e9c9cc43b947bb42501c2e33b30bf0) | fix(tv): hide focus ring after pointer input and drop duplicate grid ring | U04 |
| 105 | [`41d0121ce`](https://github.com/khoadng/Boorusama/commit/41d0121cee07c3533042f86e0b256663a9f7134d) | fix(tv): make original image viewer reachable by remote | U04 |
| 106 | [`7895ce70e`](https://github.com/khoadng/Boorusama/commit/7895ce70e7b520ddd8cefe3ef640de3679ee4fde) | test(tv): cover blacklist edit, comments, viewer, phone and typed suggestions | U04 |
| 107 | [`f93bdf0dd`](https://github.com/khoadng/Boorusama/commit/f93bdf0dd42c5eb0e8165d9070310a2aebfa32c1) | fix(backup): export favorite tags from storage before UI initialization | D08, X03 |
| 108 | [`0b4dcfcc4`](https://github.com/khoadng/Boorusama/commit/0b4dcfcc40d22cff1464b34506a6b836f06d7586) | fix(ddos): retry with the clearance cookie the server accepts | N05 |
| 109 | [`0ad2e6465`](https://github.com/khoadng/Boorusama/commit/0ad2e646591aceac0ab726aec1213289e42311ac) | fix(ddos): read webview cookies through a native channel | N05 |
| 110 | [`dc7b9cee9`](https://github.com/khoadng/Boorusama/commit/dc7b9cee911f28049333546c56379be8c51d955a) | fix(ddos): accept cleared pages that embed captcha widgets | N04 |
| 111 | [`f82a62885`](https://github.com/khoadng/Boorusama/commit/f82a6288563d73e8da1943b7fed499d16f3611d7) | fix(ddos): accept cleared challenges redirected to a subdomain | N04 |
| 112 | [`3c72c200e`](https://github.com/khoadng/Boorusama/commit/3c72c200e1ecbf241feb09d1a3c932957720c84a) | style(browser): drop duplicate override annotation | A17 |
| 113 | [`a555bbb3d`](https://github.com/khoadng/Boorusama/commit/a555bbb3db20d9b8c29c3c1b7d87c2b0d8546d20) | fix(focus): keep Tab order within each pane on desktop | U05 |
| 114 | [`8ca15fcff`](https://github.com/khoadng/Boorusama/commit/8ca15fcff2e461488bc4ced314700196d421deb5) | refactor(context-menu): replace legacy context menus with kurumi | P13 |
| 115 | [`b0a1d65d9`](https://github.com/khoadng/Boorusama/commit/b0a1d65d9e60131f010491f38877cfd5e5df7b60) | fix(ddos): judge cloudflare pages by structure and explain network blocks | N04 |
| 116 | [`5972548ec`](https://github.com/khoadng/Boorusama/commit/5972548ecd6e32622b8476776490251d61d6a099) | fix: update post endpoint | B10 |
| 117 | [`e95a71f85`](https://github.com/khoadng/Boorusama/commit/e95a71f85d7982a797a89b0879a42e1c55d46253) | fix: hide focus ring until the user presses a key | U05 |
| 118 | [`f7174bab4`](https://github.com/khoadng/Boorusama/commit/f7174bab405360103c48659b1c5bb72cbcd2bd61) | fix(search): draw a single focus ring around the whole search bar | U03 |
| 119 | [`3ff8b054e`](https://github.com/khoadng/Boorusama/commit/3ff8b054e558c77fd94a0419b33526d7e6d9c829) | fix(menu): close anchored menus on Escape | U06 |
| 120 | [`5f57df699`](https://github.com/khoadng/Boorusama/commit/5f57df699e940fb8256aa74bdac46d2979246141) | fix(explore): let keyboard reach explore posts and skip the hidden page | U05 |
| 121 | [`58254b441`](https://github.com/khoadng/Boorusama/commit/58254b441040ec4c6187018a46c4366511e3e7f0) | fix(post-details): move focus out of the page only to controls in view | U05 |
| 122 | [`c65a81074`](https://github.com/khoadng/Boorusama/commit/c65a81074f123eed5efbe368a8a44985dd8340cf) | fix(video): let the time text grow instead of overflowing | P11 |
| 123 | [`72bafb43d`](https://github.com/khoadng/Boorusama/commit/72bafb43d3e5063749ce663277201b01ea644a54) | feat(post-details): support media play/pause keys for videos | P11 |
| 124 | [`84286ddc1`](https://github.com/khoadng/Boorusama/commit/84286ddc1e3da8e7cae71783c5e21641015635ae) | fix(focus): keep Tab in view and arrows continuing from the current control | U05 |
| 125 | [`d7041c4d4`](https://github.com/khoadng/Boorusama/commit/d7041c4d42b3470c45ab4ed29bbe1e3e73093aa8) | fix(focus): focus the control under a mouse click | U05 |
| 126 | [`20e750618`](https://github.com/khoadng/Boorusama/commit/20e750618847bbb0a84391cca0b2440667ab18e7) | feat(favorite-tags): edit favorite tags in a dialog on wide screens | U07 |
| 127 | [`d1047aa89`](https://github.com/khoadng/Boorusama/commit/d1047aa890c64b3baa575e0ca16f50b4724e6826) | fix(posts): let keyboard reach the bookmark and favorite buttons on thumbnails | P14 |
| 128 | [`e04b3bfd1`](https://github.com/khoadng/Boorusama/commit/e04b3bfd186e8b5b88ab704189e23178ae26d098) | fix(posts): close the hover preview on key press | P12 |
| 129 | [`e1ad37e1e`](https://github.com/khoadng/Boorusama/commit/e1ad37e1eddbb12106930e2ec983536863b5511b) | test(search): cover confirming a raw query from the desktop search bar | U03 |
| 130 | [`f31f551be`](https://github.com/khoadng/Boorusama/commit/f31f551bedd31b2c75fcddf354e682b07bae5e69) | fix(focus): skip the focus ring on text fields that draw their own focus border | U05 |
| 131 | [`7f5693c84`](https://github.com/khoadng/Boorusama/commit/7f5693c847ea0a88acb1fd12ff05057e0a6e5bb5) | feat(search): highlight tag suggestions while typing and keep keys off covered pages | U03 |
| 132 | [`b925a581b`](https://github.com/khoadng/Boorusama/commit/b925a581bd361ca710d27a3e95c1eb315f9be62f) | feat(menu): highlight the focused menu row instead of drawing the focus ring | U06 |
| 133 | [`2d6d9f6e6`](https://github.com/khoadng/Boorusama/commit/2d6d9f6e6dacf60a52f8d0b62e7d27b8318b707c) | feat(kurumi): close the innermost open layer on Escape | U06 |
| 134 | [`76a8485de`](https://github.com/khoadng/Boorusama/commit/76a8485de122438d3f70c74de5c69bd1c8ea8987) | feat(keyboard): let Escape close what back closes | U06 |
| 135 | [`5da94c1df`](https://github.com/khoadng/Boorusama/commit/5da94c1dfa6a39ef34c21c6ba1d171267ee06928) | feat(posts): open the post preview from an info badge instead of the whole thumbnail | P12 |
| 136 | [`d79ef1fcc`](https://github.com/khoadng/Boorusama/commit/d79ef1fcc9f59b07933e76681b6c033e12327460) | fix(shimmie2): keep listings working when favorite status fails | B06 |
| 137 | [`8757eb295`](https://github.com/khoadng/Boorusama/commit/8757eb2953d41716bc7c8fb3a028b71fb3f03e2c) | fix(sankaku): show rejected logins as authentication errors | B04 |
| 138 | [`1d8c879f4`](https://github.com/khoadng/Boorusama/commit/1d8c879f406d54df86c25d334ace0ada98846886) | fix(configs): keep profiles with unknown thumbnail actions or invalid media hosts | P02 |
| 139 | [`0f71409de`](https://github.com/khoadng/Boorusama/commit/0f71409dea3775ae1dd033bcf7fc27bb008888a0) | fix(videos): stop cached video cleanup from deleting pages in use | P08, X04 |
| 140 | [`71b41b8a0`](https://github.com/khoadng/Boorusama/commit/71b41b8a0f5574975f1cae673ac9cedde5b594ed) | test: fix stale hover preview test and flaky dry run session wait | U08 |
| 141 | [`e44fff71c`](https://github.com/khoadng/Boorusama/commit/e44fff71cd79dc4c581f6b6072a85e999a89df37) | build: prepare for 4.6.0 | A16 |
| 142 | [`c69b3e824`](https://github.com/khoadng/Boorusama/commit/c69b3e824d4acc4d60922ce78e391594846ff2c0) | fix(kurumi): cancel the pending checkmark animation when deselecting | A03 |
| 143 | [`5feaa3dcf`](https://github.com/khoadng/Boorusama/commit/5feaa3dcf0a5069afab3f95594b3935fe08f7150) | fix(posts): let long press and right click reach the post menu again | P12 |
| 144 | [`1e480b775`](https://github.com/khoadng/Boorusama/commit/1e480b7751a359931c53057e86a42ff56a1c6672) | fix(tags): keep the tag cloud context menu at full size | P13 |
| 145 | [`953fee30b`](https://github.com/khoadng/Boorusama/commit/953fee30bd78245cc9113a1dfc41a7953a7b2c3a) | fix(changelogs): stop the what's new popup from returning on every launch | A16 |
| 146 | [`e6511bad5`](https://github.com/khoadng/Boorusama/commit/e6511bad5c6d44f9b574bb08e1eeef4ddaed4d23) | ci: sign github release apks with a permanent key | A15 |
| 147 | [`399a4da47`](https://github.com/khoadng/Boorusama/commit/399a4da47587906a73a316f18c089254b58156d5) | fix(ddos): answer with the browser page instead of flashing a challenge that never appeared | N04 |
| 148 | [`2a5818b57`](https://github.com/khoadng/Boorusama/commit/2a5818b570a58071959e9d877aa4d2a3c9c25a17) | docs: add 4.6.1 changelog | A16 |
| 149 | [`5a2a4e82e`](https://github.com/khoadng/Boorusama/commit/5a2a4e82e827785f0c296b600e44aae2247b90a4) | docs: keep the 4.6.0 notes for 4.6.1 | A16 |
| 150 | [`5b04bf6a1`](https://github.com/khoadng/Boorusama/commit/5b04bf6a164f028d41701299367d0dde74dde330) | build: prepare for 4.6.1 | A16 |

## Anhang B – 106 bestätigte Merge-Konfliktpfade

Direkt mit `git merge-tree --write-tree --name-only develop v4.6.1` aus dem Bundle ermittelt; enthält auch Mod/Delete- und Verzeichnisumbenennungs-Konflikte. Die Liste ist kein Ersatz für semantische Abnahme.

| Pfad | |
|---|---|
| `.fvmrc` | |
| `.github/workflows/github-release.yml` | |
| `CHANGELOG.md` | |
| `android/app/build.gradle.kts` | |
| `android/app/src/main/AndroidManifest.xml` | |
| `android/app/src/main/kotlin/com/degenk/boorusama/MainActivity.kt` | |
| `android/app/src/main/kotlin/com/timberpile/boorusama/CacheDocumentsChannel.kt` | |
| `android/app/src/main/kotlin/com/timberpile/boorusama/CacheDocumentsProvider.kt` | |
| `android/app/src/main/kotlin/com/timberpile/boorusama/WebViewCookieChannel.kt` | |
| `android/gradle.properties` | |
| `ios/Runner/AppDelegate.swift` | |
| `lib/boorus/danbooru/artists/artist/src/pages/artist_page.dart` | |
| `lib/boorus/danbooru/danbooru_builder.dart` | |
| `lib/boorus/danbooru/favgroups/details/src/favorite_group_details_page.dart` | |
| `lib/boorus/danbooru/pools/details/src/widgets/danbooru_infinite_post_id_list.dart` | |
| `lib/boorus/danbooru/posts/explores/src/pages/explore_most_viewed_page.dart` | |
| `lib/boorus/danbooru/posts/favorites/src/favorites_page.dart` | |
| `lib/boorus/danbooru/posts/listing/src/default_danbooru_image_grid_item.dart` | |
| `lib/boorus/danbooru/posts/listing/src/grid_thumbnail_url.dart` | |
| `lib/boorus/danbooru/posts/post/src/providers.dart` | |
| `lib/boorus/danbooru/posts/uploads/src/pages/danbooru_my_uploads_page.dart` | |
| `lib/boorus/e621/popular/widgets.dart` | |
| `lib/boorus/eshuushuu/users/widgets.dart` | |
| `lib/boorus/hydrus/posts/types.dart` | |
| `lib/boorus/sankaku/posts/parser.dart` | |
| `lib/boorus/sankaku/posts/types.dart` | |
| `lib/boorus/sankaku/sankaku_builder.dart` | |
| `lib/boorus/sankaku/sankaku_repository.dart` | |
| `lib/boorus/sankaku/tags/providers.dart` | |
| `lib/boorus/zerochan/client_provider.dart` | |
| `lib/boorus/zerochan/posts/parser.dart` | |
| `lib/boorus/zerochan/zerochan_repository.dart` | |
| `lib/core/app.dart` | |
| `lib/core/backups/auto/providers.dart` | |
| `lib/core/backups/auto/widgets.dart` | |
| `lib/core/backups/widgets/backup_restore_tile.dart` | |
| `lib/core/blacklists/src/data/providers.dart` | |
| `lib/core/bookmarks/src/data/bookmark_convert.dart` | |
| `lib/core/bookmarks/src/data/hive/bookmark_hive_object.dart` | |
| `lib/core/bookmarks/src/data/hive/repository.dart` | |
| `lib/core/bookmarks/src/data/providers.dart` | |
| `lib/core/bookmarks/src/pages/bookmark_page.dart` | |
| `lib/core/bookmarks/src/providers/bookmark_provider.dart` | |
| `lib/core/bookmarks/src/types/bookmark.dart` | |
| `lib/core/bookmarks/src/widgets/bookmark_scroll_view.dart` | |
| `lib/core/bookmarks/src/widgets/bookmark_search_bar.dart` | |
| `lib/core/bookmarks/types.dart` | |
| `lib/core/boorusama_app.dart` | |
| `lib/core/bulk_downloads/src/data/repo_io.dart` | |
| `lib/core/bulk_downloads/src/data/repo_web.dart` | |
| `lib/core/bulk_downloads/src/pages/bulk_download_completed_page.dart` | |
| `lib/core/bulk_downloads/src/pages/bulk_download_page.dart` | |
| `lib/core/bulk_downloads/src/pages/bulk_download_saved_task_page.dart` | |
| `lib/core/bulk_downloads/src/providers/bulk_download_notifier.dart` | |
| `lib/core/configs/auth/src/pages/cookie_access_webview_page.dart` | |
| `lib/core/configs/create/src/pages/add_booru_page.dart` | |
| `lib/core/debug/widgets.dart` | |
| `lib/core/developer_options/widgets.dart` | |
| `lib/core/hive/hive_adapters.g.dart` | |
| `lib/core/hive/hive_adapters.g.yaml` | |
| `lib/core/http/client/src/interceptors/dio_image_deduplicate_interceptor.dart` | |
| `lib/core/http/client/src/interceptors/dio_protection_interceptor.dart` | |
| `lib/core/http/client/src/interceptors/sliding_window_rate_limit_interceptor.dart` | |
| `lib/core/images/booru_image.dart` | |
| `lib/core/posts/details_pageview/src/post_details_page_view.dart` | |
| `lib/core/posts/details_parts/src/toolbars/bookmark_post_button.dart` | |
| `lib/core/posts/favorites/src/pages/favorite_page_scaffold.dart` | |
| `lib/core/posts/favorites/src/widgets/quick_favorite_button.dart` | |
| `lib/core/posts/listing/src/types/grid_thumbnail_url_generator_default.dart` | |
| `lib/core/posts/listing/src/widgets/default_image_grid_item.dart` | |
| `lib/core/posts/listing/src/widgets/default_image_quick_action_button.dart` | |
| `lib/core/posts/listing/src/widgets/post_grid_controller.dart` | |
| `lib/core/posts/post/src/types/post.dart` | |
| `lib/core/posts/shares/src/download_and_share.dart` | |
| `lib/core/search/histories/src/data/repo_io.dart` | |
| `lib/core/search/histories/src/data/repo_web.dart` | |
| `lib/core/search/search/src/widgets/search_page_scaffold.dart` | |
| `lib/core/settings/src/pages/appearance/appearance_page.dart` | |
| `lib/core/settings/src/pages/data_and_storage_page.dart` | |
| `lib/core/settings/src/pages/language_page.dart` | |
| `lib/core/settings/src/pages/settings_page.dart` | |
| `lib/core/tags/favorites/src/providers/providers.dart` | |
| `lib/core/tags/show/src/pages/show_tag_list_page_scaffold.dart` | |
| `lib/core/tags/tag/src/widgets/general_tag_context_menu.dart` | |
| `lib/foundation/picker.dart` | |
| `macos/Runner.xcodeproj/project.pbxproj` | |
| `macos/Runner/MainFlutterWindow.swift` | |
| `packages/booru_clients/boorus.yaml` | |
| `packages/booru_clients/lib/src/gelbooru/gelbooru_client_favorites.dart` | |
| `packages/booru_clients/lib/src/gelbooru_v2/parsers/r34_parsers.dart` | |
| `packages/booru_clients/lib/src/sankaku/sankaku_client.dart` | |
| `packages/booru_clients/lib/src/shimmie2/shimmie2_client.dart` | |
| `packages/extended_image/analysis_options.yaml` | |
| `packages/extended_image/lib/src/extended_image.dart` | |
| `packages/i18n/translations/tr-TR.json` | |
| `packages/kurumi/lib/material.dart` | |
| `packages/kurumi/lib/src/components/context_menu.dart` | |
| `packages/kurumi/lib/src/components/interactive_viewer.dart` | |
| `packages/kurumi/lib/src/components/popup_menu.dart` | |
| `packages/kurumi/test/context_menu_test.dart` | |
| `packages/kurumi/test/interactive_viewer_test.dart` | |
| `pubspec.yaml` | |
| `test/bulk_downloads/common.dart` | |
| `test/bulk_downloads/providers/downloads/session_test.dart` | |
| `test/bulk_downloads/providers/downloads/skip_test.dart` | |
| `test/image_url_resolver_test.dart` | |

## Anhang C – Leitplanken für den geplanten Endstand

Vor Integration unbedingt bestätigen und in allen Konfliktauflösungen berücksichtigen:

- **Kein Verlust von Bookmarks** (inkl. neuer StoredPostSnapshots, Ordner, Profile, lokaler Suche und Undo).
- **Keine Regression unserer Profile UUIDs, Following/Pinned Searches und Suchoberfläche.**
- **Shared Cache/Origin-Trennung, Browser-Priorität und Android-Exportpipeline erhalten.**
- **Timberpile App-ID, Paketnamen, Signing-Key, Icons und Updates bleiben unverändert.**
- **Keine stille Veränderung bestehender Privacy-Einstellungen oder Weitergabe von Auth-Daten.**
- **Funktionaler Upstream-Fix zählt erst als übernommen, wenn sein Verhalten getestet ist.**
- **Vollständige Testsuite nach AGENTS.md** vor Integration; Targeted Tests pro Thema.

## Entscheidungsprotokoll – vollständig abgeschlossen

**68/68 Themen sind explizit beschlossen.** Das [autoritative Entscheidungsprotokoll](decisions.md) enthält Zielverhalten, Abhängigkeiten, Datenmigration und Abnahmetests. Die [kompakte Checkliste](boorusama-v4.6.1-checkliste.md) bildet denselben Stand ab. Die frühere pauschal „offene“ Anhang-Tabelle war eine unbefüllte Planungsvorlage und wird nicht mehr als zweite Statusquelle geführt.

---

Diese Datei ist eine **Planungs- und Entscheidungsgrundlage**, keine Aussage, dass alle Änderungen erfolgreich gemerged oder getestet wurden. Der experimentelle Merge-Patch aus der vorherigen Sitzung ist weiterhin unvalidiert.