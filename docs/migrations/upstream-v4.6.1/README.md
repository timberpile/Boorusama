# Upstream v4.6.1 – Merge-Entscheidungen

**Status: PLANUNG / NICHT IMPLEMENTIERT.** Dieser Ordner dokumentiert die gewünschten Ergebnisse eines künftigen echten Merges von `khoadng/Boorusama v4.6.1` in `timberpile/Boorusama`. Der Branch dient zunächst nur dazu, die Analyse und sämtliche expliziten Entscheidungen dauerhaft und nachvollziehbar zu sichern.

## Fixierte Vergleichsbasis

- Unser `develop`: `d4e15586f06192f0ff4315d36a3f61ae69a752d5`
- Upstream-Tag `v4.6.1` (Commit): `5b04bf6a164f028d41701299367d0dde74dde330`
- Gemeinsamer Vorfahr: `2c0ac699184854d363833ea4a3205aef0895a92b`
- Umfang: 150 neue Upstream-Commits, 68 Themen, 106 Konfliktpfade beim unveränderten Test-Merge.
- Ein früherer lokaler Trial Merge war **nicht** build-/testverifiziert und ist **kein** akzeptierter Integrationsstand.

## Dokumente

1. [Detaillierter Entscheidungskatalog](boorusama-v4.6.1-entscheidungskatalog.md) – alle Änderungen, Fork-Abweichungen, Konflikte, SHA-Belege, Tests und noch unverbindliche Empfehlungen.
2. [Kompakte Checkliste](boorusama-v4.6.1-checkliste.md) – stabile IDs (X01–X04, A01–A18, N01–N06, D01–D08, B01–B10, P01–P14, U01–U08).
3. [Entscheidungsprotokoll](decisions.md) – **verbindliche Quelle für explizit vom Nutzer bestätigte Beschlüsse** und Gesprächsnotizen.

## Regeln für die Besprechung

- Jede ID bleibt stabil. Diskussionen werden in `decisions.md` dokumentiert, bevor sie als Entscheidung gelten.
- `OFFEN` bedeutet **nicht freigegeben**. Eine Arbeitshypothese im Katalog darf ein Agent nicht als Entscheidung interpretieren.
- Pro abgeschlossener Entscheidung: ID, Beschluss (vollständig / angepasst / Fork behalten / nicht übernehmen), konkretes Zielverhalten, Begründung, Abhängigkeiten, Datenmigration, Verifikation und Datum notieren.
- Nach bestätigter Entscheidung die Checkliste ergänzen; bei Widersprüchen gilt das explizit bestätigte Entscheidungsprotokoll. Entscheidungen nicht ohne neue Rücksprache umdeuten.
- Implementierende Agents erhalten erst nach Freigabe einen Merge-Auftrag. Nicht beschlossene Themen bleiben unangetastet beziehungsweise müssen erneut vorgelegt werden.
- **Schutzinvarianten:** Profile/UUIDs, Bookmarks/Hive, Post-Identität, Export/Import, Following/Pinned Searches, Cache, eigene UI, Signing/Privacy-Defaults. Veränderungen an persistenten Daten nur mit explizitem Migrationsdesign und Regressionstests.
- Den echten Upstream-Merge **nicht** per `-s ours` simulieren; Git-Ancestry soll die tatsächlich integrierte Arbeit widerspiegeln.
- Keine Änderungen oder PRs nach `develop` ohne separate Freigabe. Vollständige Testsuite nach `AGENTS.md` vor Integration.

## Entscheidungsstand (2026-10-16)

**61 von 68 Themen beschlossen, 7 noch offen.** Alle 61 Entscheidungen stehen verbindlich in [decisions.md](decisions.md), zusammengefasst in Katalog und Checkliste. **Es wurde noch kein Upstream-Code integriert und keine Umsetzung freigegeben.**

