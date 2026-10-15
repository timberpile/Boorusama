# Upstream v4.6.1 – Entscheidungsprotokoll

**Autoritativer Entscheidungsstand:** Noch **keine** Übernahme-/Ablehnungsentscheidung bestätigt. Dieses Dokument enthält ausschließlich Analyse und explizit bestätigte künftige Beschlüsse. Referenz: [Katalog](boorusama-v4.6.1-entscheidungskatalog.md) und [Checkliste](boorusama-v4.6.1-checkliste.md).

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

**Status: OFFEN · im Gespräch · Stand 2026-10-15.**

### Verifiziertes technisches Verhalten

- Upstream `Post.sitePostId` bezeichnet die **unveränderte Original-Post-ID der jeweiligen Website als String**, unabhängig von `Post.id` (numerische/interne ID).
- Relevant besonders für Sankaku: Die Original-ID kann alphanumerisch sein; der Dart-`int`-Wert ist dann nur eine erzeugte interne ID. Bei üblichen numerischen Sites entspricht `sitePostId` meist `post.id.toString()`.
- Upstream nutzt `sitePostId` für den Bookmark-Datensatz und dessen Export, den originalen Link beziehungsweise die ursprüngliche ID, Download-Dateinamen und optionale Metadata-Sidecars.
- Im Fork speichert `SankakuPostData` bereits die Sankaku-Original-ID; `StoredPostSnapshot` persistiert diese via `postSnapshot`. `PostOrigin` enthält die Herkunft, `BookmarkIdentity` einen standortbezogenen Post-Schlüssel.
- **Persistenzkollision:** Fork Hive-Index `15 = snapshotSchemaVersion` (`int`), Index `16 = postSnapshot` (Map); Upstream Index `15 = sitePostId` (`String?`). Ein direkt übernommener Adapter kann vorhandene Daten falsch interpretieren.

### Diskussionsgrundlage (keine Entscheidung)

1. Vorhandene Hive-Indizes **15 und 16 erhalten**, nicht überschreiben.
2. `sitePostId` als Ableitung aus der originären Post-Datenstruktur prüfen und mit X02 zusammen entscheiden.
3. Nur falls persistente Ergänzung nötig: freien Hive-Feldindex verwenden, ältere Daten sicher migrieren und Testfixtures für beide Schemata vorsehen.
4. Der interne, eventuell künstliche `int`-Wert darf die echte externe ID weder in Exporten noch beim Erstellen von Links oder Dateinamen ersetzen.

**Noch offen:** Ist eine zusätzliche Hive-Persistierung nötig, oder reicht die schon gespeicherte Quell-ID im Fork-Snapshot? Endgültige Entscheidung gemeinsam mit X02.

### Verifikation

- Unveränderte Lese-/Schreibbarkeit existierender Fork-Hive-Dateien (Indizes 15/16).
- Nichtnumerische Sankaku-ID bleibt über Bookmark → Backup/Restore → Link/Export/Dateinamen exakt erhalten.
- Identische numerische Post-IDs auf unterschiedlichen Sites kollidieren nicht.
- Altes/upstream-kompatibles Backup und ungültige/fehlende Quell-ID sicher behandeln.

## X02 – Post-Identity / Herkunft

**Status: OFFEN · anschließend gemeinsam mit X01 entscheiden.**

Zu klären: `PostOrigin`, `BookmarkIdentity`, `SankakuPostData` und das benötigte `sitePostId`-API so integrieren, dass Quell-IDs erhalten bleiben, ohne Fork-Identität oder Post-Snapshots zu destabilisieren.

## Weitere Entscheidungen

Alle übrigen 66 Themen sind **OFFEN**. In der [Checkliste](boorusama-v4.6.1-checkliste.md) stehen die IDs in der vorgesehenen Reihenfolge; zukünftige bestätigte Beschlüsse werden hier ergänzt.
