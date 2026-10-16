# Upstream v4.6.1 – Entscheidungsprotokoll

**Autoritativer Entscheidungsstand:** **68 von 68 Themen entschieden** (2026-10-16); **0 offen**, Umsetzung nicht freigegeben. Dieses Dokument enthält ausschließlich Analyse und explizit bestätigte künftige Beschlüsse. Referenz: [Katalog](boorusama-v4.6.1-entscheidungskatalog.md) und [Checkliste](boorusama-v4.6.1-checkliste.md).

## Entscheidungsformat

Für jede abgeschlossene ID einen Eintrag in diesem Schema pflegen:

- **ID / Datum / Status:** `OFFEN`, `ENTSCHIEDEN`, `UMGESETZT`, `VERIFIZIERT`
- **Beschluss:** `vollständig übernehmen` / `angepasst übernehmen` / `Fork-Lösung behalten` / `nicht übernehmen`
- **Zielzustand:** beobachtbares Verhalten und zu bewahrende Fork-Eigenschaften
- **Daten/API:** notwendige Modell-, Schema- und Migrationsänderungen
- **Abhängigkeiten:** zu anderen IDs
- **Tests/Abnahme:** konkrete Regressionstests und Ergebnisse
- **Begründung/Quellen:** Upstream-Commit und lokale Codebefunde

Vor der expliziten Nutzerentscheidung bleibt jeder Eintrag `OFFEN`; ein technischer Vorschlag ist nicht verbindlich. Änderungen an einer Entscheidung werden mit Datum und Begründung nachvollziehbar ergänzt.

## X01 – Bookmark-Hive-Feldindex / ursprüngliche Site-Post-ID

**Status: ENTSCHIEDEN · 2026-10-15 · Umsetzung ausstehend.**

### Verifiziertes technisches Verhalten

- Upstream `Post.sitePostId` bezeichnet die **unveränderte Original-Post-ID der jeweiligen Website als String**, unabhängig von `Post.id` (numerische/interne ID).
- Relevant besonders für Sankaku: Die Original-ID kann alphanumerisch sein; der Dart-`int`-Wert ist dann nur eine erzeugte interne ID. Bei üblichen numerischen Sites entspricht `sitePostId` meist `post.id.toString()`.
- Upstream nutzt `sitePostId` für den Bookmark-Datensatz und dessen Export, den originalen Link beziehungsweise die ursprüngliche ID, Download-Dateinamen und optionale Metadata-Sidecars.
- Im Fork speichert `SankakuPostData` bereits die Sankaku-Original-ID; `StoredPostSnapshot` persistiert diese via `postSnapshot`. `PostOrigin` enthält die Herkunft, `BookmarkIdentity` einen standortbezogenen Post-Schlüssel.
- **Persistenzkollision:** Fork Hive-Index `15 = snapshotSchemaVersion` (`int`), Index `16 = postSnapshot` (Map); Upstream Index `15 = sitePostId` (`String?`). Ein direkt übernommener Adapter kann vorhandene Daten falsch interpretieren.

### Bestätigter Beschluss – Fork-Schema behalten; Upstream-Verhalten angepasst integrieren

**Entscheidung:** Die bestehenden Fork-Hive-Feldindizes **15 = `snapshotSchemaVersion`** und **16 = `postSnapshot`** bleiben unverändert. Den Upstream-Hive-Index 15 für `sitePostId` **nicht** übernehmen. Vorhandene Bookmark-Dateien und Backups müssen lesbar bleiben.

**Zielzustand:** Die ursprüngliche Site-Post-ID für Funktionen wie Links, Exporte und Dateinamen nach Möglichkeit aus bereits vorhandenen Post-Daten und Snapshots ableiten; keine redundante Persistenz ohne nachgewiesenen Bedarf einführen. Interne oder künstliche numerische IDs dürfen externe IDs nicht ersetzen.

**Umsetzungsvorgabe:** Nur wenn sich bei X02 ein konkreter persistenter Datenbedarf zeigt, einen **separaten** Vorschlag für einen neuen freien Hive-Feldindex und eine rückwärtskompatible Migration vorlegen; dafür liegt mit X01 noch **keine** Freigabe vor.

**Abhängigkeit:** X02 ist inzwischen ebenfalls entschieden: Getter `sitePostId` ohne zusätzlichen Hive-Index. X01s persistente Indizes 15/16 bleiben unverändert.

**Begründung:** Direkte Übernahme der Upstream-Indexbelegung würde das bestehende Fork-Schema mit einem inkompatiblen Datentyp kollidieren lassen. Bereits gespeicherte Original-IDs sollen wiederverwendet werden. Vom Nutzer am 2026-10-15 bestätigt.

### Verifikation

- Unveränderte Lese-/Schreibbarkeit existierender Fork-Hive-Dateien (Indizes 15/16).
- Nichtnumerische Sankaku-ID bleibt über Bookmark → Backup/Restore → Link/Export/Dateinamen exakt erhalten.
- Identische numerische Post-IDs auf unterschiedlichen Sites kollidieren nicht.
- Altes/upstream-kompatibles Backup und ungültige/fehlende Quell-ID sicher behandeln.

## X02 – Post-Identity/Origin vs Upstream sitePostId

**Status: ENTSCHIEDEN · 2026-10-15 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** `Post.sitePostId` als gemeinsamen `String?`-Getter einführen. Für numerische Boorus die originale numerische ID als String, für Sankaku die ggf. alphanumerische Original-ID aus `SankakuPostData`, bei unbekannter Original-ID `null` statt künstlichem Fallback. `PostOrigin`, `BookmarkIdentity` und Snapshots nicht umbauen; keine neuen Hive-Felder.

**Abnahme / Tests:** Download-`{id}`, JSON-Sidecars, Links, Bookmark-Speichern/Export und Backup/Restore; Sankaku mit numerischen/alphanumerischen/fehlenden IDs; zwei Sites mit gleicher Post-Zahl.

**Verifizierte Upstream-Verwendungen:** Download-`{id}`-Token, JSON-Sidecars, Bookmark-Speichern/Restore/Export und Sankaku-Links. Getter möglichst über kleine Core-seitige Original-ID-Abstraktion, ohne Core→Sankaku-Abhängigkeit und ohne zusätzlichen Hive-Index. X01s alte Hive-Felder 15/16 bleiben verbindlich. D07 bestätigt die Umstellung von Download-`{id}` auf die echte Site-Post-ID ohne zusätzlichen `{site_post_id}`-Token; Pixivs Standardvorlage `{illust_id}_p{page}.{extension}` bleibt.

## X04 – Shared Post/Image Cache und Download-Lifecycle beibehalten

**Status: ENTSCHIEDEN · 2026-10-15 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen / Cache gezielt vereinfachen.

**Zielzustand / technische Grenzen:** Den gemeinsamen persistenten Fork-Image-Cache mit URL-MD5-Hash, Origin-Isolation, LRU, Quotas, Journal, Checkpoints und Performance-Fixes behalten. Physische `.generation_`-Dateien und langfristige File-Leases entfernen; Cache-Dateiname = URL-Hash. Einzigartige temporäre Downloads erst nach erfolgreichem Schreiben sicher/atomar veröffentlichen; falls gültige Datei bereits da ist, konkurrierendes Ergebnis verwerfen. Ungültige Dateien entfernen und neu laden. Image-Sharing nutzt eine eigene Temp-Kopie im existierenden Betriebssystem-Cache-Unterordner `boorusama-share` (ggf. `share_plus`), bestehende Bereinigung alter Dateien (>24 h beim App-Start) wiederverwenden; keinen neuen Cleanup-Service erfinden. Video-Cache und Download-Observer/Lifecycle erhalten.

**Abnahme / Tests:** Parallele Cache-Misses, partielle/fehlgeschlagene Downloads, Invalidierung, Cache-Clear während Anzeige/Share, Race mit Eviction, Restart/Index/LRU, Limits, Cross-Site-Isolation, Temp-Cleanup und A09.

**X04 – vorhandene Share-Infrastruktur:** `ShareMediaPreparation` nutzt bereits einen `boorusama-share`-Ordner in der App-Temp-Root und `cleanupExpiredShareFiles` entfernt beim nächsten Start Dateien über 24 Stunden. Für das neue Modell nur Cache→Share-Kopie statt dauerhafter Cache-Datei-Lease; keine neue Hintergrundaufräumung oder genereller OS-Cache-Cleanup-Versprechen.

## A01 – App-Bootstrap, Runtime und Dependency Injection

**Status: ENTSCHIEDEN · 2026-10-15 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Upstream-Bootstrap/Runtime/Dependency Injection (`BoorusamaBootstrapHost`, Production-Bootstrap, Runtime, AppScope, External Effects) als führenden einzigen Startup-Pfad übernehmen; ALLE Fork-Dienste und Startjobs (Profile/UUID, ImportRecoveryGate, DataMutationCoordinator, SearchRefreshLifecycle, Following, Backups, Cache, GIF-/Share-Cleanup, native Kanäle) korrekt integrieren.

**Abnahme / Tests:** Cold start/Retry, alte Daten/Profile, Import/Restore, Following, Cache, Android/Desktop/Web; Headless-Flows A12.

## A02 – Kurumi / Material-Cupertino-Paketmigration

**Status: ENTSCHIEDEN · 2026-10-15 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Kurumi-/Material-Cupertino-Migration, KurumiLikeButton, LinearProgressIndicator, PulseIndicator, PageIndicator und Kurumi-Kontextmenüs übernehmen; kein zusätzliches Redesign. ALLE Fork-spezifischen Actions und Long-Press-/Hold-and-Drag-/Rechtsklick-Interaktionen erhalten. **Der Agent erstellt NACH Umsetzung nur eine kurze priorisierte manuelle UI-Testliste für den Nutzer. Die manuellen Checks führt der Nutzer selbst durch, NICHT der Agent.** Automatisierte Tests/Builds macht der Agent weiterhin.

**Abnahme / Tests:** Manuelle Liste mit konkreten betroffenen Screens: Post-Grid/Selection/Viewer/Toolbar, Bookmark-Groups, Pinned Searches/Following, Suche/Tag-Chips, Danbooru-Favorites, Share/GIF, Profile, Download-Actions, Desktop-Hover/Rechtsklick/Escape und mobile Menüs.

**A02 – manuelle Abnahme verbindlich:** Der Agent dokumentiert NACH dem UI-Merge die wichtigsten konkret vorhandenen Funktionen als kurze manuelle Checkliste für den Nutzer; **nicht vom Agent manuell ausführen lassen**. Automatisierte Unit-/Widget-/Build-Checks bleiben vorgeschrieben.

## A03 – Kurumi-Stabilität, Animationen und Overflow

**Status: ENTSCHIEDEN · 2026-10-15 · Umsetzung ausstehend.** **Beschlussart:** vollständig übernehmen, soweit regressionsfrei.

**Zielzustand / technische Grenzen:** Upstreams Kurumi-Fixes für Menüs, Fokus, Escape, Animationen, Overflow und Stabilität übernehmen; eigene Actions/Selection-Gesten nicht verlieren.

**Abnahme / Tests:** Widget-/Build-Prüfungen und Benutzer-UI-Abnahme gemäß A02.

## A04 – Responsives Settings-Navigationsmodell

**Status: ENTSCHIEDEN · 2026-10-15 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Upstreams responsive Settings-Navigation (neuer State, Unterseiten, Sidebar, kleine visuelle Änderungen) übernehmen. Vorhandene Fork-Settings Search, neue Kategorien/Einstellungen und **dynamische Titelgröße in der App-Top-Bar** unbedingt erhalten; kein abweichendes Fork-Redesign erzwingen.

**Abnahme / Tests:** Settings-Suche samt Zielen, mobile/desktop, Resize in Unterseite, Zurück-/Escape-Navigation, Titelgröße.

## A05 – Upstream Settings Search wurde hinzugefügt und wieder revertiert

**Status: ENTSCHIEDEN · 2026-10-15 · Umsetzung ausstehend.** **Beschlussart:** nicht übernehmen.

**Zielzustand / technische Grenzen:** Die kurzzeitig eingeführte und in Upstream v4.6.1 wieder entfernte Settings Search ignorieren. Ausschließlich die bestehende Fork-Settings-Search behalten. Grund für Revert ist nicht öffentlich verifiziert (Einführung `408666ef5`, Revert `685db1ad5`).

**Abnahme / Tests:** Settings-Suche nach A04 vollständig nutzbar.

## A06 – App-Lock: abweichende Privacy-Defaults

**Status: ENTSCHIEDEN · 2026-10-15 · Umsetzung ausstehend.** **Beschlussart:** vollständig übernehmen (Defaults).

**Zielzustand / technische Grenzen:** Upstream-Defaults übernehmen: App-Preview-Blur/Hide-App-Preview `false`, Lock-Timeout `30 Sekunden`. Bestehende vom Nutzer gespeicherte Werte beim Upgrade respektieren.

**Abnahme / Tests:** Erstinstallation/Upgrade, vorhandene Settings, PIN/Biometrie, Lock/Preview.

## A07 – Debug-Logging, Logspeicherung und Redaction

**Status: ENTSCHIEDEN · 2026-10-15 · Umsetzung ausstehend.** **Beschlussart:** 1:1 übernehmen.

**Zielzustand / technische Grenzen:** Upstreams persistentes Logging, Logansicht, Copy/Export, aktuelle Redaction-Defaults und übrige Konfiguration **1:1** integrieren. Keine vorgezogene Änderung an Privacy-/Redaction-Defaults; zukünftiges Fork-Logging-Work-Item baut darauf auf. Fork-Diagnosen erhalten.