- **A02:** Implementierender Agent schreibt nach dem UI-Umbau die wichtigsten manuellen Testfälle für den Nutzer; führt diese nicht selbst manuell durch.
- **X04 + A09:** Cache-Generationen entfernen, URL-MD5/LRU/Checkpoints behalten; OS-Temp-Share-Kopie und vorhandenes >24h-Cleanup verwenden; Upstream read-only DocumentsProvider übernehmen.
- **N01:** `ApiRequestCoordinator` behalten, Upstream-Retry-Fixes ohne zweiten Sliding-Window-Limiter übernehmen.
- **X03:** Fork-Profile-UUIDs, Import/Export, Bookmark-/Pinned-Ordner und Following schützen; kompatible Test-/Factory-Boundaries über A01/A12; Favorite-Tag-Storage-Fix separat bei D08.
- **D02:** Upstream-Completion-Fixes angepasst übernehmen, Fork-Lifecycle-Guards bewahren; Crash-/Cleanup-Recovery und Notification-Deduplizierung verifizieren.
- **B01–B05:** Sankaku-Metatags in gemeinsame Search-UX integrieren, Datums-/Fehler-/Tag-Kategorie-Fixes sowie sichere Auth-Recovery adaptieren.
- **B06:** Shimmie2-Media-/Favorite-Fixes mit nicht-blockierendem Favorite-Status.
- **B07–B08:** Rule34-Kommentar-Upvotes (keine Downvotes), Cursor-Pagination und capability-bedingte Sortierung übernehmen.
- **B09–B10:** Nozomi-Index-/Range-Fixes mit Request-Koordination; Rule34-API-Host erst nach Live-Verifikation umstellen.
- **P01–P14:** Alle 14 Post/Grid/Viewer-Migrationsthemen beschlossen. P01-Zwei-Actions-UI integriert pro-Post-Fork-`defaultActionButton` samt Legacy-Migration. P06 lässt Danbooru-Highest-Sample-GIFs bei aktiviertem Autoplay animiert, bei deaktiviertem statisch; Automatic-Large ist derzeit ein eigener 720-Variantpfad. Besonders P04: bestehende Refresh-Queue behalten, stale Ergebnisse verwerfen; P08: gecachte Videos und temporäre Seiten während Playback schützen; P09: Swipe/Pan-Gesten ohne Verlust der Fork-Zoom-Funktionen; P10: Lautstärketasten nur bei aktivem Viewer-Modus konsumieren.
- **U01–U03:** Soft-Keyboard-Layout, scrollkontrollierte Search History und Keyboard-Suggestion-Listbox in die neue kompakte Fork-Suchoberfläche integrieren.
- **U04–U06:** Einheitliches Keyboard-/D-Pad-Focus-Handling, Focus-Panes und Escape/Back-Layer-Priorität mit Fork-Navigation verbinden; TV nur Best-Effort.
- **U07–U08:** Favorite-Tag-Dialog ab Tabletbreite, volle Fork-Labels erhalten; Upstream-Regressionstests nur zusammen mit Features und kontrollierten Clocks übernehmen.
- **P06-Limit:** Animierte GIFs einschließlich Danbooru-Samples nur bei aktivem GIF-Autoplay und bekanntem Original-`fileSize` ≤ 5 MiB automatisch im Grid laden, sonst statisch (auch Highest); Viewer/Downloads unberührt.

## Fortschritt

- [x] Basis-SHAs, Katalog und Checkliste gesichert
- [x] X01: Fork-Hive-Indizes 15/16 behalten; Quell-IDs nach Möglichkeit ableiten
- [x] X02: gemeinsamer `sitePostId`-Getter, Hive/Identität unverändert
- [x] X03: Fork-Daten-/Identitätsinvarianten, Headless-Boundaries und Bookmark-Refresh geklärt
- [x] X04: vereinfachter URL-MD5-Image-Cache ohne `generation_`; Temp-Share-Kopien
- [x] A01–A18: Upstream-/Fork-Zielverhalten beschlossen
- [x] N01–N06: Netzwerk-Zielverhalten beschlossen
- [x] D02: Bulk-Download-Finalisierung und Notification-Schutz entschieden
- [ ] D01, D03–D08: übrige Backup-/Download-Punkte entscheiden
- [x] B01–B10: Booru-Kompatibilität vollständig entschieden (Implementierung ausstehend)
- [x] P01–P14: alle 14 Viewer-/Grid-Themen entschieden (Implementierung ausstehend)
- [x] U01–U08: Suche/Keyboard/Desktop/TV sowie Testpflege entschieden (Implementierung ausstehend)
- [ ] Alle nichttrivialen Punkte entschieden
- [ ] Merge-Resolution gegen finalen Plan implementiert
- [ ] Datenmigrationen und vollständige Regressionstests bestanden
- [ ] Integration in `develop` freigegeben
