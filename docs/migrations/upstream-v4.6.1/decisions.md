# Upstream v4.6.1 – Entscheidungsprotokoll

**Autoritativer Entscheidungsstand:** **29 von 68 Themen entschieden** (2026-10-15); **41 offen**, Umsetzung nicht freigegeben. Dieses Dokument enthält ausschließlich Analyse und explizit bestätigte künftige Beschlüsse. Referenz: [Katalog](boorusama-v4.6.1-entscheidungskatalog.md) und [Checkliste](boorusama-v4.6.1-checkliste.md).

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

## Weitere Entscheidungen

**29/68 Themen ENTSCHIEDEN, 39 OFFEN.** Offen sind D01, D03–D08, B01–B10, P01–P14 und U01–U08. Die Entscheidungen sind **Planungsbeschlüsse, keine Implementierung**; weitere Merge-Arbeit erst nach ausdrücklicher Freigabe. Für U08 (Testpflege) bleibt die bisherige automatische Einordnung bestehen.