**Abnahme / Tests:** Startup-/Crash-Logging, Logpersistenz, Kopieren/Export, Rotation und bestehende Diagnosefunktionen.

## A08 – Typisierte Cloudflare-/DDoS-Diagnostics

**Status: ENTSCHIEDEN · 2026-10-15 · Umsetzung ausstehend.** **Beschlussart:** vollständig übernehmen.

**Zielzustand / technische Grenzen:** Upstreams typisierte Cloudflare-/DDoS-Diagnostics mit ausführlichen Challenge-/Solver-Status- und Fehlerereignissen in A07-Logging integrieren; Rule34-Fork-Recovery erhalten.

**Abnahme / Tests:** Cloudflare Erfolg/Fehler, Loop-Vermeidung, lesbare Logs.

## A09 – Android-Cachepfade und DocumentsProvider

**Status: ENTSCHIEDEN · 2026-10-15 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Upstreams Cache-Locations-Settings und schreibgeschützten Android-DocumentsProvider übernehmen. Nur gültige, fertig gespeicherte Image-/Video-Cachedateien zeigen; keine Indizes, Partials, anderen privaten App-Dateien. An Fork-Package-ID/Native-Channels und **X04s normale Hash-Dateinamen** anpassen. Cache selbst nicht doppelt implementieren.

**Abnahme / Tests:** Dateimanager-Öffnen/Kopieren, read-only, MIME, Android-Versionen, Cache-Clear/Eviction, Private-Data-Grenze.

## A10 – Windows Embedded WebView, WebView-Plattformfähigkeit

**Status: ENTSCHIEDEN · 2026-10-15 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Windows-Embedded-WebView, Browser-Factories, WinHTTP und Unsupported-Platform-Fallbacks übernehmen; vorhandenes Fork-Cloudflare-/Browserverhalten bewahren.

**Abnahme / Tests:** Windows Challenge/Login, Android/iOS/macOS, Navigation, Unsupported-Fallback.

## A11 – Lokalisierung: Arabisch, Indonesisch, weitere Updates

**Status: ENTSCHIEDEN · 2026-10-15 · Umsetzung ausstehend.** **Beschlussart:** vollständig übernehmen, mit Fork-Ergänzungen.

**Zielzustand / technische Grenzen:** Upstream-Sprachen/Übersetzungen einschließlich Arabisch, Indonesisch, Language-Switch-Fixes integrieren, ohne die zusätzlich im Fork eingeführten Keys/Strings oder Fallbacks zu verlieren.

**Abnahme / Tests:** i18n-Generierung, JSON/Placeholders, RTL, Länder-Varianten, eigene Following-/Bookmark-/Settings-Texte.

## A12 – Headless Test-Harness und App-Flow-Tests

**Status: ENTSCHIEDEN · 2026-10-15 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Upstreams Headless-App-Test-Harness, Fake-Services und App-Flow-Tests mit A01-Runtime integrieren. Eigene Fork-Tests erhalten. Für visuelle/gestische A02-Abnahme schreibt Agent nur Nutzer-Checkliste; keine manuellen Geräte-Checks durch Agent.

**Abnahme / Tests:** Startup, Suche, Bookmarks, Downloads, Network Recovery, Fork-Flows; deterministische Tests.

## A13 – NixOS-Paket und Development Shell

**Status: ENTSCHIEDEN · 2026-10-15 · Umsetzung ausstehend.** **Beschlussart:** optional ohne Supportpflicht.

**Zielzustand / technische Grenzen:** NixOS-Flake, Entwicklungsshell und Paketierung nur soweit wartbar/kompatibel übernehmen; keine neue offizielle Release-Verpflichtung oder zusätzliche Wartungsinfrastruktur.

**Abnahme / Tests:** `nix flake check` soweit verfügbar; übrige Build-Systeme unverändert.

## A14 – Release CI, native Assets, SDK und Build CLI

**Status: ENTSCHIEDEN · 2026-10-15 · Umsetzung ausstehend.** **Beschlussart:** selektiv übernehmen.

**Zielzustand / technische Grenzen:** Nützliche Upstream-CI-/native Assets-/SDK-/Build-CLI-Fixes übernehmen. Fork-Flavors, split-APKs, bestehende CI/Release-Workflows und Flutter-3.47.2-Pinning erhalten; zurückgenommene Upstream-Build-Fixes nicht unkritisch erneut übernehmen.

**Abnahme / Tests:** Android-/Desktop-Builds, CLI, CI-Matrix, Release-Assets, Signierung gemäß A15.

## A15 – APK-Signing: permanenter Upstream-Key

**Status: ENTSCHIEDEN · 2026-10-15 · Umsetzung ausstehend.** **Beschlussart:** Upstream-Signing NICHT übernehmen.

**Zielzustand / technische Grenzen:** Fork-App-ID `com.timberpile.boorusama`, Flavors, bestehende Release-Signatur, Keystore, Update-Manifest und Upgrade-Kompatibilität unverändert lassen. Upstream-Key keinesfalls übernehmen; etwaige Signing-CI-Fixes nur passend zur vorhandenen Fork-Signatur.

**Abnahme / Tests:** Signer-Cert vor/nach Migration, installiertes Fork-APK upgraden, Paket-ID und Release/Manifest.

## A16 – Versionierung, Changelog und What’s-New-Popup

**Status: ENTSCHIEDEN · 2026-10-15 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Timberpile-Versionierung, eigene Release-History und Fork-Changelog beibehalten. Upstream-Fix für wiederkehrendes What's-New-Popup integrieren. Die neue verbindliche Versionsregel ist nachfolgend festgelegt; konkrete Buildnummer und Release-Tag vor der tatsächlichen Veröffentlichung verifizieren.

**Additional binding version policy (approved 2026-10-16):** Every fork release name begins with the **exact upstream `MAJOR.MINOR.PATCH` release version actually integrated**. Use `<upstream-version>-timberpile.<N>+<build-number>`. **Reset `N` to 1** when the upstream base version changes; increment `N` for subsequent fork releases based on the same upstream version. Do not publish a `.0` release. The `+build-number` / Android `versionCode` is **globally monotonically increasing across upstream upgrades** and must exceed all previously shipped fork Android version codes / relevant store values (never reset it). With current `4.5.0-timberpile.5+189`, the first release based on upstream v4.6.1 is **`4.6.1-timberpile.1+190` if no intervening build/release occurred**; otherwise compute the next available build number from real release/store history. Keep `pubspec.yaml`, top `CHANGELOG.md` heading, `v<version-name>` GitHub tag, GitHub updater manifest, `PackageInfo`, Android Gradle `flutter.versionCode` and flavor-specific APK codes consistent. The existing `.agents/skills/prepare-release/SKILL.md` default (always increment old Timberpile suffix and preserve old upstream base) **must be updated during implementation** along with relevant release/checker tests. Preserve own Timberpile release history and What's-New fix. Setting a policy does not authorize publishing a new release or changing `develop` now.

**Abnahme / Tests:** Popup einmalig, Upgrade von älterem Fork, Versionierung, Changelog und Update-Manifest.

## A17 – Formatierung, Reverts ohne Nettoeffekt, Kleinst-Cleanup

**Status: ENTSCHIEDEN · 2026-10-15 · Umsetzung ausstehend.** **Beschlussart:** Maintenance automatisch behandeln.

**Zielzustand / technische Grenzen:** Formatierungs-, Cleanup- und effektlose/revertierte Upstream-Änderungen ohne Produktentscheidung behandeln. Nur notwendige Lint-/Format-Fixes; unnötige Diffs und Wiederbelebung revertierter Features vermeiden.

**Abnahme / Tests:** Analyzer, Formatter, Diff, Build.

## A18 – AVIF-Decoder-Kompatibilität im Web

**Status: ENTSCHIEDEN · 2026-10-15 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** AVIF-Web-/Network-Decoder-Korrekturen übernehmen, bestehende AVIF-/Extended-Image-/Fork-Cache-Pipeline erhalten.

**Abnahme / Tests:** AVIF Web/Android, Thumbnail/Original, Cache-Hit/Miss und Fallback.

## N01 – HTTP-Retry-After, Rate-Limiter und Admission-Locks

**Status: ENTSCHIEDEN · 2026-10-15 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen und redundant vereinfachen.

**Zielzustand / technische Grenzen:** **Fork-`ApiRequestCoordinator` behalten:** zentrale Origin-Quotas, parallele In-Flight-Limits, interaktive Priorität, Following/Preload/Bulk-Pacing und 429-Cooldowns. Upstreams Sliding-Window-Interceptor NICHT als zweite Warteschicht einführen. **Übernehmen:** `packages/retriable`-Fixes für `Retry-After` (Datum/Sekunden, insb. 503), konfigurierbare retrybare Statuscodes, korrektes Gesamttimeout und Abbruch. Alten, nach Aufrufstellenprüfung unbenutzten Sliding-Window-Interceptor samt unnötigen Tests entfernen; doppelte Parser konsolidieren. Zusätzliche Upstream-Site-Pacing-Regeln für Zerochan, Anime-Pictures, E-Shuushuu in unsere `ApiQuotaPolicy` prüfen/überführen, bestehende belegte Fork-Limits nicht blind ersetzen.

**Abnahme / Tests:** 429/503 Retry-After und Zeitbudget, Parallelstart/Cancellation, keine Doppelwartezeiten, Danbooru/e621/Derpi/Zerochan, Anime-Pictures/E-Shuushuu, aktive vs. Following-/Bulk-Anfragen.

**N01 – kein doppelter Rate-Limiter:** Upstreams neue `SlidingWindowRateLimitInterceptor`-Cooldown-/Serialisierungslogik ist im Fork durch `ApiRequestCoordinator` funktional weitgehend abgedeckt. Eine zusätzliche Instanz an `defaultDioProvider`, Zerochan, Anime-Pictures oder E-Shuushuu würde dieselben Requests doppelt verzögern. Nur relevante `retriable`-Korrekturen und passende Policy-Regeln integrieren.

## N02 – Per-Profile Media-Host-Overrides

**Status: ENTSCHIEDEN · 2026-10-15 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Media-Host-Overrides pro Profil inkl. UI für Bilder/Videos/Downloads übernehmen. Header/Cookies/Auth NICHT ohne kontrollierte Origin-Grenzen zum Ersatzhost weitergeben; Source-/Profilidentität und Cache-Isolation bewahren.

**Abnahme / Tests:** CDN-Wechsel, Previews/Original/Video/Download, Proxy, Auth-Leaks, Cache.

## N03 – Cloudflare: state-changing Requests nicht blind erneut senden

**Status: ENTSCHIEDEN · 2026-10-15 · Umsetzung ausstehend.** **Beschlussart:** vollständig übernehmen (Replay-Sicherheit).

**Zielzustand / technische Grenzen:** Upstream-Schutz vor blindem Wiederholen mutierender Requests nach Cloudflare-Challenge übernehmen. POST/PUT, Votes, Favorites, Comments nur bei explizit sicherer Idempotenz erneut senden; Fork-Request-Kontext/Rule34 berücksichtigen.

**Abnahme / Tests:** Mutationen höchstens einmal, sichere GET-Recovery, Abbruch/Fehler.

## N04 – Cloudflare-Erkennung, Blockseiten, Redirects und Challenge-UX

**Status: ENTSCHIEDEN · 2026-10-15 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Upstream Cloudflare-Challenge-Erkennung, Blockseiten, Captcha-Bestätigung, Subdomain-Redirects, Loop-Vermeidung und Dialog-UX übernehmen; Fork Rule34-403-Recovery erhalten.

**Abnahme / Tests:** 403/429, Captcha, Challenge-Redirect, kein unnötiges Dialog-Aufblitzen/Loop.

## N05 – Clearance-Cookie und native WebView-Cookie-Bridge

**Status: ENTSCHIEDEN · 2026-10-15 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Upstream-WebView→HTTP-Cookie-Bridge Android/iOS/macOS übernehmen, ohne Fork-App-ID, Native Channels, Cookie-Origin-/Secure-/HttpOnly-Grenzen zu beeinträchtigen.

**Abnahme / Tests:** Gelöste Challenges, Domain/Subdomains, Android/iOS/macOS, unsupported platforms.

## N06 – HTTP/2-Window und automatisches Gzip

**Status: ENTSCHIEDEN · 2026-10-15 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** HTTP/2-Window- und Gzip-Verbesserungen übernehmen; Fork-Priorisierung, HTTP1-/Plattform-Fallback und mobile Speichergrenzen erhalten.

**Abnahme / Tests:** HTTP2/HTTP1, gzip, hohe Parallelität, wenig RAM.

## X03 – Fork-Export/Import, Profile-UUIDs und Following bewahren

**Status: ENTSCHIEDEN · 2026-10-15 · Umsetzung ausstehend.** **Beschlussart:** Fork-Architektur behalten, kompatible Upstream-Teile angepasst übernehmen.

**Zielzustand / technische Grenzen:** Die Fork-spezifische Export-/Import-/Backup-Pipeline, stabile Profile-UUIDs, `PostOrigin`/`BookmarkIdentity`, Hive-/Snapshot-Kompatibilität, verschachtelte Bookmark- und Pinned-Search-Ordner sowie Following-Feeds unverändert im Verhalten und in ihren Datenidentitäten erhalten. Keine Rückmigration auf Upstream-Profile, flache Ordner oder dessen alte Feed-/Backup-Modelle; keine inkompatible Schema- oder ID-Änderung.

