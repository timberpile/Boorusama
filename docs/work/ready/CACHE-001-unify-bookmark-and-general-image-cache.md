# Bookmark-Bilder und normale Bilder über denselben Cache laden

Priority: Normal
Affected feature: Bildcache, Bookmark-Grids, PostViewer, Preloading und Sharing

## Problem und Ziel

Bookmark-Grids verwenden einen separaten dauerhaften Bildcache, der gemeinsame Viewer jedoch den normalen Bildcache. Nutzer möchten diese Sonderbehandlung entfernen. Garantierte Offline-Verfügbarkeit ist kein Ziel; Bookmark-Bilder sollen wie gewöhnliche Cache-Bilder behandelt werden. Der gemeinsame Dateicache erhält eine einstellbare Speicherobergrenze und entfernt bei Platzbedarf die am längsten nicht verwendeten Einträge (LRU).

## Vereinbartes Verhalten und Akzeptanzkriterien

- Bookmark-Grids, Gruppenvorschauen, Viewer, Preloading und Sharing verwenden denselben normalen Bildcache. Keine getrennte Dateicache-Auswahl durch die einzelnen Bookmark-Aufrufer.
- Kein `protected`-Flag, keine Bookmark-Referenzlisten zur Medienaufbewahrung und kein zusätzlicher dauerhafter Bookmark-Bildcache.
- Eine persistierte Einstellung begrenzt die gesamte Dateigröße des gemeinsamen Bildcaches. Bild- und Video-Limit sind unabhängig; die Bildobergrenze betrifft normale Bilder und Bookmark-Bilder zusammen.
- Größenoptionen und Bedienung 1:1 vom vorhandenen Videocache übernehmen: 100 MB, 500 MB, 1 GB, 2 GB, 5 GB, 10 GB, deaktiviert sowie benutzerdefiniert. Standardwert ist wie beim Videocache 1 GB. Benutzerdefinierte Grenzen, Schritte und Dialogverhalten entsprechen der vorhandenen Video-Einstellung; gemeinsame Options-/Dialoglogik verwenden statt getrennte Varianten zu pflegen.
- Deaktiviertes Bild-Dateicaching (Limit 0) lässt normales Anzeigen von Bildern weiterhin zu, hält jedoch keine neuen Dateien in diesem Cache. Für bereits vorhandene Dateien dieselbe vereinbarte Limitreduktions-/Bereinigungsregel anwenden.
- Kein festes Ablaufdatum für gewöhnliche gecachte Post-Bilder: weder die bisherige Stunde noch die zwischenzeitlich vorgeschlagene Woche. Ein vorhandener Eintrag bleibt ohne altersbedingten erneuten Download nutzbar, bis Platzbedarf, manuelles Leeren oder Betriebssystem-Bereinigung ihn entfernt. Verhalten expliziter Aktualisierung bzw. veränderlicher Ressourcen beim Design benennen; keine garantierte Aktualität unverändert adressierter Dateien behaupten.
- Bei Platzbedarf zuerst die am längsten nicht verwendeten Einträge entfernen. Die letzte tatsächliche Nutzung zählt, nicht das ursprüngliche Download-Datum. Zugriffsreihenfolge muss Neustarts überleben und auch relevante RAM-Cache-Hits berücksichtigen; keine Bookmark-Referenzlisten dafür einführen.
- Speicherbudget bei neuen Dateien, parallelen Schreibvorgängen und dem Herabsetzen des Limits berücksichtigen. Kein aktives Lesen oder Schreiben durch Bereinigung beschädigen. Dateien, die größer als das gesamte Budget sind, dürfen angezeigt/übertragen werden, werden aber nicht dauerhaft in diesem Cache gehalten; kein sinnloses vollständiges Leeren zugunsten einer nicht passenden Datei.
- Thumbnail, Sample und Original bleiben unterschiedliche Cache-Einträge, wenn sie unterschiedliche Medienvarianten sind; Bookmark-Identität nicht als alleinigen Dateischlüssel verwenden.
- Manuelles Leeren des normalen Bildcaches bzw. aller Caches entfernt auch Bookmark-Bilder; Bookmark-Datensätze, Post-Snapshots und Gruppenmitgliedschaften bleiben erhalten. Eine separate Bookmark-Bildcache-Löschaktion/-Anzeige entfällt mit der separaten Speicherung.
- Kein automatischer Komplettdownload von Bookmark-Medien. Nur tatsächlich geladene bzw. regulär vorgeladene Varianten sind vorhanden. Temporäre Dateien können vom Betriebssystem bereinigt werden; daraus keine Offline-Garantie ableiten.
- Bookmark-spezifische Datei-Löschungen beim Entfernen von Bookmarks entfallen. Gemeinsame Dateien unterliegen den normalen Cache-Regeln.
- Vorhandene Dateien des bisherigen Bookmark-Bildcaches werden NICHT migriert, kopiert oder übernommen. Ebenso keine Nutzerdatenmigration für diese Umstellung. Umgang mit verbleibenden alten Dateien beim Review benennen; kein pauschales Löschen von App-Daten oder anderen Nutzerdaten.
- Gezielte Prüfung: identischer Cache-Zugriff in Bookmark-Grid und Viewer, Cache-Hit ohne erneuten Download auch nach mehr als einer Woche, echte LRU-Reihenfolge über Neustarts, Limitänderung und parallele Schreibvorgänge, übergroße Dateien sowie manuelles Leeren ohne Änderung von Bookmark-Nutzerdaten.

## Kontext und Entscheidung

2026-10-05: Nutzer bevorzugt normale Cache-Behandlung ohne Schutz-/Referenzverwaltung, akzeptiert Betriebssystem-Bereinigung und lehnt die Migration alter Bookmark-Bilddateien ab. Anschließend ersetzt der Nutzer das vorgeschlagene Wochen-Zeitlimit durch eine einstellbare Größenobergrenze mit Entfernung der am längsten nicht verwendeten Bilder. Die frühere altersbasierte Löschungs-/Aktualisierungsplanung entfällt für gewöhnliche Post-Bilder. Das vorhandene Video-Cache-Verhalten dient als UI-Vorbild; dessen separate Altersprüfung wird durch dieses Bildcache-Ticket nicht automatisch geändert.

2026-10-05: Nutzer legt anschließend fest, die Limits 1:1 vom Videocache zu übernehmen. Damit sind Standardwert, Presets und benutzerdefinierte Bedienung bestimmt; beide Cache-Budgets bleiben unabhängig.

Einstiegspunkte: `packages/cache_manager/lib/src/image_cache_manager.dart`, `packages/extended_image/lib/src/extended_image.dart`, `lib/core/images/providers.dart`, `lib/core/bookmarks/src/data/image_cache_io.dart`, Bookmark-Grids und Share-Toolbar sowie die Speicher-/Cache-Einstellungsseite. [Post-Architektur](../../post_architecture.md).

Unclaimed; Produktimplementierung nicht beauftragt oder erfolgt. Vor Umsetzung [Entwicklungsworkflow](../../development_workflow.md) und [Engineering Guidelines](../../engineering_guidelines.md) beachten.
