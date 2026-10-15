# Upstream v4.6.1 – Entscheidungsprotokoll

**Autoritativer Entscheidungsstand:** **X01 entschieden** (2026-10-15); alle übrigen Themen weiterhin offen. Dieses Dokument enthält ausschließlich Analyse und explizit bestätigte künftige Beschlüsse. Referenz: [Katalog](boorusama-v4.6.1-entscheidungskatalog.md) und [Checkliste](boorusama-v4.6.1-checkliste.md).

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

**Abhängigkeit:** X02 entscheidet über eine gemeinsame `sitePostId`-API beziehungsweise die genaue Quell-ID-Auflösung. X01 legt das persistente Schema fest, nicht bereits die Implementierung von X02.

**Begründung:** Direkte Übernahme der Upstream-Indexbelegung würde das bestehende Fork-Schema mit einem inkompatiblen Datentyp kollidieren lassen. Bereits gespeicherte Original-IDs sollen wiederverwendet werden. Vom Nutzer am 2026-10-15 bestätigt.

### Verifikation

- Unveränderte Lese-/Schreibbarkeit existierender Fork-Hive-Dateien (Indizes 15/16).
- Nichtnumerische Sankaku-ID bleibt über Bookmark → Backup/Restore → Link/Export/Dateinamen exakt erhalten.
- Identische numerische Post-IDs auf unterschiedlichen Sites kollidieren nicht.
- Altes/upstream-kompatibles Backup und ungültige/fehlende Quell-ID sicher behandeln.

## X02 – Post-Identity / Herkunft

**Status: OFFEN · X01 hat die bestehenden Hive-Indizes verbindlich festgelegt.**

Zu klären: `PostOrigin`, `BookmarkIdentity`, `SankakuPostData` und das benötigte `sitePostId`-API so integrieren, dass Quell-IDs erhalten bleiben, ohne Fork-Identität oder Post-Snapshots zu destabilisieren.

## Weitere Entscheidungen

Die übrigen **67 Themen** (einschließlich X02) sind **OFFEN**. In der [Checkliste](boorusama-v4.6.1-checkliste.md) stehen die IDs in der vorgesehenen Reihenfolge; zukünftige bestätigte Beschlüsse werden hier ergänzt.
