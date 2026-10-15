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

## Fortschritt

- [x] Basis-SHAs, Katalog und Checkliste gesichert
- [x] X01: Fork-Hive-Indizes 15/16 behalten; Quell-IDs nach Möglichkeit ableiten
- [ ] X02: Post-Identity und gemeinsames `sitePostId`-API entscheiden
- [ ] Alle nichttrivialen Punkte entschieden
- [ ] Merge-Resolution gegen finalen Plan implementiert
- [ ] Datenmigrationen und vollständige Regressionstests bestanden
- [ ] Integration in `develop` freigegeben
