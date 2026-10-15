# Boorusama v4.6.1 – kompakte Entscheidungscheckliste

Grundlage `develop d4e1558` vs. Upstream `v4.6.1 5b04bf6`. **27/68 Themen entschieden, 41 offen** (2026-10-15). Beschlüsse dokumentieren Zielverhalten, noch keine Implementierung. Die vollständigen Details, Begründungen, Codestrukturen, SHA-Links und Konfliktpfade stehen in [der ausführlichen Liste](boorusama-v4.6.1-entscheidungskatalog.md).

**Legende:** Kritisch = Datenverlust/Architekturrisiko · Hoch = funktionaler Merge-Konflikt · Mittel/Niedrig = gezielter Fix · „Automatisch“ nur nach Tests.

| ID | Konkrete Änderung / Entscheidungsgegenstand | Risiko | Offizieller Beschluss |
|---|---|---|---|
| **Querschnitt: Daten und Fork-Schutz** | | | |
| `X01` | Hive-Feldindex 15: echte Schema-Kollision bei Bookmarks | 🔴 kritisch | **ENTSCHIEDEN (2026-10-15): Fork-Indizes 15/16 behalten; Original-ID bevorzugt aus Post-Daten ableiten; X02-Getter ebenfalls beschlossen** |
| `X02` | Post-Identity/Origin vs Upstream sitePostId | 🔴 kritisch | **ENTSCHIEDEN (2026-10-15):** Post.sitePostId als gemeinsamen String?-Getter einführen. Für numerische Boorus die originale numerische ID als String, für Sankaku die ggf. alphanumerische Original-ID aus SankakuPo… |
| `X03` | Fork-Export/Import, Profile-UUIDs und Following erhalten | 🔴 kritisch | OFFEN |
| `X04` | Shared Post/Image Cache und Download-Lifecycle beibehalten | 🔴 kritisch | **ENTSCHIEDEN (2026-10-15):** Den gemeinsamen persistenten Fork-Image-Cache mit URL-MD5-Hash, Origin-Isolation, LRU, Quotas, Journal, Checkpoints und Performance-Fixes behalten. Physische .generation_-Dateien und… |
| **Architektur / Plattform / Settings** | | | |
| `A01` | App-Bootstrap, Runtime und Dependency Injection | 🔴 kritisch | **ENTSCHIEDEN (2026-10-15):** Upstream-Bootstrap/Runtime/Dependency Injection (BoorusamaBootstrapHost, Production-Bootstrap, Runtime, AppScope, External Effects) als führenden einzigen Startup-Pfad übernehmen; AL… |
| `A02` | Kurumi / Material-Cupertino-Paketmigration | 🟠 hoch | **ENTSCHIEDEN (2026-10-15):** Kurumi-/Material-Cupertino-Migration, KurumiLikeButton, LinearProgressIndicator, PulseIndicator, PageIndicator und Kurumi-Kontextmenüs übernehmen; kein zusätzliches Redesign. ALLE Fo… |
| `A03` | Kurumi-Stabilität, Animationen und Overflow | 🟡 mittel | **ENTSCHIEDEN (2026-10-15):** Upstreams Kurumi-Fixes für Menüs, Fokus, Escape, Animationen, Overflow und Stabilität übernehmen; eigene Actions/Selection-Gesten nicht verlieren. |
| `A04` | Responsives Settings-Navigationsmodell | 🟠 hoch | **ENTSCHIEDEN (2026-10-15):** Upstreams responsive Settings-Navigation (neuer State, Unterseiten, Sidebar, kleine visuelle Änderungen) übernehmen. Vorhandene Fork-Settings Search, neue Kategorien/Einstellungen un… |
| `A05` | Upstream Settings Search wurde hinzugefügt und wieder revertiert | ⚪ niedrig | **ENTSCHIEDEN (2026-10-15):** Die kurzzeitig eingeführte und in Upstream v4.6.1 wieder entfernte Settings Search ignorieren. Ausschließlich die bestehende Fork-Settings-Search behalten. Grund für Revert ist nicht… |
| `A06` | App-Lock: abweichende Privacy-Defaults | 🟠 hoch | **ENTSCHIEDEN (2026-10-15):** Upstream-Defaults übernehmen: App-Preview-Blur/Hide-App-Preview false, Lock-Timeout 30 Sekunden. Bestehende vom Nutzer gespeicherte Werte beim Upgrade respektieren. |
| `A07` | Debug-Logging, Logspeicherung und Redaction | 🟠 hoch | **ENTSCHIEDEN (2026-10-15):** Upstreams persistentes Logging, Logansicht, Copy/Export, aktuelle Redaction-Defaults und übrige Konfiguration 1:1 integrieren. Keine vorgezogene Änderung an Privacy-/Redaction-Defaul… |
| `A08` | Typisierte Cloudflare-/DDoS-Diagnostics | 🟡 mittel | **ENTSCHIEDEN (2026-10-15):** Upstreams typisierte Cloudflare-/DDoS-Diagnostics mit ausführlichen Challenge-/Solver-Status- und Fehlerereignissen in A07-Logging integrieren; Rule34-Fork-Recovery erhalten. |
| `A09` | Android-Cachepfade und DocumentsProvider | 🟡 mittel | **ENTSCHIEDEN (2026-10-15):** Upstreams Cache-Locations-Settings und schreibgeschützten Android-DocumentsProvider übernehmen. Nur gültige, fertig gespeicherte Image-/Video-Cachedateien zeigen; keine Indizes, Part… |
| `A10` | Windows Embedded WebView, WebView-Plattformfähigkeit | 🟠 hoch | **ENTSCHIEDEN (2026-10-15):** Windows-Embedded-WebView, Browser-Factories, WinHTTP und Unsupported-Platform-Fallbacks übernehmen; vorhandenes Fork-Cloudflare-/Browserverhalten bewahren. |
| `A11` | Lokalisierung: Arabisch, Indonesisch, weitere Updates | 🟡 niedrig–mittel | **ENTSCHIEDEN (2026-10-15):** Upstream-Sprachen/Übersetzungen einschließlich Arabisch, Indonesisch, Language-Switch-Fixes integrieren, ohne die zusätzlich im Fork eingeführten Keys/Strings oder Fallbacks zu verli… |
| `A12` | Headless Test-Harness und App-Flow-Tests | 🟠 mittel–hoch | **ENTSCHIEDEN (2026-10-15):** Upstreams Headless-App-Test-Harness, Fake-Services und App-Flow-Tests mit A01-Runtime integrieren. Eigene Fork-Tests erhalten. Für visuelle/gestische A02-Abnahme schreibt Agent nur N… |
| `A13` | NixOS-Paket und Development Shell | ⚪ niedrig | **ENTSCHIEDEN (2026-10-15):** NixOS-Flake, Entwicklungsshell und Paketierung nur soweit wartbar/kompatibel übernehmen; keine neue offizielle Release-Verpflichtung oder zusätzliche Wartungsinfrastruktur. |
| `A14` | Release CI, native Assets, SDK und Build CLI | 🟠 hoch | **ENTSCHIEDEN (2026-10-15):** Nützliche Upstream-CI-/native Assets-/SDK-/Build-CLI-Fixes übernehmen. Fork-Flavors, split-APKs, bestehende CI/Release-Workflows und Flutter-3.47.2-Pinning erhalten; zurückgenommene … |
| `A15` | APK-Signing: permanenter Upstream-Key | 🔴 kritisch | **ENTSCHIEDEN (2026-10-15):** Fork-App-ID com.timberpile.boorusama, Flavors, bestehende Release-Signatur, Keystore, Update-Manifest und Upgrade-Kompatibilität unverändert lassen. Upstream-Key keinesfalls übernehm… |
| `A16` | Versionierung, Changelog und What’s-New-Popup | 🟡 mittel | **ENTSCHIEDEN (2026-10-15):** Timberpile-Versionierung, eigene Release-History und Fork-Changelog beibehalten. Upstream-Fix für wiederkehrendes What's-New-Popup integrieren. Konkrete nächste Fork-Version erst bei… |
| `A17` | Formatierung, Reverts ohne Nettoeffekt, Kleinst-Cleanup | ⚪ niedrig | **ENTSCHIEDEN (2026-10-15):** Formatierungs-, Cleanup- und effektlose/revertierte Upstream-Änderungen ohne Produktentscheidung behandeln. Nur notwendige Lint-/Format-Fixes; unnötige Diffs und Wiederbelebung rever… |
| `A18` | AVIF-Decoder-Kompatibilität im Web | 🟡 mittel | **ENTSCHIEDEN (2026-10-15):** AVIF-Web-/Network-Decoder-Korrekturen übernehmen, bestehende AVIF-/Extended-Image-/Fork-Cache-Pipeline erhalten. |
| **Netzwerk / Cloudflare** | | | |
| `N01` | HTTP-Retry-After, Rate-Limiter und Admission-Locks | 🟠 hoch | **ENTSCHIEDEN (2026-10-15):** Fork-ApiRequestCoordinator behalten: zentrale Origin-Quotas, parallele In-Flight-Limits, interaktive Priorität, Following/Preload/Bulk-Pacing und 429-Cooldowns. Upstreams Sliding-Win… |
| `N02` | Per-Profile Media-Host-Overrides | 🟠 hoch | **ENTSCHIEDEN (2026-10-15):** Media-Host-Overrides pro Profil inkl. UI für Bilder/Videos/Downloads übernehmen. Header/Cookies/Auth NICHT ohne kontrollierte Origin-Grenzen zum Ersatzhost weitergeben; Source-/Profi… |
| `N03` | Cloudflare: state-changing Requests nicht blind erneut senden | 🟠 hoch | **ENTSCHIEDEN (2026-10-15):** Upstream-Schutz vor blindem Wiederholen mutierender Requests nach Cloudflare-Challenge übernehmen. POST/PUT, Votes, Favorites, Comments nur bei explizit sicherer Idempotenz erneut se… |
| `N04` | Cloudflare-Erkennung, Blockseiten, Redirects und Challenge-UX | 🟠 hoch | **ENTSCHIEDEN (2026-10-15):** Upstream Cloudflare-Challenge-Erkennung, Blockseiten, Captcha-Bestätigung, Subdomain-Redirects, Loop-Vermeidung und Dialog-UX übernehmen; Fork Rule34-403-Recovery erhalten. |
| `N05` | Clearance-Cookie und native WebView-Cookie-Bridge | 🟠 hoch | **ENTSCHIEDEN (2026-10-15):** Upstream-WebView→HTTP-Cookie-Bridge Android/iOS/macOS übernehmen, ohne Fork-App-ID, Native Channels, Cookie-Origin-/Secure-/HttpOnly-Grenzen zu beeinträchtigen. |
| `N06` | HTTP/2-Window und automatisches Gzip | 🟡 mittel | **ENTSCHIEDEN (2026-10-15):** HTTP/2-Window- und Gzip-Verbesserungen übernehmen; Fork-Priorisierung, HTTP1-/Plattform-Fallback und mobile Speichergrenzen erhalten. |
| **Downloads / Backup** | | | |
| `D01` | Download Sidecars: TXT-Tags und JSON-Metadaten | 🟠 hoch | OFFEN |
| `D02` | Bulk-Download-Finalisierung und Benachrichtigungen | 🔴 kritisch | OFFEN |
| `D03` | Background Downloader Plugin-Update | 🟡 niedrig–mittel | OFFEN |
| `D04` | Download-Manager: injizierbarer Task-Client und Snapshot-Fix | 🟡 mittel | OFFEN |
| `D05` | Anime-Pictures Bulk Download und Request-Pacing | 🟡 mittel | OFFEN |
| `D06` | Zerochan Bulk Download und URL-Auflösung | 🟡 mittel | OFFEN |
| `D07` | Quellseitige Post-IDs in Exporten statt nur int IDs | 🟠 hoch | OFFEN |
| `D08` | Favorite Tags direkt aus Storage exportieren | 🟡 mittel | OFFEN |
| **Booru-Kompatibilität** | | | |
| `B01` | Sankaku-Metatags, Syntax-Highlighting und typed Suggestions | 🟠 mittel–hoch | OFFEN |
| `B02` | Sankaku-Exclusion und Datumsfilter normalisieren | 🟡 mittel | OFFEN |
| `B03` | Sankaku-Tag-Kategorien vollständig erhalten, Duplikate entfernen | 🟡 mittel | OFFEN |
| `B04` | Sankaku-Auth: API-Header, invalid credentials, Session-Recovery | 🟠 hoch | OFFEN |
| `B05` | Sankaku-Suchlimits korrekt erklären | ⚪ niedrig | OFFEN |
| `B06` | Shimmie2: Medienformate und Favorite-Fallback | 🟡 mittel | OFFEN |
| `B07` | Gelbooru v2: Kommentar-Voting und Cursor-Pagination | 🟠 mittel–hoch | OFFEN |
| `B08` | Gelbooru v2: Kommentar-Sortierung | 🟡 mittel | OFFEN |
| `B09` | Nozomi: korrekte Tag-Counts und HTTP-Range-Encoding | 🟡 niedrig–mittel | OFFEN |
| `B10` | Rule34: JSON-Post-API auf api.rule34.xxx | 🟠 hoch | OFFEN |
| **Post / Grid / Viewer** | | | |
| `P01` | Zwei Quick Actions auf Post-Thumbnails | 🟠 hoch | OFFEN |
| `P02` | Profile mit unbekannten Thumbnail-Actions/Media-Host-Regeln behalten | 🟠 hoch | OFFEN |
| `P03` | Bildladefehler: Tap-to-Retry nur bei passenden Error-Widgets | 🟡 mittel | OFFEN |
| `P04` | Post-Grid: Refresh während laufendem Fetch nicht verlieren | 🟡 mittel | OFFEN |
| `P05` | Bookmark-Library nach Bookmark-Mutation aktualisieren | 🟡 mittel | OFFEN |
| `P06` | GIF-Autoplay respektiert Qualitätseinstellungen | 🟡 niedrig–mittel | OFFEN |
| `P07` | Video-Thumbnail bis zum ersten gerenderten Frame anzeigen | 🟡 mittel | OFFEN |
| `P08` | WebView-Video aus Cache-Datei und Cleanup-Schutz | 🟠 hoch | OFFEN |
| `P09` | Kurumi InteractiveViewer: Bild-Pan vs Page-Swipe | 🟠 hoch | OFFEN |
| `P10` | Volume Keys im Post Viewer korrekt konsumieren | 🟡 niedrig–mittel | OFFEN |
| `P11` | Videosteuerung: Zeit-Overflow und Media-Play/Pause-Key | 🟡 niedrig–mittel | OFFEN |
| `P12` | Hover Preview nur über Info-Badge öffnen; Long Press erhalten | 🟠 hoch | OFFEN |
| `P13` | Post-/Tag-Kontextmenüs auf Kurumi migrieren | 🟠 hoch | OFFEN |
| `P14` | Keyboard-Fokus auf Quick Favorite/Bookmark-Buttons | 🟡 mittel | OFFEN |
| **Suche / Bedienung / Desktop** | | | |
| `U01` | Suche oberhalb Soft-Keyboard bedienbar | 🟠 hoch | OFFEN |
| `U02` | Search History als Full-Height-Sheet + Tests | 🟡 mittel | OFFEN |
| `U03` | Tag-Suggestions per Tastatur fokussieren und hervorheben | 🟠 hoch | OFFEN |
| `U04` | TV-Remote- und Tastaturnavigation auf gesamter App | 🟠 mittel–hoch | OFFEN |
| `U05` | Desktop Tab-Reihenfolge und Fokusgrenzen | 🟡 mittel | OFFEN |
| `U06` | Escape-Handling, Menu Selection und Layer-Hierarchie | 🟠 mittel–hoch | OFFEN |
| `U07` | Favorite Tags auf großen Screens im Dialog statt Sheet | 🟡 niedrig–mittel | OFFEN |
| `U08` | Regressionstests und Flakiness-Fixes nachziehen | ⚪ niedrig | — (vorerst kein Review) |

**Fortsetzung:** X03 und D01–D08; danach Booru-/Viewer-/UX-Themen. A02-Manuellcheckliste durch Agent **erstellen**, vom Nutzer **ausführen**.

**Ergebnisschlüssel:** übernehmen · angepasst übernehmen · Fork beibehalten · nicht übernehmen.