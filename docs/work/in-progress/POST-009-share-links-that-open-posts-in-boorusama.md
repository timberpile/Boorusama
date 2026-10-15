# Posts über „Boorusama link“ direkt in der App öffnen

Priority: Normal
Affected feature: Post-Sharing, URI-Empfang und Profilauflösung
Claimed by: ChatGPT, 2026-10-16
Branch: `feature/POST-009-boorusama-links`
Base: `e8bf883912ecd5a8c4154472a962aa0aabf0c09a` (`develop`)
Workspace: isolated task worktree `/mnt/data/post009-worktree` (snapshot-based local history); published branch is authoritative.

## Problem und Ziel

Nutzer möchten einen Post-Link versenden, den Empfänger direkt in ihrer installierten Boorusama-App öffnen können, ohne Website oder Post manuell zu suchen.

## Vereinbartes Verhalten und Akzeptanzkriterien

- Der bestehende Share-Dialog erhält unter Links den Eintrag „Boorusama link“ mit den vorhandenen Aktionen Copy und Share; es gibt keinen zusätzlichen Schalter oder Modus-Picker für „Link only“ versus „Image + link“.
- **Copy:** Kopiert ausschließlich den portablen Boorusama-URI als reinen Text in die Zwischenablage, ohne Bild, Beschreibung oder vorangestellten Text. Dafür wird kein Medium heruntergeladen.
- **Share:** Übergibt in einem gemeinsamen OS-Share-Vorgang ein Bild als Anhang und denselben Boorusama-URI als Text/Bildunterschrift. Der Text enthält eine kurze, menschenlesbare Zeile wie `Open in Boorusama`, gefolgt vom vollständigen, unveränderten URI in einer eigenen Zeile. Kein Markdown-/Rich-Text-Linklabel voraussetzen.
- Für den Bildanhang die bestehende Medienvorbereitung und temporäre Datei-Lifecycle aus [IDEA-029](IDEA-029-unified-share-flow.md) wiederverwenden; für Posts ohne teilbares Standbild (z. B. Video) kann, sofern vorhanden, ein Vorschaubild verwendet werden. Ist kein Bild verfügbar oder schlägt die Vorbereitung fehl, wird dies verständlich angezeigt; Copy bleibt nutzbar. Keinen separaten normalen „Link only“-Sharemodus einführen.
- Copy und Share müssen dieselbe Post-Referenz enthalten. Der Messenger entscheidet, ob der Text als tatsächliche Bildunterschrift erscheint, getrennt von der Datei angezeigt oder ignoriert wird. Die App darf eine Bildunterschrift oder klickbare Darstellung nicht garantieren.
- Der Link verwendet ein eigenes URI-Schema und benötigt eine installierte Boorusama-App. Keine zusätzliche Website, kein Hosting und kein Browser-Fallback gehören zum Umfang. Messenger können benutzerdefinierte URI-Schemata als nicht anklickbaren Text behandeln; die vollständige URL muss deshalb sichtbar/kopierbar bleiben.
- Der Link kann die geschlossene App starten oder den Post in der bereits laufenden App öffnen. Die App muss nicht vorher geöffnet sein.
- Der Link enthält die Website und eine stabile Post-Referenz; zusammengesetzte Post-Keys werden für unterstützte Engines korrekt abgebildet. Keine Zugangsdaten oder senderlokalen Profil-IDs übertragen.
- Das Öffnen führt zum richtigen Post und mutiert keine Bookmarks oder Favoriten.
- Genau ein passendes Empfängerprofil wird automatisch verwendet. Bei mehreren passenden Profilen erscheint eine Auswahl.
- Ohne passendes Profil wird die Einrichtung angeboten; nach erfolgreicher Einrichtung wird der ursprünglich verlinkte Post geöffnet. Abbruch ist möglich.
- Ungültige Links, nicht unterstützte Websites/Post-Referenzen und nicht verfügbare Posts werden verständlich behandelt. Vorhandene Datei-Import-Intents bleiben funktionsfähig.

## Kontext und technische Festlegungen

An [IDEA-029](IDEA-029-unified-share-flow.md) und die [Post-Architektur](../../post_architecture.md) anschließen, ohne laufende Claims zu übernehmen. Das genaue URI-Schema, dessen versionierbares Format und die unterstützten Plattformen vor Umsetzung festlegen.

Copy-only-URI und Share-Payload (Bilddatei plus Text mit identischem URI) automatisiert prüfen. Für tatsächliche Messenger-Weitergabe insbesondere WhatsApp, Telegram, Signal und Discord testen und dokumentieren, ob Caption/Text erhalten und der URI anklickbar bzw. kopierbar ist. Das Öffnen bei kalter und laufender App auf den vorgesehenen Plattformen prüfen.

