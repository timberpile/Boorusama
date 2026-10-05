# Geplante Importänderungen kompakt anzeigen

Priority: Normal
Affected feature: Import-Preflight und Review-Ansicht

## Problem und Ziel

Vor einem Import soll sichtbar sein, welche Bookmark-Gruppen, pinned searches, Ordner, Feeds, Profile und weiteren Daten erstellt, gelöscht oder geändert werden. Die Darstellung soll kompakt bleiben und lange erklärende Texte vermeiden.

## Vereinbarte Darstellung und Akzeptanzkriterien

- Kategorien zeigen kompakte Zeilen für betroffene Elemente. Grün kennzeichnet Hinzufügungen, Rot Löschungen, Blau Änderungen; zusätzlich Zeichen oder kurze Beschriftungen verwenden, damit Farbe nicht die einzige Information ist.
- Bookmark-Gruppen zeigen ihren Namen und Mitgliedschaftsänderungen als grüne `+12` und rote `−4` statt ausformulierter Sätze. Anzahlen pro Gruppe reichen aus; keine Liste einzelner Bookmarks.
- Nicht zwischen vollständiger Bookmark-Löschung und Entfernung aus einer Gruppe unterscheiden. Die Zähler in der Gruppenzeile bezeichnen hinzugefügte/entfernte Mitgliedschaften. Interne Planung und Anwendung müssen dennoch die bestehenden Löschungs- und Mitgliedschaftsregeln korrekt beibehalten.
- Neue oder gelöschte Gruppen erhalten ein grünes Plus bzw. rotes Minus am Namen. Umbenennungen werden kompakt als blau markiertes `Alter Name → Neuer Name` dargestellt; kombinierte Änderungen bleiben verständlich.
- Pinned searches, Suchordner, Following Feeds und Profile werden einzeln mit Hinzufügen/Löschen/Änderung gezeigt; zusätzliche relevante Änderungen sind bei Bedarf aufklappbar. Keine erklärenden Texte pro Zeile und keine unveränderten Elemente anzeigen.
- Settings zeigen, soweit zuverlässig ermittelbar, konkrete interne Keys und lesbare Alt-/Neu-Werte, z. B. `themeMode: light → dark`. Interne Namen benötigen keine Localization.
- Blacklist zeigt konkrete hinzugefügte, entfernte oder geänderte Regeln mit nötiger Profilzuordnung. Weitere Quellen liefern konkrete Elementänderungen, soweit zuverlässig möglich; Grenzen werden knapp und ehrlich dargestellt.
- Zugangsdaten und andere Geheimnisse bleiben maskiert; die Tatsache einer Änderung darf erkennbar sein.
- Die Vorschau basiert vor der ersten Anwendungsdaten-Mutation auf dem tatsächlichen aufgelösten Importplan. Auswahl, Importaktion und Profilzuordnung aktualisieren die Vorschau. Veralteter lokaler Zustand erfordert erneute Planung und Bestätigung.
- Replace, Update, Merge, Copy und Skip liefern jeweils korrekte Auswirkungen einschließlich Löschungen lokaler Elemente, die in der Importdatei fehlen. Identische bzw. übersprungene Daten erscheinen nicht als Änderungen. Abbruch verändert keine Anwendungsdaten.

## Verpflichtende Designphase vor Umsetzung

Zuerst ein HTML-Mockup erstellen und dem Nutzer präsentieren. Darin mindestens mehrere Kategorien, neue/gelöschte/umbenannte Gruppen, kombinierte Mitgliedschaftsänderungen, Settings und Blacklist sowie eine umfangreichere Liste auf schmalem Display zeigen. Beispieldaten ausdrücklich als solche behandeln.

Das Mockup anschließend gemeinsam genau besprechen und nach Rückmeldung anpassen. Erst nach expliziter Freigabe der besprochenen Darstellung mit der Produktimplementierung beginnen. Dieses Ticket legt die Inhalte und kompakte Richtung fest, nicht ein bereits freigegebenes finales Layout.

## Kontext und Abhängigkeiten

[Export-/Import-Design](../../superpowers/specs/2026-10-01-unified-export-import-design.md), [Bookmark-Regeln](../../bookmark_groups.md). Mit laufenden Import-Tickets koordinieren, insbesondere [DATA-012 Profil-Mappings](../done/DATA-012-default-and-edit-import-profile-mappings.md) und [DATA-011 Merge-Zielauswahl](../done/DATA-011-fix-bookmark-merge-into-selection.md); bestehende Claims nicht übernehmen. Aktuelle Bookmark-Identitätsregeln haben Vorrang vor älteren Abschnitten im Export-Design.

Vor Umsetzung [Entwicklungsworkflow](../../development_workflow.md) und [Engineering Guidelines](../../engineering_guidelines.md) beachten. Dieses Ticket ist unclaimed; Umsetzung benötigt einen eigenen Branch/Worktree und einen Implementer gemäß Queue-Regeln.

## Entscheidung

2026-10-05: Nutzer hat die kompakte Darstellung, reine Bookmark-Anzahlen pro Gruppe und den Verzicht auf die Unterscheidung zwischen vollständiger Löschung und Gruppenentfernung bestätigt. Vor Umsetzung ist ein HTML-Mockup zur gemeinsamen Detailbesprechung erforderlich. Work Item erstellt; Mockup und Produktimplementierung noch nicht erstellt oder freigegeben.