**Gezielt übernehmen:** Aus Upstreams Headless-Refactoring die austauschbaren Plattform-, Navigation-, Dateipicker-, Repository-Factory- und Backup-Trigger-Abhängigkeiten sowie App-Flow-Tests kompatibel in den bereits beschlossenen A01-/A12-Zielzustand integrieren. Keine zweite parallele Runtime, Repository- oder Backup-Implementierung. Die Upstream-Bookmark-Library-Refresh-Ergänzung nicht zusätzlich kopieren: der Fork beobachtet `bookmarkProvider` bereits mit `BookmarkViewRefreshGate`, um Refresh/Selection korrekt zu koordinieren. Upstreams Export-Lesen von Favorite Tags direkt aus persistenter Storage statt möglicherweise uninitialisiertem UI-State ist unter D08 inzwischen separat beschlossen.

**Daten/API:** Keine neue Persistenz oder Migration allein durch X03. Vorhandene Profil-UUIDs, Bookmark-Hive-Felder 15/16, Post-Snapshots, Ordnerstrukturen und Following-Daten erhalten; X01/X02 und die bestehenden Fork-Import-/Recovery-Garantien gelten verbindlich.

**Abnahme / Tests:** Legacy- und aktueller Full-Backup-Roundtrip mit Profile-UUIDs, Bookmark-Gruppen/Unterordnern, Pinned Searches/Following und Favorite Tags; Cold-Start/Import-Recovery, Profilwechsel, Folder-Undo, Auswahl beim Bookmark-Refresh und kein doppelter Refresh. A01/A12-Headless-Flows; keine stillen Datenverluste.