## Ausführung und Verifikation

2026-10-16: Umsetzung vom Nutzer beauftragt. Aktualisierten Vertrag aus `maintenance/POST-009-share-link-contract` übernommen und Ticket vor Implementierung beansprucht. Keine Integration in `develop`, kein Pull Request.

Die lokale Ausführungsumgebung enthält kein Flutter/FVM und keinen Android-Emulator; direkter Git-Zugriff scheitert an der DNS-Auflösung. Deshalb wurden die Quelltexte in einem isolierten Snapshot-Worktree bearbeitet und über den GitHub-Connector auf dem Feature-Branch veröffentlicht. Flutter-Analyse und Tests wurden mit dem gepinnten SDK in GitHub Actions tatsächlich ausgeführt. Der nur für diese Sitzung benötigte CI-Helfer und sämtliche Patch-Transferdateien wurden im abschließenden Dokumentationscommit entfernt.

## Entscheidung

2026-10-05: Nutzer hat „Boorusama link“, einen direkten URI-Link ohne Website/Hosting, die Voraussetzung einer installierten App sowie die automatische Profilwahl, Auswahl bei mehreren Profilen und Einrichtung bei fehlendem Profil bestätigt.

2026-10-16: Share-Verhalten präzisiert: Copy kopiert nur den URI, Share sendet Bild und URI zusammen mit kurzer, menschenlesbarer Bildunterschrift. Kein zusätzlicher Share-Modus-Picker; die tatsächliche Darstellung und Klickbarkeit hängen vom Messenger ab.

## Implementierter Stand

- Versioniertes URI-Format `boorusama://post/open?v=1&engine=<engine>&site=<encoded-base-url>&key=<encoded-key>`; Parser und Generator sind von Accounts unabhängig. Normale IDs, Sankaku-Server-IDs und Pixiv-Werk/Bildindex werden erhalten. Unbekannte Versionen, doppelte/unbekannte Parameter, ungültige Schlüssel und URLs mit Zugangsdaten werden zurückgewiesen.
- Der bestehende Links-Tab enthält genau eine Boorusama-link-Zeile. Copy übergibt nur den URI. Share verwendet die bestehende Bildvorbereitung, Cache-Leases, Abbruch-, Fehler- und Übergabepfade und übergibt Bild plus lokalisierten Text mit URI. Androids eigener Bildkanal erhält `EXTRA_TEXT`; der share_plus-Pfad erhält dieselbe Caption und einen Popover-Ursprung. Video-Posts verwenden nur vorhandene Bildvorschauen.
- Die neue `/open`-Route verwendet bestehendes Flutter/GoRouter-Deep-Linking. Profilauflösung erfolgt nach Engine und normalisierter Website, niemals nach Sender-Profil-ID. Mehrere Empfängerprofile benötigen eine Wahl; fehlende Profile öffnen den vorhandenen Editor und setzen danach den ursprünglichen Link fort. Der Post wird über das gewählte Empfänger-Repository geladen und seine Identität verifiziert. Es gibt keinen neuen globalen Profilwechsel und keine Bookmark-/Favoritenmutation.
- Fehler-, Wiederholungs-, Abbruch- und Profilwechselzustände sowie deutsche und englische Texte sind implementiert. Neue Links verdrängen veraltete Ladeergebnisse. Die Protokollgrenzen sind in `docs/post_architecture.md` dokumentiert.

## Verifikation des Implementierungsstands

