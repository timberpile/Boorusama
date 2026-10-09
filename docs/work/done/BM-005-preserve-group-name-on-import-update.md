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

Einstiegspunkte: `lib/core/backups/sources/bookmark_import_service.dart` und `lib/core/backups/export_import/import/import_planned_change_projector.dart`. Zusammenhang mit [Gruppenordnern](IDEA-015-nested-bookmark-search-feed-folders.md) und [kompakter Importvorschau](DATA-015-compact-import-change-preview.md).

Akzeptanzkriterien nach unabhängiger Prüfung verifiziert; lokale Integration vom Nutzer freigegeben. Vor Umsetzung [Entwicklungsworkflow](../../development_workflow.md) und [Engineering Guidelines](../../engineering_guidelines.md) beachten.

## Claim

Claimed 2026-10-05 by coordinator `/root`; implementer `/root/bm005`; branch `fix/bm-005-preserve-import-group-name`; worktree `/home/timber/code/Boorusama/.worktrees/bm-005-preserve-import-group-name`; base local develop `46a20296b`. User authorized implementation and continuation in `/tmp/boorusama-priority-program-2026-10-05/order.md`. Integration, publication and cleanup remain separate approvals.

## Progress and evidence

2026-10-05: Implementation prepared on the claimed branch. Update preserves the
exact local name and UUID in execution and projection. Verification covered
resolved actions, name-only preview no-op, orphan cleanup and rollback, plus
full category Replace. Evidence: `/tmp/boorusama-priority-program-2026-10-05/bm005-report.md`.
2026-10-06: Independent spec and quality review passed; minor documentation
findings were resolved in reviewed head `64ef008c5f0d03ee127fb822f9cbedcea97db8ed`.
The user approved `fix/bm-005-preserve-import-group-name`: “works and can be merged”.

Locally integrated as one single-parent commit on `develop`, based on
`46a20296bdd74c5eaf99f8917d1a1d1f69c0d0cd`, in the separate integration checkout
`/home/timber/code/Boorusama/.worktrees/bm-005-develop-integration` by
`/root/integrate_bm005`. Fresh CLI `fvm dart pub get` and `./gen.sh` passed;
the five focused test files passed all 46 tests and targeted analysis of the
five changed Dart files reported no issues. All five Dart blobs match the
reviewed head; only BM-005 delivery metadata and its incoming link differ.
The original claim, branch/worktree, and the user's clean detached review
checkout are preserved. No remote publication, cleanup, APK, full suite or
live-device validation was performed.

Final local commit, parent/tree, scope/hash checks, command exits, and raw logs:
`/tmp/boorusama-priority-program-2026-10-05/bm005-local-integration-report.md` and
`/tmp/boorusama-priority-program-2026-10-05/bm005-local-integration-provenance.json`.
