# Warnungen und Fehler appweit nachvollziehbar protokollieren

Priority: Normal
Affected feature: Appweites Diagnose-Logging

## Problem und Ziel

Warnungen und Fehler scheinen häufig keine hilfreichen Details im Log zu hinterlassen. Als konkretes Beispiel wurde „Some saved site-specific data could not be read“ genannt. Die sichtbare Meldung darf kurz bleiben; die zugrunde liegende technische Ursache muss im Log nachvollziehbar sein. Der Nutzer hat die Prüfung ausdrücklich appweit gewünscht.

## Umfang und Akzeptanzkriterien

- Die bestehenden Logging-Wege und Fehlerbehandlungen appweit prüfen, einschließlich Startup/Persistenz, API-/Netzwerkzugriff, Profil-/Account-Auflösung, Post-Decoding und Recovery, Import/Export, Suche/Feeds, Favoriten/Bookmarks sowie Medienladen, Download und Sharing. Inventar und konkrete Lücken im Arbeitsbericht dokumentieren; die Vermutung über fehlende Logs nicht als bereits verifiziertes Ergebnis behandeln.
- Behandelte Warnungen und Fehler erhalten passende Warning-/Error-Einträge an der verantwortlichen Stelle in der vorhandenen Logging-Pipeline. Auch Fehler berücksichtigen, die als Ergebnis/Fallback statt als Exception dargestellt werden.
- Eintrag nennt Operation bzw. Komponente und konkreten technischen Grund. Ursprüngliche Exception und Stacktrace erhalten, sofern vorhanden; Wrapper dürfen die Ursache nicht verlieren. Relevante Schema-/Codec-Versionen und betroffene Feldnamen nennen, soweit verfügbar und ohne private Werte offenzulegen.
- Beim Beispiel zu gespeicherten site-spezifischen Daten ist aus dem Log erkennbar, welcher Decoder bzw. welche Validierungsstufe scheiterte und warum. Nicht nur den lokalisierten UI-Satz protokollieren.
- Recovery bleibt diagnostizierbar: Ausgangsproblem, Erfolg einer Wiederherstellung und endgültiges Scheitern sind unterscheidbar. Erfolgreiche automatische Recovery erfordert keine zusätzliche sichtbare Fehlermeldung.
- Keine wiederholten Einträge für dasselbe Ereignis durch Widget-Rebuilds oder mehrfaches Weiterreichen einer Exception. Erwartete Nutzerabbrüche, unveränderte Daten und normale Nichtverfügbarkeit nicht pauschal als Fehler einstufen.
- Keine Credentials, Auth-Header, Tokens, vollständigen privaten Payloads oder sensiblen Query-/Bookmark-Werte loggen. URLs und technische Referenzen nach bestehenden Datenschutzregeln redigieren, auch innerhalb von Exceptions und Stack-Kontext.
- Repräsentative Fehlerpfade der betroffenen Subsysteme nachvollziehen und fehlende Ursachen nachweislich erhalten. Bekannte Lücken und tatsächlich geprüfte Bereiche im Arbeitsbericht benennen; keine appweite Vollständigkeit aus einem einzelnen Beispiel ableiten.

## Kontext und Abgrenzung

Die Aufgabe umfasst appweite Diagnosequalität, keine pauschale Aktivierung sämtlicher Debug-/Netzwerk-Payload-Logs und kein vollständiges neues Logging-System. Bestehende Logger und Log-Zugriff verwenden; strukturelle Anpassungen nur soweit für zuverlässige Fehlerdiagnose nötig.

[Post-Architektur](../../post_architecture.md), Datenschutzabschnitt im [Export-/Import-Design](../../superpowers/specs/2026-10-01-unified-export-import-design.md). [POST-008](../in-progress/POST-008-silently-recover-incomplete-bookmarks-on-open.md) behandelt automatische Recovery, dieses Ticket deren Diagnose; laufenden Claim nicht übernehmen.

Vor Untersuchung eines Subsystems dessen Dokumentation lesen. Vor Umsetzung [Entwicklungsworkflow](../../development_workflow.md) und [Engineering Guidelines](../../engineering_guidelines.md) beachten. Dieses Ticket ist unclaimed; Umsetzung benötigt einen eigenen Branch/Worktree und einen Implementer gemäß Queue-Regeln.

## Entscheidung

2026-10-05: Nach Einzelbesprechung hat der Nutzer den appweiten Umfang bestätigt. Work Item erstellt; Audit und Umsetzung noch nicht durchgeführt oder beauftragt.