Geprüfter Commit: `4a7bb02a7c57bfd205df58bed9b6624c90fea388`.
[CI-Lauf mit Prüfprotokollen](https://github.com/timberpile/Boorusama/actions/runs/38825240008).
Der Lauf startete auf dem Transfercommit `0b88b4e5f55a1e70cb316dc2237d95fa79778694`, wandte die beiden letzten Testkorrekturen an und zeichnete den tatsächlich geprüften Commit separat auf. Der abschließende Commit ändert nur diese Dokumentation und entfernt den temporären Workflow; Runtime und Tests bleiben gegenüber dem geprüften Stand unverändert.

- Gepinntes Flutter `3.47.2` über FVM `4.3.1`; `./init.sh` einschließlich Generierung erfolgreich. Geänderte Dart-Dateien wurden mit `fvm dart format` formatiert.
- `fvm flutter analyze --no-pub --no-fatal-infos lib/core/posts/links lib/core/posts/shares lib/core/routers lib/foundation/clipboard.dart test/core/posts/links test/core/posts/shares/share_boorusama_link_test.dart`: Exit 0, keine Fehler oder Warnungen; ein nicht blockierender Hinweis `avoid_redundant_argument_values` für das ausdrücklich gesetzte `showAnim: false` im Toast-Test-Teardown.
- `fvm flutter test --no-pub --reporter=expanded --concurrency="$(python3 scripts/physical_core_count.py)" test/core/posts/links test/core/posts/shares test/foundation`: **325 bestanden, 10 übersprungen, keine Fehler**. Die übersprungenen Fälle sind bestehende GIF/FFmpeg-Tests ohne `/usr/bin/ffmpeg`, keine Post-Link-Tests.
- Abgedeckt sind URI-/Credential-Validierung, normalisierte Profilauflösung, exakte Pixiv-/Sankaku-Identität, initiale URI-Navigation, neue URI über den Flutter-Plattformkanal, verdrängte Ladeergebnisse, Profileinrichtung/Abbruch, Auth-/Fehlerzustände, schmale Profilwahl mit großer Schrift, Copy ohne Medienzugriff sowie Bild und identischer URI über Android-Method-Channel und share_plus. Die Dart-seitigen Plattformadapter sind gemockt; native Empfänger werden dadurch nicht verifiziert.
- `scripts/run_regression_tests.sh`: **fehlgeschlagen**. Die vollständige App-Suite meldet **3.398 bestanden, 1 fehlgeschlagen, 10 übersprungen**. Wegen des frühen Abbruchs wurden die nachgelagerten Paket-/CLI- und Repository-Tooling-Suiten dieses Gates nicht ausgeführt.
- Der fehlgeschlagene Fall ist `test/settings/image_cache_limit_ui_test.dart` — `image and video limit dialogs save independently and restore their visible values`. Nach Testende tritt beim Hive-Aufräumen eine `PathNotFoundException` für `pinned_search_folders.lock` auf; der Stack führt über `_FollowingTopicRepositoryBuild._closeBox`. Sowohl dieser Test als auch `lib/core/search/following_topics/src/data/providers.dart` sind gegenüber der Branch-Basis unverändert. Der Ablauf deutet auf eine Teardown-Race mit dem bereits entfernten temporären Verzeichnis hin; eine Reproduktion auf der unveränderten Basis wurde nicht durchgeführt. Keine fachfremde Reparatur in POST-009. Vor Integration muss dieser Regressionsfehler geklärt und der vollständige Gate erneut erfolgreich ausgeführt werden.
- Lokale Abschlussprüfungen: `git diff --check`, JSON-Validität und übereinstimmende neue Übersetzungsschlüssel für Englisch/Deutsch sowie lokale Dokumentationslinks bestanden. Runtime-/Testdateien stimmen bytegenau mit dem archivierten CI-Prüfstand überein. Manuelle Codeprüfung von Profilbindung, Parser, Navigation und Sharing durchgeführt; keine unabhängige Agenten- oder native Geräteprüfung behauptet.

## Noch offene Plattformabnahme

Status bleibt **in progress**: Die Plattformabnahme und ein vollständig grüner Regressionslauf sind noch offen. Bestehende Android- und iOS-Scheme-Registrierungen wurden statisch geprüft; dies ersetzt keine native Ausführung. Neue Desktop-Protokollregistrierungen und Web-/HTTPS-Fallbacks gehören nicht zu V1.

- Android/iOS: Post-Link bei geschlossener und laufender App öffnen; bestehende Profil-Links und Dateiimporte gegenprüfen. Ein, mehrere und keine passenden Profile sowie Abbruch/Einrichtung, Authentifizierung und nicht verfügbare Posts auf Geräten prüfen.
- Android-Instrumentierungstest `ImageClipboardChannelTest.shareIncludesCaptionInTheSameImageIntent` ausführen; neue Prüfung umfasst Caption, Bild-URI, Leseberechtigung und Lesbarkeit nach Entfernen der Quelldatei. In dieser Sitzung nicht nativ ausgeführt; kein APK-/iOS-Build als bestanden behauptet.
- WhatsApp, Telegram, Signal und Discord: tatsächlichen Empfang der Bilddatei und des unveränderten URI prüfen und je App festhalten, ob Caption/Text erhalten, der URI anklickbar oder nur kopierbar ist. iPad-Popover, Live-Authentifizierung und sichtbaren Abbruch während Medienvorbereitung prüfen. Keine Empfänger-App wurde in dieser Sitzung bedient.

Keine Integration in `develop`, kein Pull Request. Nur der eigene Feature-Branch wurde veröffentlicht.