**Begründung / Quellen:** Upstream [`a3278c5d2`](https://github.com/khoadng/Boorusama/commit/a3278c5d2ecc3672fea63c68fb21c81a1db2bb07) refaktoriert u. a. Backup-/Bookmark-Abhängigkeiten für Tests; [`3f4ce2bd4`](https://github.com/khoadng/Boorusama/commit/3f4ce2bd4f0f94c116b2262fa9418809710278a8) ergänzt im Fork bereits abgedeckten Refresh; [`f93bdf0dd`](https://github.com/khoadng/Boorusama/commit/f93bdf0dd42c5eb0e8165d9070310a2aebfa32c1) betrifft D08. Vom Nutzer am 2026-10-15 bestätigt.

## D02 – Bulk-Download-Finalisierung und Benachrichtigungen

**Status: ENTSCHIEDEN · 2026-10-15 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen; Fork-Lifecycle-Schutz behalten.

**Zielzustand / technische Grenzen:** Upstreams finale, nicht die zwischenzeitlich revertierte Timer-basierte Implementierung integrieren. Abgeschlossene Task-Records auch bei fehlgeschlagener Dateigrößenbestimmung als abgeschlossen markieren (`fileSize` dann unbekannt, Fehler protokollieren), danach Finalisierung prüfen. Concurrent Completion-Checks derselben Session serialisieren (Future-basierte `_completionChecks`-Sperre) und bereits abgeschlossene Sessions nicht erneut berechnen/aufräumen; finalen Statistik-Snapshot vor Task-/Record-Cleanup sichern. Zuletzt abgeschlossene Sessions als begrenzte `completedSessions`-Liste (Upstream: max. 100, nur im Speicher) im Download-Activity-State belassen, sodass eine kurzlebige UI-State-Änderung keine Completion-Notification verschluckt. Für abgeschlossene Aktivitäten Fortschritt 100 % anzeigen und doppelte Abschlussbenachrichtigungen vermeiden. Fork-eigene Notifier-/Session-Lifecycle-Guards und Download-Observer nicht durch vereinfachte Upstream-Version ersetzen.

**Recovery / Grenzen:** Die neue In-Memory-Liste ist kein persistentes Notification-Log. Zusätzlich Crash-/Restart- und Cleanup-Fehlerfenster untersuchen, vor allem Status `completed` vor erfolgreichem `updateStatisticsAndCleanup`; idempotente/restartfähige Recovery sicherstellen, ohne Statistiken zu verlieren oder Notifications mehrfach zu senden. Eine ungeprüfte vollständige Transaktionsgarantie wird nicht behauptet.

**Daten/API:** Bestehende persistente Bulk-Download-/Task-Repositories und Fork-Lifecycle-Strukturen erhalten; `completedSessions` ist zunächst ausschließlich abgeleiteter Runtime-State. Eventuell notwendige Persistenz-/Migrationsänderungen separat begründen und vor Umsetzung prüfen.

**Abnahme / Tests:** Parallele vollständige Task-Events, Out-of-order/Replay, konkurrierende Finalisierung, fehlgeschlagener Dateigrößenresolver, korrekte Summen, Cleanup-Fehler/Retry, Cold-Start/Resume, Notification-Sichtbarkeit nach Entfernen aus aktiver Liste, höchstens eine Abschlussbenachrichtigung, max.-100-Limit und Lifecycle-Disposal. Vorhandene Fork-Regressionstests und Upstream-D02-Testfälle kombinieren.

**Begründung / Quellen:** Upstream [`ebdfb05d9`](https://github.com/khoadng/Boorusama/commit/ebdfb05d9bec5be5c6fd6dd3e5460cea8ce1e1a1) revertiert die ursprüngliche deterministische Finalisierung nur vorübergehend; [`54b19cd4c`](https://github.com/khoadng/Boorusama/commit/54b19cd4cf77b3a75579a2b27aeccc1b1dc56ef5) führt serialisierte Completion, Fehlerbehandlung und History-for-Notifications wieder ein. Der Fork nutzt noch den älteren deterministischen Pfad plus eigene Lifecycle-Guards. Vom Nutzer am 2026-10-15 bestätigt.

## B01 – Sankaku-Metatags, Syntax-Highlighting und typed Suggestions

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Sankaku-spezifische Metatag-Definitionen (u. a. `rating`, `date`, `order`, `user`, `pool`, `fav`), Parser, typed Autocomplete-Suggestions und sichere Abbildung der Quellwerte übernehmen. Metatag-Präfixe erkennbar hervorheben, aber die UI in das geplante siteübergreifende Search-Options-Interface einfügen; keine parallele/alte Upstream-Search-Bar bauen. Raw-Syntax und sitespezifische Möglichkeiten bleiben hinter der gemeinsamen Schnittstelle.

**Abhängigkeiten:** Geplanter gemeinsamer Search-UX-Umbau; B02 und die bestehenden Fork-Suchzustände.

**Abnahme / Tests:** Tag- vs. Metatag-Vorschläge, `fav`/`user`/`pool`, Highlighting, Raw-Query, Leer-/Alias-/unbekannte Werte und neuer Search-UX-Flow, keine Regression in Suche/Tag-Chips.

**Begründung / Quellen:** Bestätigte Upstream-v4.6.1-Codeänderungen: [`2569eaeeb`](https://github.com/khoadng/Boorusama/commit/2569eaeeb6ea01ea35386ffc8bab858dcbd1d75d), [`216eb6e6d`](https://github.com/khoadng/Boorusama/commit/216eb6e6d43cef2581a110b66a8f1482d110e7b9). Nutzer hat den vollständigen B01–B10-Vorschlagsbatch am 2026-10-16 bestätigt.

## B02 – Sankaku-Exclusion und Datumsfilter normalisieren

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** übernehmen (site-adaptiert).

**Zielzustand / technische Grenzen:** Sankaku-Exclusion-Restriktionen verständlich übersetzen und nur für Sankaku einzelne gültige `date:YYYYMMDD`/`date:YYYY-MM-DD`-Tokens in einen API-konformen Tagesbereich übersetzen. Eine explizite Range, Operatoren, ungültige Datumsangaben und die sichtbare Raw-Query nicht unkontrolliert umschreiben; Normalisierung unmittelbar im Site-Query-Composer/Adapter.

**Abhängigkeiten:** B01, B05; gemeinsamer Search-Composer darf keine Sankaku-Syntax auf andere Sites anwenden.

**Abnahme / Tests:** Exclusion-Fehler/Limit-Codes, gültige/ungültige Daten, Tages-/Jahreswechsel, Leap-Day, Range und Vergleich Raw-Eingabe zu gesendetem Query.

**Begründung / Quellen:** Bestätigte Upstream-v4.6.1-Codeänderungen: [`18216f412`](https://github.com/khoadng/Boorusama/commit/18216f4123586634f0756e7d5b20673638711766), [`6ad672075`](https://github.com/khoadng/Boorusama/commit/6ad672075306e5621a4dde519ad124da0b19f8cb). Nutzer hat den vollständigen B01–B10-Vorschlagsbatch am 2026-10-16 bestätigt.

## B03 – Sankaku-Tag-Kategorien vollständig erhalten, Duplikate entfernen

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Alle bekannten Sankaku-Kategorien einschließlich Studio (`2`), Genre (`5`), Medium (`8`) und Meta (`9`) korrekt site-spezifisch zuordnen (generisches Fork-`TagCategory.fromLegacyId(5)` wäre für Sankaku falsch). Unbekannte Kategorien ohne stillen Verlust erhalten und doppelte API-Tag-Einträge nach echter ID bzw. Name+Kategorie konsistent deduplizieren; sinnvollere Counts übernehmen. Bestehende Fork-`PostRecord`/`PostOrigin`-/Snapshot-/Bookmark-Datenformate behalten, ggf. erweiterten Detailtag-Satz ohne persistente Schemaänderung bereitstellen.

**Abhängigkeiten:** X01/X02/X03 und Fork-Tag-Modell, keine Upstream-Postmodelle blind ersetzen.

**Abnahme / Tests:** Kategorien 0/1/2/3/4/5/8/9/unbekannt, doppelte Namen/IDs/Counts, Tag-Farben und Filter, Bookmark-Snapshot-Roundtrip, alte Daten.

**Begründung / Quellen:** Bestätigte Upstream-v4.6.1-Codeänderungen: [`d0fde834a`](https://github.com/khoadng/Boorusama/commit/d0fde834a413658bb50db150636c481c88a88222), [`396ae059e`](https://github.com/khoadng/Boorusama/commit/396ae059e9e5576aa0172df7fabf823963c03e92). Nutzer hat den vollständigen B01–B10-Vorschlagsbatch am 2026-10-16 bestätigt.

## B04 – Sankaku-Auth: API-Header, invalid credentials, Session-Recovery

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Bestehende Dio-Optionen/Interceptors/Header beim Sankaku-API-Header-Merge erhalten. Login-Response vor Token-Speicherung streng validieren. Bei erkennbar abgelaufenem/ungültigem Token GET-Requests höchstens einmal nach kontrollierter Neuanmeldung wiederholen; gleichzeitige Logins pro Client zusammenfassen, nur das tatsächlich abgelehnte Token invalidieren und Client-/Profile-Isolation bewahren. Mutierende Favorites/POST/DELETE nicht blind wiederholen, sondern Fehler melden und neue Auth für spätere Nutzeraktionen ermöglichen. Wenn Auto-Reauth scheitert, bestehende Profil-Login-UX verwenden; Tokens/Credentials nie loggen.

**Abhängigkeiten:** N01/N03/N04/N05; bestehendes Fork-Profil- und Credential-Modell, kein Cross-Origin-Auth-Leak.

**Abnahme / Tests:** Ungültige Credentials/Tokenformat, 401/API-Auth-Code, gleichzeitige GETs, erneute Ablehnung, Profilwechsel, Cookie/Header-Erhalt, Favoriten ohne Doppelmutation, Cancellation/Rate-Limit und Credential-Redaction.

**Begründung / Quellen:** Bestätigte Upstream-v4.6.1-Codeänderungen: [`829ec71fb`](https://github.com/khoadng/Boorusama/commit/829ec71fbaedbc60fff7d98fe1b40c494a130ebe), [`6ad691a6d`](https://github.com/khoadng/Boorusama/commit/6ad691a6de23d8a44c46d02bf3640997dbb618f4), [`6762d00f2`](https://github.com/khoadng/Boorusama/commit/6762d00f2e4ac6efc99bf969bd15a335f6767437), [`8757eb295`](https://github.com/khoadng/Boorusama/commit/8757eb2953d41716bc7c8fb3a028b71fb3f03e2c). Nutzer hat den vollständigen B01–B10-Vorschlagsbatch am 2026-10-16 bestätigt.

## B05 – Sankaku-Suchlimits korrekt erklären

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** vollständig übernehmen (in Fork-Fehler-UI).

**Zielzustand / technische Grenzen:** Sankaku-Codes für anonyme/Account-Tag-Limits in verständliche lokalisierte Meldungen übersetzen und an den Fork-Error-Layer anbinden. Bestehendes Verhalten bei unbekannten Serverfehlern als Fallback behalten.

**Abhängigkeiten:** B02 sowie vorhandener Error-Translator/i18n.

**Abnahme / Tests:** Anonyme/Account-Limits, bereits durch B02 erfasste Exclusion-Limits, lokalisierte Meldungen, unbekannte Fehler und Retry.

**Begründung / Quellen:** Bestätigte Upstream-v4.6.1-Codeänderungen: [`5b495f1ad`](https://github.com/khoadng/Boorusama/commit/5b495f1adec13643ee83307bb2b68eb0272766b2). Nutzer hat den vollständigen B01–B10-Vorschlagsbatch am 2026-10-16 bestätigt.

## B06 – Shimmie2: Medienformate und Favorite-Fallback

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Dateiformate aus `ext`, Filename und Datei-URL robust normalisieren (ohne Punkt, lowercase). Den serverseitigen Favorite-Status bei unterstützter Erweiterung und angemeldetem Nutzer ergänzen, aber optional und möglichst asynchron nach dem eigentlichen Post-Laden: Die Timeline darf bei Ausfall, fehlender Auth oder langsamer Favorite-API nicht blockiert werden. Späte Ergebnisse mit bereits erfolgten Nutzeraktionen bzw. aktuellem Favorite-Cache zusammenführen statt überschreiben; Fehler als Soft-Failure behandeln, bekannte Auth-Probleme sinnvoll sichtbar machen.

**Abhängigkeiten:** Fork-Favorite-Repository/Cache und Shimmie2-Feature-Capabilities.

**Abnahme / Tests:** Erkennung verschiedener Medienextensions/URL-Formate, fehlende Extension, GraphQL/REST, 100er-ID-Batches, Favoritenabfrage mit/ohne Login, Serverfehler/Timeout, schnelle Favorite-Mutation während laufender Abfrage.

**Begründung / Quellen:** Bestätigte Upstream-v4.6.1-Codeänderungen: [`2d4f8484b`](https://github.com/khoadng/Boorusama/commit/2d4f8484ba62db8e5c5386825934b1bcc30455cf), [`d79ef1fcc`](https://github.com/khoadng/Boorusama/commit/d79ef1fcc9f59b07933e76681b6c033e12327460). Nutzer hat den vollständigen B01–B10-Vorschlagsbatch am 2026-10-16 bestätigt.

## B07 – Gelbooru v2: Kommentar-Upvote und Cursor-Pagination

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Upstream-Gelv2-Comment-Page-Keys, Rule34-HTML-Kommentarparser/Score und cursorbasierte Pagination kompatibel zu Fork-Comment-/Postmodell übernehmen. **Upstream implementiert nur Kommentar-Upvotes, keine Downvotes**; keine Downvote-UI behaupten oder erfinden. Voting nur bei expliziter Site-Capability und gültiger Session anzeigen, mutierenden Upvote-GET trotz HTTP-Verb als Mutation behandeln (kein automatischer Replay nach Challenge/Retry), Auth- und Fehlerfälle sichtbar machen. Andere Gelv2-Sites behalten ihre vorhandenen Kommentar-Fetchpfade.

**Abhängigkeiten:** N03/N04, B08, Fork-Comment-/Selection-UI, Site-Capabilities.

**Abnahme / Tests:** Rule34-HTML/Script-Scores, Kommentare/Quotes, Cursor vorwärts/Ende, wiederholte Requests/Sortwechsel, login/no-login, Score- und Action-Fehler, POST-ID-Zuordnung, keine Doppelvotes unter 403/Cloudflare.

**Begründung / Quellen:** Bestätigte Upstream-v4.6.1-Codeänderungen: [`f459e9922`](https://github.com/khoadng/Boorusama/commit/f459e99220e4ac5b449c033d1d60a0b672ea2b58). Nutzer hat den vollständigen B01–B10-Vorschlagsbatch am 2026-10-16 bestätigt.

## B08 – Gelbooru v2: Kommentar-Sortierung

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** übernehmen, gemeinsam mit B07.

**Zielzustand / technische Grenzen:** Auf Sites, deren Comment-Capabilities es explizit vorsehen (Upstream: Rule34), `Newest`/`Oldest` über unterstützte Request-Sortierung anbieten (für Rule34 `comments_direction`-Cookie); bestehende Session-Cookies sicher mergen. Änderung nur innerhalb der aktuellen Kommentaransicht merken, ohne neue persistente Profileinstellung; Pagination/Cursor beim Umschalten vollständig zurücksetzen. Keine Optionen auf nicht unterstützten Sites zeigen.

**Abhängigkeiten:** B07 und Site-Feature-/Sort-Capabilities.

**Abnahme / Tests:** Newest/Oldest, Cookie-Isolation, Cursor-Reset, schnelle Sortwechsel und verspätete Requests, einzelne Seite und Reload.

**Begründung / Quellen:** Bestätigte Upstream-v4.6.1-Codeänderungen: [`43619dd49`](https://github.com/khoadng/Boorusama/commit/43619dd495d5cb79425845521f0a0e0de030670d). Nutzer hat den vollständigen B01–B10-Vorschlagsbatch am 2026-10-16 bestätigt.

## B09 – Nozomi: korrekte Tag-Counts und HTTP-Range-Encoding

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Nozomi-Tag-Counts aus Postindex-Dateigrößen statt Search-Buckets bestimmen; gezielte Byte-Range-Requests mit `Accept-Encoding: identity`, Behandlung 200/206/404/416 sowie Content-Range und Cache/Fallback korrekt übernehmen. Gleichzeitige Count-Lookups drosseln und mit dem Fork-`ApiRequestCoordinator` koordinieren, damit parallele Autosuggestions und Following keine unnötigen Host-Requests verursachen.

**Abhängigkeiten:** N01; Nozomi-Client/Rate-Policy des Forks.

**Abnahme / Tests:** Byte-Größe/4, partial/full Responses, fehlender Content-Range, 404/416/0, Range+gzip, Cache, Limits/429, parallele Suggestions und Cancellation.

**Begründung / Quellen:** Bestätigte Upstream-v4.6.1-Codeänderungen: [`7880a020f`](https://github.com/khoadng/Boorusama/commit/7880a020fc7ba968351ee5256d3685c347d4eca0), [`5a4498f78`](https://github.com/khoadng/Boorusama/commit/5a4498f78dbce67aa43c0d3d01c4fc8d31784a23). Nutzer hat den vollständigen B01–B10-Vorschlagsbatch am 2026-10-16 bestätigt.

## B10 – Rule34: JSON-Post-API auf api.rule34.xxx

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen, erst nach Verifikation aktivieren.

**Zielzustand / technische Grenzen:** Rule34-Listing-Endpoint nach gezielten Live-API-Tests auf `https://api.rule34.xxx/index.php?page=dapi&s=post&q=index&json=1` umstellen, da der Fork diesen Host bislang nur für Post-Details verwendet. Profil- und Site-Identität, Auth-/Cookie-Origin-Grenzen, Parsing, Pagination, Rate-Limits sowie eigene Rule34-403-/Cloudflare-Recovery erhalten. Bei Inkompatibilität zuerst Ursache bewerten, keinen ungetesteten Hostwechsel erzwingen.

**Abhängigkeiten:** N01/N02/N04/N05; aktuelles `boorus.yaml`-Rule34-Profil.

**Abnahme / Tests:** JSON-Post-Listen/Details, Pagination/Filter/Limit, mit und ohne Login, CORS/Redirect, 403-Challenge, Rate-Limit/429, Content-Shape, Cross-Host-Auth und Cache-Isolation; Live-Verifikation ist noch nicht erfolgt.

**Begründung / Quellen:** Bestätigte Upstream-v4.6.1-Codeänderungen: [`5972548ec`](https://github.com/khoadng/Boorusama/commit/5972548ecd6e32622b8476776490251d61d6a099). Nutzer hat den vollständigen B01–B10-Vorschlagsbatch am 2026-10-16 bestätigt.

## P02 – Profile mit unbekannten Thumbnail-Actions/Media-Host-Regeln behalten

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Optionale unbekannte/ungültige Thumbnail-Action-Werte und Media-Host-Overrides beim Einlesen tolerant behandeln, ohne das Profil als Ganzes zu verwerfen; bei Import/Restore nachvollziehbare Validierungswarnungen anbieten. Existierende Profil-UUIDs und übrige Daten stets behalten. Unbekannte, semantisch nicht auswertbare Werte, soweit technisch sicher möglich, für Forward-Compatibility im Originaldatensatz erhalten; andernfalls nur die betroffene Option mit dokumentiertem Fallback behandeln.

**Daten / Abhängigkeiten:** Keine Änderung an Profil-UUIDs oder Identitäten. Die noch offene P01-Konfigurationsmigration sowie N02-Media-Host-Regeln müssen das Fallback- und Warnmodell gemeinsam nutzen.

**Abnahme / Tests:** Alte/neue Profil-JSONs; unbekannte Action, fehlender/ungültiger Host oder Datentyp, doppelte Aktionen, Restore ohne Profilverlust und sichtbare Import-Warnungen.

**Begründung / Upstream-Quellen:** [`1d8c879f4`](https://github.com/khoadng/Boorusama/commit/1d8c879f406d54df86c25d334ace0ada98846886). Nutzer hat P02 am 2026-10-16 explizit bestätigt. P01 ist weiterhin offen.

## P05 – Bookmark-Library nach Bookmark-Mutation aktualisieren

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** Fork-Lösung behalten.

**Zielzustand / technische Grenzen:** Keinen zusätzlichen Upstream-Bookmark-Listener einbauen: Der Fork lauscht bereits auf `bookmarkProvider` und koordiniert Sichtbarkeitswechsel/Selection über `BookmarkViewRefreshGate`. Diesen einzigen autoritativen Refreshpfad behalten; nur nützliche Upstream-Regressionstests ergänzen.

**Daten / Abhängigkeiten:** Keine API-/Datenmigration. Überschneidet sich mit dem verbindlichen X03-Beschluss.

**Abnahme / Tests:** Bookmark hinzugefügt/gelöscht, Undo, Group-Switch, Sortierung, Filter, Details-Overlay und Selection-Stabilität; nur ein sichtbarer Refresh pro Mutation.

**Begründung / Upstream-Quellen:** [`3f4ce2bd4`](https://github.com/khoadng/Boorusama/commit/3f4ce2bd4f0f94c116b2262fa9418809710278a8). Nutzer hat P05 am 2026-10-16 explizit bestätigt. P01 ist weiterhin offen.

## P06 – GIF-Autoplay respektiert Qualitätseinstellungen

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** GIF-Autoplay-Setting bei allen Grid-Qualitätsstufen einschließlich `original` respektieren: Bei deaktiviertem Autoplay nur eine statische Vorschau laden; bei aktiviertem Autoplay animierte GIF-Varianten im Grid nur unter der nachfolgend festgelegten 5-MiB-Originaldateigrößen-Schranke verwenden und sonst statisches Thumbnail. Wichtig: Statische kleinere GIF-Thumbnails sind keine garantierten niedrig aufgelösten *animierten* GIF-Varianten; Danbooru liefert häufig statische 180/360/720-Varianten und die animierte Original-GIF. Eine fehlende animierte Preview nicht erfinden; im Viewer gelten dessen eigene Qualität-/Abspielregeln.

**Daten / Abhängigkeiten:** Fork-spezifische Danbooru-Variant-URL-Auflösung und generischen Thumbnail-Resolver erhalten; keine persistente Migration.

**Abnahme / Tests:** Danbooru/andere Boorus, automatische/low/high/highest/original-Qualität × autoplay/static, verfügbares/unverfügbares Sample, URL und Aspect Ratio, GIF-Originalgrößen 0/unbekannt/5 MiB/5 MiB+1 Byte, kein animiertes Sample als Limit-Bypass, keine zusätzlichen HEAD/GET-Anfragen für Prüfung, unberührte Viewer-/Download-Flows.

**Zusätzliche verbindliche Schutzregel (2026-10-16, Nutzerbestätigung):** In sämtlichen Post-Grid-/Timeline-Varianten **animierte GIF-Dateien nur automatisch anfordern, wenn die bekannte Größe der Original-GIF-Datei positiv und ≤ 5 MiB (5 × 1024 × 1024 Bytes) ist und GIF-Autoplay aktiviert ist**. Bei größerer, fehlender, ungültiger oder als 0 defaultierter Größe nur eine statische Vorschau anfordern – auch bei manuell `Highest`. Auch animierte `sample`-Varianten unterliegen dieser konservativen Originalgrößen-Schranke, da `VariantDto` für Samples zwar URL/Dimension/File-Extension, aber **keine Sample-Dateigröße** liefert; keinesfalls eine unkontrolliert große Sample-GIF als Umgehung zulassen. Ist die Originaldatei klein genug, die ohnehin von der bestehenden Qualitätsstufe aufgelöste animierte `sample`-/Original-Quelle weiter verwenden und Highest nicht pauschal auf Original zwingen. `post.fileSize` stammt aus Danboorus `PostDto.file_size`; `fileSize <= 0` bedeutet unbekannt und ist **nicht** freizugeben. Keine HEAD-Probes/eigenen Original-Downloads ausschließlich für diesen Size-Check; bereits vorhandene API-Metadaten nutzen. Auf andere Boorus nur anwenden, soweit die Größenangabe verlässlich die Original-GIF-Datei beschreibt. Gilt nur für automatisches Grid-/Timeline-Playback, **nicht** für die explizite Post-Viewer-Ansicht, manuelle Originalansicht oder Downloads. Das Limit verhindert große Dateiabrufe, ist aber keine Garantie für geringe Decoder-/CPU-Kosten.

**Technisch verifizierter Befund zur GIF-Qualität (2026-10-16):** In `lib/boorus/danbooru/posts/listing/src/grid_thumbnail_url.dart` wählt **manuelles Highest** bei normalen/großen Danbooru-Grid-Kacheln `PostQualityType.sample`, welches für GIFs tatsächlich animierte Medien liefern kann (vom Nutzer live beobachtet). Der GIF-Zweig nutzt `settings.imageQuality` roh; bei **Automatic**, selbst im größten Grid, führt dies dagegen zum statischen `720x720`-Variantpfad, obwohl `resolvedImageQuality` sonst bei `GridSize.large` zu Highest auflöst. Deshalb GIF-Auto nicht versehentlich mit einer generellen höchsten Qualitätsstufe gleichsetzen. Das **gewünschte Verhalten** bleibt: `autoplay` aktiv + manuell Highest soll die animierte Sample-Vorschau weiter verwenden können; `autoplay` deaktiviert muss auch bei manuell Highest eine statische Variante wählen. Die bestehende automatische Grid-Größenstaffelung bleibt erhalten; eine Änderung, ob Automatic-Large bei GIFs künftig animieren soll, ist durch P06 **nicht** implizit freigegeben. **Upstream-v4.6.1-Einschränkung:** `e4d645630` korrigiert den generischen GIF-Resolver und für Danbooru vor allem den `Original`-Fall bei deaktiviertem Autoplay; der Danbooru-Highest-Zweig benötigt den Fork-spezifischen zusätzlichen Guard. Testcases müssen beide Pfade explizit prüfen.

**Begründung / Upstream-Quellen:** [`e4d645630`](https://github.com/khoadng/Boorusama/commit/e4d6456309c93f050b3a5d311ea4e2a60e0a7663). Nutzer hat P06 am 2026-10-16 explizit bestätigt. P01 ist weiterhin offen.

## P07 – Video-Thumbnail bis zum ersten gerenderten Frame anzeigen

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Video-Thumbnail/Poster bis zum tatsächlichen Rendering des ersten Frames anzeigen und anschließend nahtlos freigeben. First-Frame-Status für jeden Quell-/Engine-Wechsel zurücksetzen und ältere asynchrone Signale anhand Generation/Source-ID ignorieren; bei fehlgeschlagener First-Frame-Benachrichtigung einen sichtbaren Fehler-/Fallbackzustand bereitstellen, keinen dauerhaft verdeckten Player. Fork-Video-Viewer, Cache und Hero-/Thumbnail-Logik erhalten.

**Daten / Abhängigkeiten:** `BooruPlayer`-fähige First-Frame-Signale für unterstützte Engines; nur Runtime-State, keine Migration.

**Abnahme / Tests:** Langsame Initialisierung, Cache/Stream, MPV/MediaKit/video_player/WebView, schnelle URL-Wechsel, First-Frame-/Player-Fehler, dispose und Reinitialize, Overlay/Transition.

**Begründung / Upstream-Quellen:** [`2003c0c1e`](https://github.com/khoadng/Boorusama/commit/2003c0c1eb2cf6b3ef0939b33adf1b575fcae8f9). Nutzer hat P07 am 2026-10-16 explizit bestätigt. P01 ist weiterhin offen.

## P11 – Videosteuerung: Zeit-Overflow und Media-Play/Pause-Key

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** übernehmen (Fork-Player berücksichtigen).

**Zielzustand / technische Grenzen:** Video-Zeitanzeigen nicht länger auf fixe 40 px beschränken (minimale Breite und sichere flexible Darstellung). Media-Play/Pause/Toggle-Hardwaretasten nur auf den aktuell sichtbaren/fokussierten Video-Post routen; bei Bild-Posts, Hidden Playern und Textfokus nicht unerwartet abspielen. Vorhandene Player-Engine- und Viewer-Shortcuts erhalten.

**Daten / Abhängigkeiten:** Keine Persistenz. Keyboard-Shortcut-Routing bei U04/U05/U06 auf Konflikte prüfen.

**Abnahme / Tests:** Lange Zeiten/schmale Screens, Text-Scaling, MediaPlay/MediaPause/MediaPlayPause, Bildpost vs. Videopost, Fokus/Seitenwechsel, unterschiedliche Engines.

**Begründung / Upstream-Quellen:** [`c65a81074`](https://github.com/khoadng/Boorusama/commit/c65a81074f123eed5efbe368a8a44985dd8340cf), [`72bafb43d`](https://github.com/khoadng/Boorusama/commit/72bafb43d3e5063749ce663277201b01ea644a54). Nutzer hat P11 am 2026-10-16 explizit bestätigt. P01 ist weiterhin offen.

## P12 – Hover Preview nur über Info-Badge öffnen; Long Press erhalten

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Hover-Preview nicht über die gesamte Thumbnail-Fläche, sondern über ein gezieltes Info-Badge öffnen, das bei Pointer-Hover bzw. passend fokussierter Keyboard-Navigation sichtbar wird. Gesten-/Hit-Test-Fixes für Long-Press, Right-Click und Hold-and-Drag übernehmen, Selection vor Preview-Badge priorisieren und bei Tastatureingaben Preview sauber schließen. Badge-Positionierung mit dem beschlossenen P01 (bis zu zwei Quick Actions) und Series-Gruppenkarten abstimmen; keine neue unruhige permanente Overlay-Reihe.

**Daten / Abhängigkeiten:** Nur UI/Interaktion, keine neuen persistenten Felder. Bestehenden `tooltipDisplayMode` respektieren.

**Abnahme / Tests:** Desktop Hover/Badeg-Tap, Touch Long-Press, Rechtsklick, Hold-and-Drag-Selection, Keyboard/Escape/Textinput, enge Grid-Kacheln, Series-Karte, disabled Tooltip.

**Begründung / Upstream-Quellen:** [`e04b3bfd1`](https://github.com/khoadng/Boorusama/commit/e04b3bfd186e8b5b88ab704189e23178ae26d098), [`5da94c1df`](https://github.com/khoadng/Boorusama/commit/5da94c1dfa6a39ef34c21c6ba1d171267ee06928), [`5feaa3dcf`](https://github.com/khoadng/Boorusama/commit/5feaa3dcf0a5069afab3f95594b3935fe08f7150). Nutzer hat P12 am 2026-10-16 explizit bestätigt. P01 ist weiterhin offen.

## P13 – Post-/Tag-Kontextmenüs auf Kurumi migrieren

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen (A02).

**Zielzustand / technische Grenzen:** Post-/Tag-Kontextmenüs über Kurumi vereinheitlichen und Keyboard/Right-Click/Long-Press/Back/Escape sowie konsistente Darstellung übernehmen. ALLE Fork-Menüaktionen, Favoriten-/Bookmarks-/Following-/Gruppenaktionen, Untermenüs, Kontext-/Selection-Priorität und bestehende Tap-through-/Dismiss-Fixes behalten. Upstreams große Migration nicht pauschal über die Fork-`KurumiContextMenuPageController`- und `CustomContextMenuOverlay`-Erweiterungen legen; dieselbe Menükomponente mit kompatiblen Funktionen verwenden.

**Daten / Abhängigkeiten:** Keine persistente Migration, A02-Kurumi-/Menü-Migration koordinieren; Anchor-Dependency-Fix nur im kompatiblen Lockfile-Stand anwenden.

**Abnahme / Tests:** Post/Tag/Grid/Selection, Long-Press, Right-Click, Untermenüs, ESC/Back, Keyboard-Rückfokus, outside click, RTL/kompakt/Tag-Cloud und Overlay-Schichtreihenfolge.

**Begründung / Upstream-Quellen:** [`8ca15fcff`](https://github.com/khoadng/Boorusama/commit/8ca15fcff2e461488bc4ced314700196d421deb5), [`1e480b775`](https://github.com/khoadng/Boorusama/commit/1e480b7751a359931c53057e86a42ff56a1c6672). Nutzer hat P13 am 2026-10-16 explizit bestätigt. P01 ist weiterhin offen.

## P14 – Keyboard-Fokus auf Quick Favorite/Bookmark-Buttons

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** übernehmen, abgestimmt auf P01/A02.

**Zielzustand / technische Grenzen:** Sichtbare Quick Favorite-/Bookmark-Buttons und weitere Thumbnail-Actions mit klarer Semantik, fokussiertem Zustand und Enter/Space-Aktivierung versehen. Bei maximal zwei Aktionen eine logisch nachvollziehbare Reihenfolge und Pfeil-/Tab-Navigation anbieten, ohne Kachelöffnung, Grid-Selection, Scroll-/Hold-and-Drag-Gesten zu übernehmen oder unsichtbare Buttons fokussierbar zu machen.

**Daten / Abhängigkeiten:** Kein Datenmodell/Schema. Abhängig vom noch offenen Layout P01 und A02-Focus-/Kurumi-Änderungen.

**Abnahme / Tests:** Keyboard/TV Focus/Enter/Space/Arrow/Tab, Scroll mit Recycling, Selection, Hidden/Disabled Actions, kleine Kacheln und visuelle Focus-Indication.

**Begründung / Upstream-Quellen:** [`d1047aa89`](https://github.com/khoadng/Boorusama/commit/d1047aa890c64b3baa575e0ca16f50b4724e6826). Nutzer hat P14 am 2026-10-16 explizit bestätigt. P01 ist weiterhin offen.

## P03 – Bildladefehler: Tap-to-Retry nur bei passenden Error-Widgets

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Endgültige Upstream-Variante mit explizitem `ExtendedImageController.reload()` statt früherem flächendeckendem `GestureDetector` verwenden. In Fork-Grid und Post-Viewer gut sichtbaren, fokussierbaren Retry-Button im `ErrorPlaceholder` anbieten; Tippen auf restliche Kachel muss weiterhin den Post öffnen und Selection-/Hold-Gesten respektieren. Der Fork-`ProgressivePostImage` hat eine eigene Kandidaten-/Generations-Loading-Pipeline und muss einen separaten kontrollierten Retry des fehlgeschlagenen Ziel-/Fallback-Requests ermöglichen, ohne ein bereits erfolgreich dekodiertes niedrigeres Bild zu verlieren. Kein automatisches endloses Retry oder unkontrolliertes Disk-Cache-Löschen.

**Daten / Abhängigkeiten:** Keine persistente Migration; `packages/extended_image`-API und Fork-Progressive-Loader/Shared-Cache entsprechend anpassen. X04-Cache-Invarianten erhalten.

**Abnahme / Tests:** Primary/Fallback/Progressive-Fehler, Zielbild-Neuladen mit gehaltenem Placeholder, Retry nach 403/Timeout/invalidierter Datei, Kachel-Tap vs. Retry-Button, Selection/Long-Press, Accessibility/Keyboard und keine dauernde Request-Schleife.

**Begründung / Quellen:** [`afdff42e3`](https://github.com/khoadng/Boorusama/commit/afdff42e344a585439bef34893bc2cbaa8e706df), [`58e4a0607`](https://github.com/khoadng/Boorusama/commit/58e4a06075faa8c07d8129dfdfa19156a4981a50). Der Nutzer bestätigte P03 nach Detailbesprechung am 2026-10-16.

## P04 – Post-Grid: Refresh während laufendem Fetch nicht verlieren

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** Fork-Race-/Refresh-Queue behalten und gezielt ergänzen.

**Zielzustand / technische Grenzen:** Bestehenden `PostGridController` mit `_refreshPending`, `_pendingMaintainPage`, `_pendingPreserveSelection` und `_queuedRefreshWaiters` unverändert als einzige Refresh-Queue erhalten. Upstreams Latest-Result-Schutz ergänzen: Wenn während des laufenden Fetchs eine neue Suche/ein Refresh/ein Profilwechsel vorgemerkt wird, die veraltete Antwort nicht zwischenzeitlich in den sichtbaren Grid-State übernehmen, sondern danach den neuesten Stand laden und erst dessen Ergebnis veröffentlichen. Fehler veralteter Passes nicht als endgültige UI-Fehler anzeigen, wenn der zuletzt angeforderte Pass erfolgreich war; aber echte letzte Fehler und wartende Future-Aufrufer korrekt behandeln. Keine zusätzliche Upstream-Refresh-Queue oder Selection-Reset einführen.

**Daten / Abhängigkeiten:** Keine Datenmigration; Bezug auf Following Topics, automatische Suchänderungen, Profilwechsel und P05-X03-Bookmark-Library-Gate.

**Abnahme / Tests:** Getaktete, konkurrierende Fetches/Refreshes, alte Antwort nicht gerendert, spätester Query/Profil-Snapshot gewinnt, Fetch-Fehler vor erfolgreichem Folgepass, maintainPage, preserveSelection, Wartende Future, Dispose, Duplicate-Fetches/Loading-State.

**Begründung / Quellen:** [`828ddbdb7`](https://github.com/khoadng/Boorusama/commit/828ddbdb75afd02fe14cf8182774a3ef67c9128f). Der Nutzer bestätigte P04 nach Detailbesprechung am 2026-10-16.

## P08 – WebView-Video aus Cache-Datei und Cleanup-Schutz

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen, Video-Cache-Lifetime schützen.

**Zielzustand / technische Grenzen:** Upstreams WebView-Wiedergabe lokaler Cache-Dateien mit kleiner lokaler HTML-Seite, MIME-Erkennung aus `VideoSource`, eingeschränktem lokalen Datei-Zugriff und sicherer serieller Bereinigung alter temporärer WebView-Seiten übernehmen; den bisherigen fehleranfälligen Base64/10-MiB-Fallback vermeiden. Fork-`VideoCacheManager` bislang ohne garantierten Usage-Schutz für aktive Videodateien: während Player/WebView-Dateizugriffes Eviction, Expiration und explizites Cache-Leeren gegen diese Videodatei absichern (kurzlebige, pro Datei referenzierte Nutzung/Lease). Beim Video-/Engine-Wechsel, Error und Dispose freigeben; ggf. zur Löschung vorgemerkte Dateien anschließend bereinigen. Keine Image-Cache-Generations zurückbringen und kein dauerhaftes Leasing über den Wiedergabezeitraum hinaus. Bei beschädigter/fehlender Cache-Datei sauber auf Remote-Streaming zurückfallen, ohne Auth/Cookies an unberechtigte Datei-/Origin-Kontexte zu geben.

**Daten / Abhängigkeiten:** Cache-Lifetime ist separate Video-Cache-Verwaltung (`packages/cache_manager/lib/src/video_cache_manager.dart`), nicht X04-Image-Cache. Lokale `CachedVideoSource` muss gültigen Pfad bekommen; temporäre HTML-Dateien werden verlässlich beim Schließen/Start bereinigt; kein Persistenzschema erforderlich.

**Abnahme / Tests:** Kleine/große/unbekannt große gecachte Videos, WebView Android/iOS/macOS, parallele Player, Cache-Eviction und Clear während Playback, Expiration, Video-/Engine-/Source-Wechsel, lokale Seite und Datei-Race, Stale-Cleanup beim Start, Streaming-Fallback, File-Read-Grenzen.

**Begründung / Quellen:** [`f3d8acaa0`](https://github.com/khoadng/Boorusama/commit/f3d8acaa0a765b6d2957ddd36f68a1aa944fa328), [`0f71409de`](https://github.com/khoadng/Boorusama/commit/0f71409dea3775ae1dd033bcf7fc27bb008888a0). Der Nutzer bestätigte P08 nach Detailbesprechung am 2026-10-16.

## P09 – Kurumi InteractiveViewer: Bild-Pan vs Page-Swipe

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen, Fork-Gesten erhalten.

**Zielzustand / technische Grenzen:** Bei unzoomed Bild (Zoom nahe 1x) sollen horizontale/vertikale PageView-Swipes statt `InteractiveViewer`-Panning gewinnen; bei vergrößertem Bild soll Pan/Pinch funktionieren. Upstreams Zoom-abhängiges `panEnabled` und die `ScaleGestureRecognizer.panCausesAcceptance`-Arbitration soweit notwendig integrieren. Vendored Flutter-3.47.2-Widget/Recognizer nur übernehmen, wenn eine kleinere kompatible Lösung am gepinnten Flutter nicht robust ausreicht. Sämtliche Fork-Funktionen erhalten: Double-Tap-Classic/Fit-Cycle, Snap-Zoom-to-Fit, Bildgrenzen, Auto-Comic-Strip, Original-on-Zoom sowie `ZoomEdgePageGesture` mit 160-dp-Edge-Pull, Retry-/Load-More-/Page-Actions. Panning und Page-Swiping nicht gleichzeitig aktivieren oder Pointer-Events doppelt konsumieren.

**Daten / Abhängigkeiten:** Keine Persistenz; A02-Kurumi-Migration und gepinnte Flutter-Version beachten, mögliche vendored Dateien nur gezielt und mit klarer Upgrade-Strategie.

**Abnahme / Tests:** Schneller Flick bei 1x horizontal/vertikal auf Android-Slop, Pinch-Zoom, Pan bei >1x, Edge-Pull/160-dp-Schwelle, geändertes Zoom/Media-Representation während Gesture, Mouse/Touch/Stylus, Rotation, Double-Tap, Original-on-Zoom, Selection und Zoom-Hardwaretest.

**Begründung / Quellen:** [`62e36f7e5`](https://github.com/khoadng/Boorusama/commit/62e36f7e5c7d40a3b5daa383a7c67ca420cb1cd3), [`c6b25213c`](https://github.com/khoadng/Boorusama/commit/c6b25213c3478abedf5c82c41dd9dd92a93a1bbe). Der Nutzer bestätigte P09 nach Detailbesprechung am 2026-10-16.

## P10 – Volume Keys im Post Viewer korrekt konsumieren

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** vollständig übernehmen (mit aktiviertem Viewer-Gate).

**Zielzustand / technische Grenzen:** Bei eingeschalteter `volumeKeyViewerNavigation`, tatsächlich sichtbarem und nicht expandiertem Post-Viewer, Lauter (+) zur Navigation zum nächsten Post und Leiser (-) zum vorherigen Post verwenden und alle zugehörigen Key-Down-/Repeat-/Up-Ereignisse als verarbeitet (`true`) zurückgeben, auch am ersten oder letzten Post. Bei ausgeschalteter Funktion, verborgenem Viewer und Expand-Mode die Keys unbehandelt (`false`) lassen, damit reguläre Systemlautstärke funktioniert. Navigation selbst nicht ungewollt bei Key-Up/Repeat mehrfach auslösen; bestehende `isKeyPressed`-Down-Gestenerkennung und eventuelle Android-/Hardware-Limits bewahren. Während dieses optionalen Modus gilt Post-Navigation auch bei Videoposts.

**Daten / Abhängigkeiten:** Keine Persistenz-/Schemaänderung, vorhandene Setting/Global-Keyboard-Handler beibehalten.

**Abnahme / Tests:** Key-Down/Repeat/Up, erster/letzter Post, Viewer sichtbar/verborgen, Setting an/aus, Expand-Mode, Video/Bild, Systemlautstärke außerhalb des Viewers, kein doppeltes Navigieren.

**Begründung / Quellen:** [`de755c0d2`](https://github.com/khoadng/Boorusama/commit/de755c0d20570d4c9e2c6d4b718517514178af44). Der Nutzer bestätigte P10 nach Detailbesprechung am 2026-10-16.

## P01 – Zwei Quick Actions auf Post-Thumbnails

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen, Fork-Post-Presentation bewahren.

**Zielzustand / technische Grenzen:** Upstreams zwei pro Profil konfigurierbare Thumbnail-Quick-Actions (primary/secondary; Standard/Favorite je Booru, Bookmark, Download, Artist; optional keine) einschließlich kompakter adaptiver horizontaler/vertikaler Platzierung übernehmen. Primär-/Sekundäraktion sind verschieden; ohne primäre Aktion keine sekundäre. Standardmäßig weiter nur die bisherige primäre Aktion, Sekundäraktion deaktiviert. Bei knappen Kacheln nur Primäraktion anzeigen. Aktionen unten rechts gruppieren, Score unten links; Selection blendet beide aus und hat Vorrang. Auf Series-/Grouped-Post-Karten keine Post-spezifischen Mutationen auf einen beliebigen Einzelpost umbiegen: dafür erst einen klaren geeigneten Aktionsträger definieren.

**Zwingende Fork-Kompatibilität:** Die 2026-09-24 mit [`c00ac614f`](https://github.com/timberpile/Boorusama/commit/c00ac614f8fb5849e57f924b6bfeaaf8a22a057c) eingeführte per-Post-Boundary erhalten: `PostGridItem` ermittelt `PostGridItemAdditions.quickActionButton` anhand der konkreten `post.origin`/`BooruPostPresentation` und übergibt diese als `defaultActionButton` an `DefaultImagePreviewQuickActionButton`. Dieser Button hat **nur bei der gewählten Default-Aktion** Vorrang vor `booruBuilder.quickFavoriteButtonBuilder`, nicht bei explizit gewählten Bookmark/Download/Artist-Actions. Beispiel: `DanbooruPostGridPresentation` liefert `DanbooruQuickFavoriteButton` mit Banned-Status-Abstimmung. Auch bei zwei Actions für jeden einzelnen Post korrekt auflösen; Mixed-Booru-Feed, Bookmark/Following und Custom-Fallbacks dürfen keine global falschen Aktionen zeigen. Direkt übergebene `quickActionButton`-Overrides/Selection-Guards ebenfalls erhalten.

**Daten / Migration:** Bisheriges einzelnes String-Feld `defaultPreviewImageButtonAction` verlustfrei auf `thumbnailActions` (primär, optional sekundär) mappen; alte Import-/Export-Profile und UUIDs erhalten. Unknown/invalid Optionen über den bereits beschlossenen P02-Schutz behandeln; keine versehentliche Zurücksetzung der Nutzerwahl.

**Abnahme / Tests:** Alle Legacy-Actions und ihr Default-Fallback, sitespezifische Default-Aktion in gemischten Feeds, Banned/Unsupported-Post, primär=sekundär/none, Legacy-JSON und Roundtrip, kleine Grid-Größen und großer Text, Selection/Hold-and-Drag, Series-Karten, Score-/Info-Badge-P12-Überlagerungen, Mouse/Touch/TV/Keyboard (P14).

**Quelle:** Upstream [`26ad35202`](https://github.com/khoadng/Boorusama/commit/26ad352026bb4187e399dfab422c76427aca8655). Der Nutzer hat P01 am 2026-10-16 nach Klärung der Fork-spezifischen `defaultActionButton`-Semantik bestätigt.

## U01 – Suche oberhalb Soft-Keyboard bedienbar

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Upstream-Fixes für Suche bei eingeblendeter Soft-Keyboard übernehmen: Search-Overlay innerhalb tatsächlich verfügbarem Platz positionieren (`fitToAvailableSpace` oder gleichwertige adaptive Platzierung), `MediaQuery.viewInsets.bottom` bei Top-/Bottom-Search korrekt einbeziehen und Liste/Inputs scrollbar halten. Die noch geplante kompakte, einheitliche Fork-Suche mit termbezogenem Raw Editor, automatischer Suche und Tag-/Metatag-Vorschlägen darf nicht durch alte Upstream-UI ersetzt werden. Texteingabe, vorhandene Chips und Vorschlagsauswahl bleiben bei 320dp, Landscape, Rotation und großem Text sichtbar; nicht unnötig das Keyboard schließen.

**Daten / Abhängigkeiten:** Gemeinsamer Search-UX-Umbau, B01–B05, U03; Profile-/Search-Session und A02-UI-Komponenten erhalten.

**Abnahme / Tests:** Phone Small/Normal/Landscape; Top- und Bottom-Position; Keyboard offen, 1.5–2× Schrift, Rotation, Suggestion-Auswahl, termbezogener Raw Editor und sichtbare aktive Chips; Upstream Headless-Keyboard-Flow adaptieren.

**Begründung / Upstream-Quellen:** [`a00d41f3a`](https://github.com/khoadng/Boorusama/commit/a00d41f3a7a1e81954e718ab1144183426a1ab89). Nutzer bestätigte U01 ausdrücklich am 2026-10-16; es ist ein Planungsbeschluss ohne Code-Implementierung.

## U02 – Search History als Full-Height-Sheet + Tests

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** übernehmen.

**Zielzustand / technische Grenzen:** Search History auf Telefon als scrollkontrolliertes Bottom Sheet (`isScrollControlled: true`) mit sinnvoll nutzbarer Höhe zeigen; Liste scrollbar, Tastatur/Insets berücksichtigen und auf weitere UI-Navigation responsiv reagieren. Bestehende Filter-/History-/Pinned-Search-/Following- und Suchzustand-Wiederherstellung erhalten, keine eigene History-Datenmigration. Upstreams Flow-Tests adaptieren.

**Daten / Abhängigkeiten:** Fork SearchHistory-Route und SearchProfileSession; U01/U03 sowie neuer Search-UX-Einstieg.

**Abnahme / Tests:** Viele Historieneinträge, Suche/Filter, Auswahl übernimmt Query korrekt, Keyboard/Back/Escape, Route-Return, Sheet bei niedriger Höhe; keine doppelte Search-Action.

**Begründung / Upstream-Quellen:** [`e53cdf3b3`](https://github.com/khoadng/Boorusama/commit/e53cdf3b31560cd4607431381b316b8e29349b11), [`3726d75c7`](https://github.com/khoadng/Boorusama/commit/3726d75c7eb14ea170e06e497b09198f4a9c4c71). Nutzer bestätigte U02 ausdrücklich am 2026-10-16; es ist ein Planungsbeschluss ohne Code-Implementierung.

## U03 – Tag-Suggestions per Tastatur fokussieren und hervorheben

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Vorschlagsliste als fokuserhaltende Kurumi-Listbox oder gleichwertigen gemeinsamen Mechanismus anbinden: Up/Down bewegt sichtbares Highlight, Enter wählt aktiven Vorschlag, Escape löscht zunächst nur den Highlight-Zustand, während der Textfokus im Suchfeld bleibt; danach greifen Search-/Layer-Back-Regeln. Das Listen-Highlight ist semantisch markiert und scrollt ins Sichtfeld. Keyboard-Navigation konsistent für Desktop, Hardware-Keyboard/TV und für Raw-Editor des einzelnen Suchbegriffs; keine doppelte Fokusmarkierung um Input/Bar, keine Tastenevents in verdeckte Screens durchlassen. Tag- und Metatag-Einträge des zukünftigen allgemeinen Search-Options-Interface unterstützen.

**Daten / Abhängigkeiten:** B01, geplanter Suchumbau, U01, U04–U06, A02-Kurumi; kein zweiter Search-Controller/Legacy-Chip-Editor.

**Abnahme / Tests:** Vorwärts/rückwärts/reversed Suggestions, Up/Down/Enter/Escape, Auswahlliste bei Filteränderung, Tab/Shift-Tab, Fokus bleibt im Feld, Raw-Query und Single-Term-Editor, mit/ohne Keyboard; Scroll-to-highlight; keine Tastaturaktion an verdeckter Seite.

**Begründung / Upstream-Quellen:** [`f7174bab4`](https://github.com/khoadng/Boorusama/commit/f7174bab405360103c48659b1c5bb72cbcd2bd61), [`e1ad37e1e`](https://github.com/khoadng/Boorusama/commit/e1ad37e1eddbb12106930e2ec983536863b5511b), [`7f5693c84`](https://github.com/khoadng/Boorusama/commit/7f5693c847ea0a88acb1fd12ff05057e0a6e5bb5). Nutzer bestätigte U03 ausdrücklich am 2026-10-16; es ist ein Planungsbeschluss ohne Code-Implementierung.

## U04 – TV-Remote- und Tastaturnavigation auf gesamter App

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen; TV Best-Effort.

**Zielzustand / technische Grenzen:** Gemeinsame directional Focus-Navigation (D-Pad/Pfeiltasten), sichtbare Focus-Rings erst bei Keyboard-/Remote-Bedienung, Scroll-to-focused-Item und vernünftige Navigation über FocusScopes/Drawer/Sidebar/Toolbar/Viewer/Dialoge übernehmen. Upstreams `KurumiDirectionalFocusAction`, Ring-/Focus-Utilities, Key-Handling und Test-Harness nur in Fork-kompatibler Form integrieren; Touch-/Mouse-Navigation ungestört lassen und keine unabsichtliche Aktivierung versteckter Controls. TV/Remote zunächst ausdrücklich **Best-Effort**, keine neue offiziell unterstützte TV-Plattform samt Release-/Support-Versprechen.

**Daten / Abhängigkeiten:** A02, P01/P13/P14, U03/U05/U06 und bestehende Fork-Navigation/Panel-Auswahl.

**Abnahme / Tests:** D-Pad+Enter+Back über Start/Browse/Profiles/Search/Settings/Viewer/Dialogs, Focus-Scope-Wechsel, Scroll-Reveal, nicht sichtbar/offstage, Input-Editing vs. Fokus, Touch/Mouse-Wechsel, Ring nur bei Keyboard; autom. Headless-Flows.

**Begründung / Upstream-Quellen:** [`e80eb1210`](https://github.com/khoadng/Boorusama/commit/e80eb1210a2327dfae4eba4866a1e7cfe472dfd8), [`00feb4d99`](https://github.com/khoadng/Boorusama/commit/00feb4d9923b49a931b7b0a24a9ac6f262214cc0), [`1e3b00c3a`](https://github.com/khoadng/Boorusama/commit/1e3b00c3a8e9c9cc43b947bb42501c2e33b30bf0), [`41d0121ce`](https://github.com/khoadng/Boorusama/commit/41d0121cee07c3533042f86e0b256663a9f7134d), [`7895ce70e`](https://github.com/khoadng/Boorusama/commit/7895ce70e7b520ddd8cefe3ef640de3679ee4fde). Nutzer bestätigte U04 ausdrücklich am 2026-10-16; es ist ein Planungsbeschluss ohne Code-Implementierung.

## U05 – Desktop Tab-Reihenfolge und Fokusgrenzen

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Pane-bezogene Tab-/Shift+Tab-Reihenfolge und FocusTraversalGroup/FocusPane sinnvoll in bestehender Sidebar, Profile-Switcher, Settings-Suche, Suchergebnissen, Browse/Post-Viewer und Dialogen etablieren. Sichtbar-fokussierte Elemente gegenüber Offstage-/Scroll-Bereich priorisieren; bei Keyboard-only Interaktion Ring zeigen, nach Mouse/Touch ausblenden; beim Schließen von Dialog/Popover Fokus an den aufrufenden Control zurückgeben. Flache und verschachtelte Navigationsbereiche nicht als zufällige Focus-Scopes behandeln; aktuelle Fork-Settings-/Sidebar-Architektur erhalten.

**Daten / Abhängigkeiten:** U04/U06, Fork Settings-Suche und responsive Settings-Panes (A04), P14.

**Abnahme / Tests:** Tab/Shift+Tab und Directional Arrows über Pane-Grenzen, lange Settings-Listen, Explore/Viewer sichtbare Controls, Focus Return nach Dialog/Sheet, Dynamic Layout/Routing/Scroll und große Textskalierung.

**Begründung / Upstream-Quellen:** [`a555bbb3d`](https://github.com/khoadng/Boorusama/commit/a555bbb3db20d9b8c29c3c1b7d87c2b0d8546d20), [`e95a71f85`](https://github.com/khoadng/Boorusama/commit/e95a71f85d7982a797a89b0879a42e1c55d46253), [`5f57df699`](https://github.com/khoadng/Boorusama/commit/5f57df699e940fb8256aa74bdac46d2979246141), [`58254b441`](https://github.com/khoadng/Boorusama/commit/58254b441040ec4c6187018a46c4366511e3e7f0), [`84286ddc1`](https://github.com/khoadng/Boorusama/commit/84286ddc1e3da8e7cae71783c5e21641015635ae), [`d7041c4d4`](https://github.com/khoadng/Boorusama/commit/d7041c4d42b3470c45ab4ed29bbe1e3e73093aa8), [`f31f551be`](https://github.com/khoadng/Boorusama/commit/f31f551bedd31b2c75fcddf354e682b07bae5e69). Nutzer bestätigte U05 ausdrücklich am 2026-10-16; es ist ein Planungsbeschluss ohne Code-Implementierung.

## U06 – Escape-Handling, Menu Selection und Layer-Hierarchie

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Mit einem Fork-kompatiblen `KurumiDismissible`/BackHandler oder gleichwertig eine einzige ordentliche Keyboard-Escape/Android-Back-Präzedenz für ineinanderliegende Layer aufbauen: zuerst aktives Submenü/Popup/Popover, dann Dialog/Sheet, dann Search-Editing-/Suggestion-State, anschließend aktive Selection, zuletzt Route/Screen; tatsächliche Router-/PopScope-/Modal-Grenzen (inklusive nicht dismissbarer oder Dirty-Form-State) respektieren. Nur eine Ebene pro Tastendruck schließen; Fokus bei Schließen auf Auslöser zurückgeben und Key-Events nicht an verdeckte Seiten durchreichen. Fork-Kontextmenüs, MultiSelection- und Tap-through-Schutz erhalten, mit P13-A02-Kurumi abstimmen.

**Daten / Abhängigkeiten:** U03–U05, P13, bestehende Fork-Router und `CustomContextMenuOverlay`-/`KurumiContextMenuPageController`-Erweiterungen.

**Abnahme / Tests:** Verschachteltes Submenü/Popover in Dialog/Sheet, Escape/Android Back, Selection+Search, non-dismissable Dialog, Routing mehrfacher Navigators, kein doppelt konsumiertes Escape, Focus-Return, kein Tap-through auf Post.

**Begründung / Upstream-Quellen:** [`3ff8b054e`](https://github.com/khoadng/Boorusama/commit/3ff8b054e558c77fd94a0419b33526d7e6d9c829), [`b925a581b`](https://github.com/khoadng/Boorusama/commit/b925a581bd361ca710d27a3e95c1eb315f9be62f), [`2d6d9f6e6`](https://github.com/khoadng/Boorusama/commit/2d6d9f6e6dacf60a52f8d0b62e7d27b8318b707c), [`76a8485de`](https://github.com/khoadng/Boorusama/commit/76a8485de122438d3f70c74de5c69bd1c8ea8987). Nutzer bestätigte U06 ausdrücklich am 2026-10-16; es ist ein Planungsbeschluss ohne Code-Implementierung.

## U07 – Favorite Tags auf großen Screens im Dialog statt Sheet

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** übernehmen (Fork-Labels bewahren).

**Zielzustand / technische Grenzen:** Favorite-Tag-Editor auf Phones wie bisher als Bottom Sheet mit Keyboard/Inset-Schutz und ab größerem Kurumi-Screen-Breakpoint als zentrierten Dialog mit ca. 520px Maximalbreite anzeigen. Inhalt unabhängig von Keyboardhöhe und erweiterten Optionen scrollbar machen, Add/Edit/Raw-Query und sämtliche vorhandenen Fork-Label-Optionen/Warnungen/Aktionen ohne Funktionsverlust bewahren. Konsistent mit Fork-Breakpoints und anderen Einstellungenmodals gestalten.

**Daten / Abhängigkeiten:** Fork Favorite-Tag-Management und Label-Verwaltung, U01/U04/U06.

**Abnahme / Tests:** Phone/Tablet/Desktop, Keyboard offen/zu, großer Text, wechselnde Advanced-Options und Label-Chips, fehlerhafte/duplizierte Tags, Submit/Cancel/Escape und State-Restoration.

**Begründung / Upstream-Quellen:** [`20e750618`](https://github.com/khoadng/Boorusama/commit/20e750618847bbb0a84391cca0b2440667ab18e7). Nutzer bestätigte U07 ausdrücklich am 2026-10-16; es ist ein Planungsbeschluss ohne Code-Implementierung.

## U08 – Regressionstests und Flakiness-Fixes nachziehen

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** test-only, zusammen mit Feature-Übernahme.

**Zielzustand / technische Grenzen:** Upstreams Testabsichten (Info-Badge-Hover nach P12 und Bulk-Dry-Run-/Session-Status nach D02) übernehmen, jedoch an aktuelle Fork-Widgets, APIs und bestehende kontrollierte Clock-/Completion-Signale anpassen statt unkontrollierte feste Sleeps oder flakey Polling-Schleifen zu duplizieren. Keine eigenständige UI-/Produktlogik und keine neue Persistenz durch U08; Tests erst zusammen mit den betreffenden Migrationsänderungen aktualisieren.

**Daten / Abhängigkeiten:** P12, D02, Fork-Regressionstests und Runner/Headless-Flows (A12).

**Abnahme / Tests:** Hover öffnet Preview nur über Info-Badge, schließen via Keyboard/Maus/Selection; Bulk Dry Run/Resume/Status ohne wall-clock-race, idempotente Session-Lifecycle-Tests und kontrollierte Futures/Events.

**Begründung / Upstream-Quellen:** [`71b41b8a0`](https://github.com/khoadng/Boorusama/commit/71b41b8a0f5574975f1cae673ac9cedde5b594ed). Nutzer bestätigte U08 ausdrücklich am 2026-10-16; es ist ein Planungsbeschluss ohne Code-Implementierung.

## D01 – Download Sidecars: TXT-Tags und JSON-Metadaten

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Optionales Download-Sidecar neben der tatsächlich gespeicherten Mediendatei (`<media>.txt` mit einem Tag pro Zeile oder `<media>.json` mit Tags, unverfälschter Herkunft/Site-ID sofern verfügbar, öffentlichen Quelllinks, tatsächlicher Qualität und tatsächlichem Dateinamen) implementieren. Globales Format `off` als Default; pro Bulk-Download-Task ein optionaler Override (Default/Off/TXT/JSON). Keine zusätzliche profilbezogene Einstellung. Einzel-, Bookmark- und Bulk-Downloads sowie Cache-Direktkopien über denselben sicheren, beobachtbaren Completion-Pfad integrieren. Sidecar-Daten als unveränderlichen Post-/Task-Snapshot vor dem Transfer einfrieren, damit Retry/Background-Recovery nicht auf UI-Provider angewiesen sind. Dateien ausschließlich nach bestätigter Transfer-Fertigstellung atomar publizieren; deduplizierte Tags sortiert ausgeben, vorhandene fremde/abweichende Sidecars nicht überschreiben, Konflikt als eigenständig reparierbaren Fehler anzeigen. Sidecar-Fehler dürfen die abgeschlossene Mediendatei nicht erneut herunterladen oder zerstören. Bei `skip if exists` eine vorhandene Mediendatei mitsamt Sidecar unverändert überspringen, auch wenn das Sidecar fehlt. Sensible Cookies/Auth-Header, signierte oder lokale API-/Datei-URLs nicht exportieren. Upstream-Storage/Callbacks/Recovery an Fork-Download-/Observer-/Lifecyclesystem anpassen. D07 bestimmt verbindlich die echte Site-Post-ID für Sidecar/JSON.

**Daten / Abhängigkeiten:** Erfordert voraussichtlich zusätzliche nullable Sidecar-Konfiguration in globalen Settings, Bulk-Task-/Download-Record-Snapshots und additive SQLite-Migration (Upstream Version 2); existierende DB-Records bleiben gültig. Sidecar-Status/Journaling muss Crash/Reboot/Retry ohne doppelte Abschluss-Events (D02) tragen. Keine Änderung am bestehenden Bookmark-/Post-Hive-Schema. Keine erneute lokale Media-Downloadaktion durch bloßen Sidecar-Retry.

**Abnahme / Tests:** Default Off, TXT/JSON, Einzel/Bookmark/Bulk/Video-Cache-Kopie, Skip-if-exists mit/ohne Sidecar, Sidecar-Kollision, readonly/scoped storage, disk full, Crash vor/nach Download/Sidecar-Write, Headless Background-Callback, Recovery nach Restart, Retry nur Sidecar, 0/mehrere Tags, UTF-8/Zeilenumbrüche, URL-/Credential-Redaction und Post-Origin-Identität.

**Begründung / Quellen:** [`86a16a20e`](https://github.com/khoadng/Boorusama/commit/86a16a20ee1327740316005b7946b8264fa70a19). Vom Nutzer am 2026-10-16 bestätigt; D07 ist inzwischen ebenfalls entschieden.

## D03 – Background Downloader Plugin-Update

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** Plugin-Commit nach Verifikation übernehmen.

**Zielzustand / technische Grenzen:** Upstream wechselt beim git-basierten `khoadng/background_downloader` mit unveränderter Package-Version `9.6.1` von `e8ad9f9` auf `fd67fff9ee4ad4cdf415dc3285289cad9289cefe`. Commit-Diff/Native-/API-Kompatibilität vor Übernahme prüfen. Nur bei erfolgreicher Prüfung `pubspec_overrides.yaml` und Lockfile konsistent auf den neueren Commit aktualisieren; keinesfalls alte Fork-Callbacks, Cronet-Transport/Resumption, Android-Dateirechte oder Persistenzabläufe ersetzen. Mit D01, D02 und D04 als gemeinsamer Lifecycle-Integrationstest prüfen; bei Inkompatibilität dokumentiert beim alten Pin bleiben bis zur Lösung.

**Daten / Abhängigkeiten:** Abhängigkeit/Lockfile-Git-Pin, keine geplante eigene Datenmigration. Platform-Plugin-/Native-Build-Verhalten gesondert prüfen.

**Abnahme / Tests:** Android foreground/background, App-Neustart, Pause/Resume, Retry/Cancel, Notifications, Cronet, Cache-/Sidecar-Completion, Task-IDs, Android build und iOS/Desktop soweit unterstützt.

**Begründung / Quellen:** [`669b8019f`](https://github.com/khoadng/Boorusama/commit/669b8019f80eaf8d0f40e268bbf8a29dc0808ddf). Vom Nutzer am 2026-10-16 bestätigt; D07 ist inzwischen ebenfalls entschieden.

## D04 – Download-Manager: injizierbarer Task-Client und Snapshot-Fix

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** vollständig übernehmen, Fork-Lifecycle bewahren.

**Zielzustand / technische Grenzen:** Den injizierbaren `DownloadTaskClient` für Pause/Resume/Retry/Cancel, Resumability sowie Pfad- und Dateigrößenabfragen nach Upstream-Konzept übernehmen, damit Download-Manager-Widgets und Notifier testbar sind; tatsächliches Enqueueing bleibt beim bestehenden Fork-Download-Service. Bei Task-Updates die existierende Gruppenliste vor Mutation kopieren (`[...?totalTasks[group]]`), statt alte State-Snapshots mutieren zu lassen. Doppeltes Schließen desselben Broadcast-StreamControllers abstellen: ein Provider besitzt/entsorgt den Controller; nach Upstream-Konzept optional zentraler `DownloadTaskEventIngress` veröffentlicht Ereignisse sowohl im Snapshot als auch im Stream. Fork-Retry-/Headers-/DDOS-/Notification-/Download-Activity-Integration bleibt erhalten.

**Daten / Abhängigkeiten:** Neue schmale Provider-/Task-Interface-Schicht ohne Datenbankänderung, vorhandene Task-IDs und Notification-/State-Strukturen behalten. D02 und D03 berücksichtigen.

**Abnahme / Tests:** Drei oder mehr Updates derselben Task erzeugen unveränderliche frühere Snapshots und vollständige Listener-Events, Dispose ohne double-close, Task-Ingress-Snapshot und Stream identisch, Retry/Cancel/Pause/Resume mit Fake-Client und Auth-/Bypass-Headern, parallele Updates/Grouped Tasks, FileSize-Ausfälle.

**Begründung / Quellen:** [`bd2e22c22`](https://github.com/khoadng/Boorusama/commit/bd2e22c221bcfb1a8c8c0675afbab6763a3102c9), [`90657ee4e`](https://github.com/khoadng/Boorusama/commit/90657ee4ed73f9a4bf7f2277ed1750e2f8b5d4ff). Vom Nutzer am 2026-10-16 bestätigt; D07 ist inzwischen ebenfalls entschieden.

## D05 – Anime-Pictures Bulk Download und Request-Pacing

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Bulk Downloads für Anime-Pictures aktivieren, einschließlich Site-Capability und mehrseitiger Aufträge. Upstream-Konservativpacing (etwa 1 Request/Sekunde über den relevanten API-/Download-Link-Host) ausschließlich über unseren bestehenden `ApiRequestCoordinator`/sitebezogene N01-Quota abbilden, keinen zweiten `SlidingWindowRateLimitInterceptor` installieren. Den unbefristeten `_downloadUrlCache` aus `AnimePicturesClient` entfernen, da URLs/Session-Cookies veralten; den Fork-`AnimePicturesDownloadFileUrlExtractor` mit begrenztem 5-Minuten-Cache beibehalten, aber Sessionwechsel, Retry nach Auth-Fehler und Links mit begrenzter Gültigkeit verifizieren. Ein Retry soll frische signierte URLs/Cookies beziehen können. Identität/Profil-/Following-Boundaries, bestehende Bulk-Auftrags-Persistenz und Download-UI nicht regressieren.

**Daten / Abhängigkeiten:** Site-Capability/Generated Booru-Config anpassen (Generator-Output nur nach Änderungen an Source-YAML neu erzeugen); N01-Quota priorisierte Request-Pacing/Retry-After, D02/D04 Download-Lifecycle. Keine zusätzliche eigenständige Rate-Limit-Schicht.

**Abnahme / Tests:** Bulk über mehrere Seiten, rate/429/Retry-After, Link-Expire/Session-Wechsel, Parallel-Profile, Download-Cookie-Handling, vorhandene Cache-Treffer, Cancel/Pause/Resume, Seiten-Cursor und Result-Recovery.

**Begründung / Quellen:** [`c5b79488c`](https://github.com/khoadng/Boorusama/commit/c5b79488c8d90b624cb17e8452d3b17e099be88f). Vom Nutzer am 2026-10-16 bestätigt; D07 ist inzwischen ebenfalls entschieden.

## D06 – Zerochan Bulk Download und URL-Auflösung

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Explizite Sperre für Zerochan-Bulk-Downloads entfernen, sobald URL-Auflösung stabil integriert und getestet ist. API-Detail liefert vorzugsweise explizite `full`/`large`/`medium`/`small`-URLs und Dateigröße/Format; wenn Full fehlt oder JSON defekt ist, gezielt die Post-HTML-Seite lesen; Asiachan-Detail-API zuverlässig durch HTML-Fallback ersetzen. Quellen/Hosts validieren und Fehler/Redirects, 404/410 und temporäre Auth-/Rate-Limits unterscheiden. Pro Post `Preview`, `Sample`, `Original` klar unterstützen; **wenn `Original` explizit angefordert ist, niemals stillschweigend Preview/Sample als Original ausgeben**, sondern nicht auflösbar melden. Dedup gleichzeitiger URL-Requests und kurzer 5-Minuten-Cache analog Upstream übernehmen. Pacing konservativ ca. 1 Request/1,2 Sek über Fork-`ApiRequestCoordinator`, ohne neue Sliding-Window-Interceptor-Schicht; Fork-FileName-/Metadata-/Observer-/Bulk-Lifecycle erhalten.

**Daten / Abhängigkeiten:** Erweiterte nullable Zerochan-DTO-Felder und PostData-/Adapter-Mapping, neuer Download-URL-Extractor und Source-Capabilities, Quality-basierte Single-Download-Action; N01/N03 und D02/D04 beachten. Cache nur bei gültigen URLs und an Site/Profile geknüpft.

**Abnahme / Tests:** Zerochan + Asiachan API/HTML-Responses, fehlende Original-URL, 404/410, falsche HTML-Seite/Metatags, explicit original vs. degraded variant, Preview/Sample, Redirect/Authentication/429, per-Post-Parallel-Fetch, Cache/Expiry, Dateiname/Extension/Size und Bulk Skip/Retries.

**Begründung / Quellen:** [`50980b8da`](https://github.com/khoadng/Boorusama/commit/50980b8da1368aa39a44051c78dee12dd4dff2ce). Vom Nutzer am 2026-10-16 bestätigt; D07 ist inzwischen ebenfalls entschieden.

## D08 – Favorite Tags direkt aus Storage exportieren

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** übernehmen.

**Zielzustand / technische Grenzen:** Für Favorite-Tag-Backups statt möglicherweise uninitialisiertem UI-State `ref.read(favoriteTagsProvider)` das persistente Repository über `await ref.read(favoriteTagRepoProvider.future)` und `await repo.getAll()` verwenden. Dies gilt auch für alle anderen relevanten vollständigen Backup-/Export-Flows, die derzeit direkt einen UI-Provider-Snapshot benutzen, und für Revision-/Auto-Backups. Bestehende Import-Semantik `repo.replaceAll(tags)` samt `ref.invalidate(favoriteTagsProvider)`, Versionsgrenzen und Label-/Raw-Query-Repräsentation erhalten. Explizite 'Export simple to clipboard'-UI-Funktion bleibt separat erhalten und darf nicht mit dem Full-Backup-Format verwechselt werden.

**Daten / Abhängigkeiten:** Keine Backupschema-/Persistenzmigration allein wegen D08. X03-Profile-/Import-/Recovery-Invarianten und A12 Headless-Tests berücksichtigen.

**Abnahme / Tests:** Kaltstart Full-Backup ohne Öffnen der Favorite-Tag-Page, zuvor nicht initialisiertes UI-State, mehrere Labels/Raw-Query/Unicode, Auto-/Server-/File-/Clipboard-Backup, vollständiger Roundtrip ohne doppelte Tags, Import ersetzt Tags unverändert; Provider-Invalidation nach Import.

**Begründung / Quellen:** [`f93bdf0dd`](https://github.com/khoadng/Boorusama/commit/f93bdf0dd42c5eb0e8165d9070310a2aebfa32c1). Vom Nutzer am 2026-10-16 bestätigt; D07 ist inzwischen ebenfalls entschieden.

## D07 – Quellseitige Post-IDs in Exporten statt nur int IDs

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen; Upstreams neue `{id}`-Semantik im Fork übernehmen.

**Zielzustand / technische Grenzen:** Den unter X02 beschlossenen `Post.sitePostId: String?`-Getter für die **tatsächliche ursprüngliche ID auf der Quellwebsite** bereitstellen. Bei üblichen numerischen Boorus die wirkliche Post-ID als String, bei Sankaku die numerische oder alphanumerische Original-ID aus `SankakuPostData`, bei Pixiv die ursprüngliche `illustId` statt des synthetischen, seitenbezogenen `Post.id`. Unbekannte Original-ID bleibt `null`: niemals eine generierte interne ID als echte Site-ID ausgeben. Herkunft per vorhandener Post-/Codec-Fähigkeit ableiten, ohne Core→Sankaku/Pixiv-Kopplung.

**Download-Dateinamen:** Den bestehenden Dateinamen-Token `{id}` von `post.id.toString()` auf die originale `post.sitePostId` umstellen, genauso wie Upstream. **Keinen zusätzlichen `{site_post_id}`-Token einführen.** Die bisherige Dateinamens-Rückwärtskompatibilität ist laut Nutzer nicht erforderlich, weil die Downloadfunktion im Fork kaum genutzt wurde. **Pixivs eigene Standardvorlage `{illust_id}_p{page}.{extension}` bleibt unverändert**, damit mehrere Seiten desselben Artworks eindeutige Namen erhalten. Benutzerdefinierte Pixiv-Vorlagen nur mit `{id}` können kollidieren; vorhandene Skip-/Dateikonfliktregeln müssen Überschreibungen verhindern. Ist die Site-ID unbekannt und die Vorlage braucht `{id}`, einen sicheren explizit nicht als Site-ID dargestellten Fallback-Namen verwenden oder eine verständliche Fehlermeldung liefern; niemals synthetische `Post.id` als echte ID einsetzen.

**Exports / Datenmigration:** D01-JSON-Sidecars, externe Post-Links und andere externe Metadaten, die die ursprüngliche Post-ID ausgeben, verwenden `post.sitePostId`. Das Bookmark-Backup v5 enthält die echte Sankaku-ID bereits im vollständigen `snapshot.custom.sankakuId`; Importer v4/v5, `StoredPostSnapshot`, `PostOrigin`, `BookmarkIdentity`, Profil-UUIDs, Bookmark-Gruppen und Following-Identitäten bleiben unverändert. Kein zusätzliches `Bookmark.sitePostId`, kein neuer Hive-Feldindex, kein Backup-Versionssprung; insbesondere Fork-Hive-Index 15=`snapshotSchemaVersion`, 16=`postSnapshot` erhalten (Upstream-Kollision auf Index 15 vermeiden).

**Abnahme / Tests:** `Post.sitePostId` für numerische/Alphanumerik/fehlende Site-IDs und Pixiv; `{id}`-Dateinamen bei Danbooru, Gelbooru, Sankaku, Pixiv inklusive korrekt unveränderter Pixiv-Standardnamen mehrseitiger Artworks; benutzerdefinierte Pixiv-`{id}`-Vorlagen und sichere Datei-Kollisionen; keine ungültigen generischen Namen, wenn ID fehlt; Links und D01-JSON-Sidecars liefern echte statt synthetische ID; bestehende Hive-Felder 15/16, Backup-/Restore-Versionen 4/5 und `BookmarkIdentity` durch Roundtrip ohne Datenverlust; gleiche numerische IDs verschiedener Booru-Installationen bleiben getrennt.

**Begründung / Quellen:** Upstream [`216eb6e6d`](https://github.com/khoadng/Boorusama/commit/216eb6e6d43cef2581a110b66a8f1482d110e7b9). Nutzer bestätigte nach expliziter Klärung der Auswirkungen auf Pixiv und des mangelnden Rückwärtskompatibilitätsbedarfs am 2026-10-16, `{id}` direkt auf die echte Site-ID umzustellen. Das ist eine Planungsentscheidung und **keine Freigabe zur Code-Implementierung**.

## Weitere Entscheidungen

**68/68 Themen ENTSCHIEDEN, 0 OFFEN.** Alle 68 Entscheidungen sind beschlossen. Die Entscheidungen sind **Planungsbeschlüsse, keine Implementierung**; weitere Merge-Arbeit erst nach ausdrücklicher Freigabe. U08 ist als Testpflege gemeinsam mit den betroffenen Features beschlossen.
