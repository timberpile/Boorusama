# Posts über „Boorusama link“ direkt in der App öffnen

Priority: Normal
Affected feature: Post-Sharing, URI-Empfang und Profilauflösung

## Problem und Ziel

Nutzer möchten einen Post-Link versenden, den Empfänger direkt in ihrer installierten Boorusama-App öffnen können, ohne Website oder Post manuell zu suchen.

## Vereinbartes Verhalten und Akzeptanzkriterien

- Der bestehende Share-Dialog erhält unter Links den Eintrag „Boorusama link“ mit den vorhandenen Aktionen Copy und Share; es gibt keinen zusätzlichen Schalter oder Modus-Picker für „Link only“ versus „Image + link“.
- **Copy:** Kopiert ausschließlich den portablen Boorusama-URI als reinen Text in die Zwischenablage, ohne Bild, Beschreibung oder vorangestellten Text. Dafür wird kein Medium heruntergeladen.
- **Share:** Übergibt in einem gemeinsamen OS-Share-Vorgang ein Bild als Anhang und denselben Boorusama-URI als Text/Bildunterschrift. Der Text enthält eine kurze, menschenlesbare Zeile wie `Open in Boorusama`, gefolgt vom vollständigen, unveränderten URI in einer eigenen Zeile. Kein Markdown-/Rich-Text-Linklabel voraussetzen.
- Für den Bildanhang die bestehende Medienvorbereitung und temporäre Datei-Lifecycle aus [IDEA-029](../in-progress/IDEA-029-unified-share-flow.md) wiederverwenden; für Posts ohne teilbares Standbild (z. B. Video) kann, sofern vorhanden, ein Vorschaubild verwendet werden. Ist kein Bild verfügbar oder schlägt die Vorbereitung fehl, wird dies verständlich angezeigt; Copy bleibt nutzbar. Keinen separaten normalen „Link only“-Sharemodus einführen.
- Copy und Share müssen dieselbe Post-Referenz enthalten. Der Messenger entscheidet, ob der Text als tatsächliche Bildunterschrift erscheint, getrennt von der Datei angezeigt oder ignoriert wird. Die App darf eine Bildunterschrift oder klickbare Darstellung nicht garantieren.
- Der Link verwendet ein eigenes URI-Schema und benötigt eine installierte Boorusama-App. Keine zusätzliche Website, kein Hosting und kein Browser-Fallback gehören zum Umfang. Messenger können benutzerdefinierte URI-Schemata als nicht anklickbaren Text behandeln; die vollständige URL muss deshalb sichtbar/kopierbar bleiben.
- Der Link kann die geschlossene App starten oder den Post in der bereits laufenden App öffnen. Die App muss nicht vorher geöffnet sein.
- Der Link enthält die Website und eine stabile Post-Referenz; zusammengesetzte Post-Keys werden für unterstützte Engines korrekt abgebildet. Keine Zugangsdaten oder senderlokalen Profil-IDs übertragen.
- Das Öffnen führt zum richtigen Post und mutiert keine Bookmarks oder Favoriten.
- Genau ein passendes Empfängerprofil wird automatisch verwendet. Bei mehreren passenden Profilen erscheint eine Auswahl.
- Ohne passendes Profil wird die Einrichtung angeboten; nach erfolgreicher Einrichtung wird der ursprünglich verlinkte Post geöffnet. Abbruch ist möglich.
- Ungültige Links, nicht unterstützte Websites/Post-Referenzen und nicht verfügbare Posts werden verständlich behandelt. Vorhandene Datei-Import-Intents bleiben funktionsfähig.

## Kontext und technische Festlegungen

An [IDEA-029](../in-progress/IDEA-029-unified-share-flow.md) und die [Post-Architektur](../../post_architecture.md) anschließen, ohne laufende Claims zu übernehmen. Das genaue URI-Schema, dessen versionierbares Format und die unterstützten Plattformen vor Umsetzung festlegen.

Copy-only-URI und Share-Payload (Bilddatei plus Text mit identischem URI) automatisiert prüfen. Für tatsächliche Messenger-Weitergabe insbesondere WhatsApp, Telegram, Signal und Discord testen und dokumentieren, ob Caption/Text erhalten und der URI anklickbar bzw. kopierbar ist. Das Öffnen bei kalter und laufender App auf den vorgesehenen Plattformen prüfen.

Vor Umsetzung [Entwicklungsworkflow](../../development_workflow.md) beachten. Dieses Ticket ist unclaimed; Umsetzung benötigt einen eigenen Branch/Worktree und einen Implementer gemäß Queue-Regeln.

## Entscheidung

2026-10-05: Nutzer hat „Boorusama link“, einen direkten URI-Link ohne Website/Hosting, die Voraussetzung einer installierten App sowie die automatische Profilwahl, Auswahl bei mehreren Profilen und Einrichtung bei fehlendem Profil bestätigt. Work Item erstellt; keine Umsetzung beauftragt oder erfolgt.

2026-10-16: Share-Verhalten präzisiert: Copy kopiert nur den URI, Share sendet Bild und URI zusammen mit kurzer, menschenlesbarer Bildunterschrift. Kein zusätzlicher Share-Modus-Picker; die tatsächliche Darstellung und Klickbarkeit hängen vom Messenger ab. Nur Ticketbeschreibung angepasst, keine Implementierung.
