# Bookmark-Gruppen-Update ändert ausschließlich den Inhalt

Priority: Normal
Affected feature: Bookmark-Import / Gruppen-Update und Änderungsvorschau

## Problem und Ziel

Das Update einer bestehenden Bookmark-Gruppe übernimmt aktuell auch den importierten Namen. Der Nutzer erwartet ausdrücklich, dass Bookmark group Update NUR den Inhalt ändert, niemals den lokalen Namen. Dies erhält auch eine vom Empfänger gewählte virtuelle Ordnerplatzierung wie `Cookie//Artists`.

## Akzeptanzkriterien

- Update einer bestehenden Gruppe behält deren UUID und lokalen Namen exakt bei; nur der Gruppeninhalt wird gemäß den vorhandenen Update-Regeln aktualisiert.
- Beispiel: Eingehend `Artists`, lokal `Cookie//Artists`, gleiche UUID. Update ersetzt die Mitgliedschaften, behält aber `Cookie//Artists`.
- Die Vorschau zeigt denselben erhaltenen lokalen Namen und plant keine Umbenennung. Vorschau, Apply und vorhandene Identitäts-/Rollback-Regeln bleiben konsistent.
- Die übrigen Importaktionen bleiben unverändert: Merge und Merge into behalten den jeweiligen lokalen Zielnamen; neu erstellte Gruppen/Kopien verwenden den importierten Namen. Vollständiges Ersetzen einer Kategorie bleibt vom Update einer einzelnen Gruppe getrennt.
- Gruppen werden anhand stabiler IDs zugeordnet, nicht anhand Namen oder dargestellten Pfaden. Die vorhandenen Regeln für entfernte Mitgliedschaften und verwaiste Bookmarks bleiben erhalten.

## Kontext und Entscheidung

2026-10-05: Nutzer hat ausdrücklich ausschließlich Inhaltsänderungen bei Bookmark group Update verlangt; alle übrigen Importaktionen passen so.

Einstiegspunkte: `lib/core/backups/sources/bookmark_import_service.dart` und `lib/core/backups/export_import/import/import_planned_change_projector.dart`. Zusammenhang mit [virtueller Gruppendarstellung](IDEA-015-nested-bookmark-search-feed-folders.md) und [kompakter Importvorschau](DATA-015-compact-import-change-preview.md).

Unclaimed; Produktimplementierung nicht beauftragt oder erfolgt. Vor Umsetzung [Entwicklungsworkflow](../../development_workflow.md) und [Engineering Guidelines](../../engineering_guidelines.md) beachten.
