# Virtuelle Ordnerdarstellung flacher Gruppen über `//` im Namen

Priority: Normal
Affected feature: Bookmark-Gruppen und Pinned-Search-Gruppen / Darstellung und Navigation

## Problem und Ziel

Der Nutzer möchte insbesondere Gruppen einer anderen Person gemeinsam unter deren Namen sehen, während eigene Gruppen flach bleiben können. Eine echte gespeicherte Hierarchie verursacht für diesen Bedarf zu viele Randfälle und wird nicht weiterverfolgt. Stattdessen bleiben Gruppen intern flach; ihre Namen erzeugen lediglich eine verschachtelte UI-Darstellung.

## Vereinbartes Design und Akzeptanzkriterien

- `//` ist der Trenner virtueller Ordnerebenen. Ein einzelnes `/` bleibt ein normal verwendbares Zeichen im Namen: `Cookie//Artists` erscheint unter Cookie als Artists; `Cookie//Landscape/City` erscheint dort als Landscape/City.
- Die gespeicherte Gruppe behält ihre UUID und ihren vollständigen Namen. Keine Eltern-IDs, gespeicherte Ordnerbäume oder neue Hierarchie-Migration einführen. Export/Import transportiert weiterhin flache Gruppennamen und bestehende Identitäten.
- Virtuelle Zwischenordner sind aus Namen abgeleitet und haben keine eigene gespeicherte Identität. Ohne eine reale Gruppe Cookie kann der Nutzer Bookmarks nicht direkt in Cookie ablegen.
- Existieren Cookie und Cookie//Artists gleichzeitig als reale Gruppen, zeigt die Cookie-Ebene sowohl den eigenen Gruppeninhalt als auch die virtuelle Untergruppe. Keine zusätzliche Gruppe automatisch erstellen und keine Mitgliedschaften verlagern.
- Gruppen ohne Trenner bleiben flach. Entfernen des letzten namensbasierten Nachfahren lässt einen rein virtuellen Ordner verschwinden; eigenständige leere virtuelle Ordner werden nicht gespeichert.
- Gruppen verschiedener UUIDs dürfen nicht wegen gleicher Namen oder Pfade zusammengeführt werden. Bestehende Bookmark-Mehrfachmitgliedschaften und Pinned-Search-Zuordnungen bleiben unverändert.
- Kein zusätzlicher Überordner-/Präfix-Picker beim Import. Nutzer können ihre lokalen Gruppen selbst umbenennen.
- [BM-005](BM-005-preserve-group-name-on-import-update.md) stellt sicher, dass Bookmark group Update nur den Inhalt ändert und den lokalen Namen samt virtueller Platzierung behält. Übrige Importaktionen werden nicht umgestaltet.

## Vor Umsetzung zu konkretisierende UI-Regeln

Navigation, Darstellung einer Ebene mit eigenem Gruppeninhalt, Verhalten leerer Namenssegmente sowie Groß-/Kleinschreibung und Kollisionen im virtuellen Pfad konkret zeigen und besprechen. Sollten virtuelle Ordner Sammelaktionen zum Umbenennen oder Löschen bekommen, betrifft das mehrere echte Gruppen und benötigt eine verständliche Vorschau; keine alten Anforderungen an rekursive Baumoperationen ungeprüft übernehmen.

Die frühere Planung umfasste auch Following-Feed-Ordner. Dafür keine echte Ordnerstruktur mehr einführen; eine zusätzliche Feed-Darstellung über Namen ist vor Umsetzung gesondert zu konkretisieren und nicht automatisch durch diesen vereinfachten Gruppenentwurf freigegeben.

## Kontext und Entscheidung

2026-10-05: Nutzer ersetzt den bisherigen Plan einer echten verschachtelten Struktur durch virtuelle Darstellung flacher Gruppen. `//` wurde als Trenner gewählt, damit `/` normal nutzbar bleibt. Ein Import-Präfix wird ausdrücklich nicht benötigt. Der Dateiname bleibt als stabile Ticketreferenz erhalten; die frühere Parent-UUID-/Baum-Migrationsplanung ist superseded.

[Bookmark-Architektur](../../bookmark_groups.md), [Pinned-Search-Architektur](../../pinned_searches.md). IDEA-010-Zielgruppenreferenzen bleiben durch unveränderte UUIDs erhalten. Unclaimed; keine Umsetzung erfolgt oder beauftragt. Vor Umsetzung [Entwicklungsworkflow](../../development_workflow.md) und [Engineering Guidelines](../../engineering_guidelines.md) beachten.
