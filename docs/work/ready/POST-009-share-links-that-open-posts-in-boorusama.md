# Posts über „Boorusama link“ direkt in der App öffnen

Priority: Normal
Affected feature: Post-Sharing, URI-Empfang und Profilauflösung

## Problem und Ziel

Nutzer möchten einen Post-Link versenden, den Empfänger direkt in ihrer installierten Boorusama-App öffnen können, ohne Website oder Post manuell zu suchen.

## Vereinbartes Verhalten und Akzeptanzkriterien

- Der bestehende Share-Dialog erhält unter Links den Eintrag „Boorusama link“ mit Kopieren und Teilen.
- Der Link verwendet ein eigenes URI-Schema und benötigt eine installierte Boorusama-App. Keine zusätzliche Website, kein Hosting und kein Browser-Fallback gehören zum Umfang.
- Der Link kann die geschlossene App starten oder den Post in der bereits laufenden App öffnen. Die App muss nicht vorher geöffnet sein.
- Der Link enthält die Website und eine stabile Post-Referenz; zusammengesetzte Post-Keys werden für unterstützte Engines korrekt abgebildet. Keine Zugangsdaten oder senderlokalen Profil-IDs übertragen.
- Kopieren und Teilen erzeugen dieselbe portable Referenz. Das Öffnen führt zum richtigen Post und mutiert keine Bookmarks oder Favoriten.
- Genau ein passendes Empfängerprofil wird automatisch verwendet. Bei mehreren passenden Profilen erscheint eine Auswahl.
- Ohne passendes Profil wird die Einrichtung angeboten; nach erfolgreicher Einrichtung wird der ursprünglich verlinkte Post geöffnet. Abbruch ist möglich.
- Ungültige Links, nicht unterstützte Websites/Post-Referenzen und nicht verfügbare Posts werden verständlich behandelt. Vorhandene Datei-Import-Intents bleiben funktionsfähig.

## Kontext und technische Festlegungen

An [IDEA-029](../in-progress/IDEA-029-unified-share-flow.md) und die [Post-Architektur](../../post_architecture.md) anschließen, ohne laufende Claims zu übernehmen. Das genaue URI-Schema, dessen versionierbares Format und die unterstützten Plattformen vor Umsetzung festlegen. Tatsächliche Link-Weitergabe und Öffnen bei kalter und laufender App auf den vorgesehenen Plattformen prüfen; Einschränkungen einzelner Messenger dokumentieren.

Vor Umsetzung [Entwicklungsworkflow](../../development_workflow.md) beachten. Dieses Ticket ist unclaimed; Umsetzung benötigt einen eigenen Branch/Worktree und einen Implementer gemäß Queue-Regeln.

## Entscheidung

2026-10-05: Nutzer hat „Boorusama link“, einen direkten URI-Link ohne Website/Hosting, die Voraussetzung einer installierten App sowie die automatische Profilwahl, Auswahl bei mehreren Profilen und Einrichtung bei fehlendem Profil bestätigt. Work Item erstellt; keine Umsetzung beauftragt oder erfolgt.
