# Upstream v4.6.1 – Entscheidungsprotokoll

**Autoritativer Entscheidungsstand:** **53 von 68 Themen entschieden** (2026-10-16); **15 offen**, Umsetzung nicht freigegeben. Dieses Dokument enthält ausschließlich Analyse und explizit bestätigte künftige Beschlüsse. Referenz: [Katalog](boorusama-v4.6.1-entscheidungskatalog.md) und [Checkliste](boorusama-v4.6.1-checkliste.md).

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

**Verifizierte Upstream-Verwendungen:** Download-`{id}`-Token, JSON-Sidecars, Bookmark-Speichern/Restore/Export und Sankaku-Links. Getter möglichst über kleine Core-seitige Original-ID-Abstraktion, ohne Core→Sankaku-Abhängigkeit und ohne zusätzlichen Hive-Index. X01s alte Hive-Felder 15/16 bleiben verbindlich.

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

**Zielzustand / technische Grenzen:** Timberpile-Versionierung, eigene Release-History und Fork-Changelog beibehalten. Upstream-Fix für wiederkehrendes What's-New-Popup integrieren. Konkrete nächste Fork-Version erst bei Release-Planung festlegen.

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

**Gezielt übernehmen:** Aus Upstreams Headless-Refactoring die austauschbaren Plattform-, Navigation-, Dateipicker-, Repository-Factory- und Backup-Trigger-Abhängigkeiten sowie App-Flow-Tests kompatibel in den bereits beschlossenen A01-/A12-Zielzustand integrieren. Keine zweite parallele Runtime, Repository- oder Backup-Implementierung. Die Upstream-Bookmark-Library-Refresh-Ergänzung nicht zusätzlich kopieren: der Fork beobachtet `bookmarkProvider` bereits mit `BookmarkViewRefreshGate`, um Refresh/Selection korrekt zu koordinieren. Upstreams Export-Lesen von Favorite Tags direkt aus persistenter Storage statt möglicherweise uninitialisiertem UI-State ist sinnvoll, wird aber **erst im noch offenen D08 separat beschlossen**.

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

**Zielzustand / technische Grenzen:** GIF-Autoplay-Setting bei allen Grid-Qualitätsstufen einschließlich `original` respektieren: Bei deaktiviertem Autoplay nur eine statische Vorschau laden; bei aktivem Autoplay die nach Site tatsächlich verfügbare animierte URL entsprechend Qualität/Fallback wählen. Wichtig: Statische kleinere GIF-Thumbnails sind keine garantierten niedrig aufgelösten *animierten* GIF-Varianten; Danbooru liefert häufig statische 180/360/720-Varianten und die animierte Original-GIF. Eine fehlende animierte Preview nicht erfinden; im Viewer gelten dessen eigene Qualität-/Abspielregeln.

**Daten / Abhängigkeiten:** Fork-spezifische Danbooru-Variant-URL-Auflösung und generischen Thumbnail-Resolver erhalten; keine persistente Migration.

**Abnahme / Tests:** Danbooru/andere Boorus, automatische/low/high/highest/original-Qualität × autoplay/static, verfügbares/unverfügbares Sample, URL und Aspect Ratio, GIF-Animation bei deaktiviertem Autoplay im Grid.

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

**Zielzustand / technische Grenzen:** Hover-Preview nicht über die gesamte Thumbnail-Fläche, sondern über ein gezieltes Info-Badge öffnen, das bei Pointer-Hover bzw. passend fokussierter Keyboard-Navigation sichtbar wird. Gesten-/Hit-Test-Fixes für Long-Press, Right-Click und Hold-and-Drag übernehmen, Selection vor Preview-Badge priorisieren und bei Tastatureingaben Preview sauber schließen. Badge-Positionierung mit noch offenem P01 (bis zu zwei Quick Actions) und Series-Gruppenkarten abstimmen; keine neue unruhige permanente Overlay-Reihe.

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

## Weitere Entscheidungen

**53/68 Themen ENTSCHIEDEN, 15 OFFEN.** Offen sind D01, D03–D08 und U01–U08. Die Entscheidungen sind **Planungsbeschlüsse, keine Implementierung**; weitere Merge-Arbeit erst nach ausdrücklicher Freigabe. Für U08 (Testpflege) bleibt die bisherige automatische Einordnung bestehen.
