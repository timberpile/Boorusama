# Boorusama v4.6.1 – kompakte Entscheidungscheckliste

Grundlage `develop d4e1558` vs. Upstream `v4.6.1 5b04bf6`. **X01 entschieden**, alle übrigen Optionen offen, bis gemeinsam entschieden. Die vollständigen Details, Begründungen, Codestrukturen, SHA-Links und Konfliktpfade stehen in [der ausführlichen Liste](boorusama-v4.6.1-entscheidungskatalog.md).

**Legende:** Kritisch = Datenverlust/Architekturrisiko · Hoch = funktionaler Merge-Konflikt · Mittel/Niedrig = gezielter Fix · „Automatisch“ nur nach Tests.

| ID | Konkrete Änderung / Entscheidungsgegenstand | Risiko | Offizieller Beschluss |
|---|---|---|---|
| **Querschnitt: Daten und Fork-Schutz** | | | |
| `X01` | Hive-Feldindex 15: echte Schema-Kollision bei Bookmarks | 🔴 kritisch | **ENTSCHIEDEN (2026-10-15): Fork-Indizes 15/16 behalten; Original-ID bevorzugt aus Post-Daten ableiten; API-Frage X02 offen** |
| `X02` | Post-Identity/Origin vs Upstream sitePostId | 🔴 kritisch | OFFEN |
| `X03` | Fork-Export/Import, Profile-UUIDs und Following erhalten | 🔴 kritisch | OFFEN |
| `X04` | Shared Post/Image Cache und Download-Lifecycle beibehalten | 🔴 kritisch | OFFEN |
| **Architektur / Plattform / Settings** | | | |
| `A01` | App-Bootstrap, Runtime und Dependency Injection | 🔴 kritisch | OFFEN |
| `A02` | Kurumi / Material-Cupertino-Paketmigration | 🟠 hoch | OFFEN |
| `A03` | Kurumi-Stabilität, Animationen und Overflow | 🟡 mittel | OFFEN |
| `A04` | Responsives Settings-Navigationsmodell | 🟠 hoch | OFFEN |
| `A05` | Upstream Settings Search wurde hinzugefügt und wieder revertiert | ⚪ niedrig | — (vorerst kein Review) |
| `A06` | App-Lock: abweichende Privacy-Defaults | 🟠 hoch | OFFEN |
| `A07` | Debug-Logging, Logspeicherung und Redaction | 🟠 hoch | OFFEN |
| `A08` | Typisierte Cloudflare-/DDoS-Diagnostics | 🟡 mittel | OFFEN |
| `A09` | Android-Cachepfade und DocumentsProvider | 🟡 mittel | OFFEN |
| `A10` | Windows Embedded WebView, WebView-Plattformfähigkeit | 🟠 hoch | OFFEN |
| `A11` | Lokalisierung: Arabisch, Indonesisch, weitere Updates | 🟡 niedrig–mittel | OFFEN |
| `A12` | Headless Test-Harness und App-Flow-Tests | 🟠 mittel–hoch | OFFEN |
| `A13` | NixOS-Paket und Development Shell | ⚪ niedrig | OFFEN |
| `A14` | Release CI, native Assets, SDK und Build CLI | 🟠 hoch | OFFEN |
| `A15` | APK-Signing: permanenter Upstream-Key | 🔴 kritisch | OFFEN |
| `A16` | Versionierung, Changelog und What’s-New-Popup | 🟡 mittel | OFFEN |
| `A17` | Formatierung, Reverts ohne Nettoeffekt, Kleinst-Cleanup | ⚪ niedrig | — (vorerst kein Review) |
| `A18` | AVIF-Decoder-Kompatibilität im Web | 🟡 mittel | OFFEN |
| **Netzwerk / Cloudflare** | | | |
| `N01` | HTTP-Retry-After, Rate-Limiter und Admission-Locks | 🟠 hoch | OFFEN |
| `N02` | Per-Profile Media-Host-Overrides | 🟠 hoch | OFFEN |
| `N03` | Cloudflare: state-changing Requests nicht blind erneut senden | 🟠 hoch | OFFEN |
| `N04` | Cloudflare-Erkennung, Blockseiten, Redirects und Challenge-UX | 🟠 hoch | OFFEN |
| `N05` | Clearance-Cookie und native WebView-Cookie-Bridge | 🟠 hoch | OFFEN |
| `N06` | HTTP/2-Window und automatisches Gzip | 🟡 mittel | OFFEN |
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

**Reihenfolge:** Start X01 → X02 → A01 → X03 → X04 → A15; anschließend Funktionalität/UX nach Absprache.

**Ergebnisschlüssel:** übernehmen · angepasst übernehmen · Fork beibehalten · nicht übernehmen.