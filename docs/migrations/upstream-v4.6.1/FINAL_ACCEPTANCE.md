# Manuelle Checkliste für ein echtes Android-Handy

Diese Anleitung gehört zur Migration auf v4.6.1, Branch
`maintenance/upstream-v4.6.1-migration`. Der geprüfte Programmstand ist
`bc55de7c2`. Die automatischen Tests und die beschriebenen Emulatorprüfungen sind
abgeschlossen. Diese Checkliste beschreibt deinen zusätzlichen Durchlauf auf
einem echten Handy. Die bisherigen Ergebnisse und ihre Grenzen stehen im
[Prüfbericht](REGRESSION_FIXES.md); die umfassendere Migrationsprüfung steht in
[MANUAL_ACCEPTANCE_CHECKLIST.md](MANUAL_ACCEPTANCE_CHECKLIST.md).

Hake einen Abschnitt erst ab, wenn du ihn auf deinem Handy durchgeführt hast und
das erwartete Ergebnis stimmt. Fehlen passende Testdaten oder Geräte, notiere
**nicht prüfbar** und den Grund. Das zählt weder als bestanden noch als Fehler.
Einzelne bestandene Handytests schließen die gesamte Migrationsprüfung nicht ab.

## Vorbereitung

1. Notiere Handymodell, Android-Version und die installierte Boorusama-Version.
   Die App-Version findest du im Info-/Über-Bereich der App oder in der
   Android-App-Info. Notiere zusätzlich, welche APK du verwendest.
2. Öffne **Einstellungen → Export and Import** und erstelle einen vollständigen
   Export. Speichere ihn an einem Ort, den du wiederfindest. Ein vollständiger
   Export kann Zugangsdaten enthalten; behalte ihn privat.
3. Notiere deine bisherigen Einstellungen für Bildqualität, GIF-Autoplay,
   Downloads, PIN und Schriftgröße. Mache davon bei Bedarf eigene Notizen.
4. Verwende für die Downloads einen eigenen leeren Ordner, zum Beispiel
   `Downloads/Boorusama-Handytest`. Wähle ihn in den Download-Einstellungen aus.
5. Verwende für Änderungen an Profilen und Importen eine entbehrliche
   Testinstallation mit gesicherten Daten. Lösche keine App-Daten und
   deinstalliere deine bestehende App nicht, um ein Update zu erzwingen.

**Menünamen:** Die App ist noch nicht vollständig übersetzt. Deshalb stehen hier
auch die tatsächlich vorhandenen englischen Namen. **Save metadata** bedeutet
Metadaten mitspeichern, **App lock** bedeutet App-Sperre und **Thumbnail quality**
bedeutet Qualität der Vorschaubilder. Einstellungen findest du über das
Seitenmenü; die Einstellungssuche hilft, wenn ein Eintrag anders eingeordnet ist.
Android-Menünamen können je nach Hersteller leicht abweichen.

**Vollständig neu starten** bedeutet in dieser Anleitung: Android-Einstellungen
öffnen → Apps → deine Boorusama-Installation → **Beenden erzwingen** → anschließend
Boorusama wieder öffnen. Das Wegwischen aus der Übersicht allein reicht dafür
nicht zuverlässig. Führe das nur ohne laufenden Export/Import/Download aus;
der gesonderte Unterbrechungstest unten ist die Ausnahme.

## 1. Update und vorhandene Daten

- [ ] Update erhält die vorhandenen Daten.

1. Verwende eine entbehrliche Installation der bisherigen Produktionsversion und
   eine dazu passende, gleich signierte neue Produktions-APK. Die geprüfte
   `app-dev-debug.apk` ist eine separate Entwicklungs-App und ersetzt diesen
   Update-Test nicht. Fehlt eine passende Produktions-APK, notiere **nicht
   prüfbar** und fahre mit den anderen Tests in deiner Testinstallation fort.
2. Notiere vor dem Update ein vorhandenes Profil, ein Bookmark samt Ordner, eine
   angeheftete Suche, ein Following-Thema und einen Favoriten-Tag. Kontrolliere
   außerdem Anmeldung, automatische Sicherung und App-Sperre.
3. Öffne die neue APK auf dem Handy und installiere sie als Update. Android muss
   sie als Update derselben App akzeptieren; eine Signaturfehlermeldung ist kein
   Grund zur Deinstallation. Paketkennung, Signatur und erhöhte interne
   Versionsnummer müssen zur bereitgestellten Produktions-APK passen; falls sie
   aus den verfügbaren APK-Angaben nicht hervorgehen, bleibt diese technische
   Teilprüfung offen.
4. Öffne die App und kontrolliere alle zuvor notierten Daten und Einstellungen.
   Prüfe, ob die Anmeldung weiterhin zum richtigen Profil gehört.
5. Schließe eine eventuell angezeigte Neuigkeiten-Seite und starte die App zweimal
   vollständig neu.

**Erwartet:** Die neue Version läuft mit deinen bisherigen Daten. Ordner,
Zuordnungen, Reihenfolge und Einstellungen bleiben erhalten. Die Neuigkeiten
erscheinen für dieselbe Version nicht erneut.

## 2. PIN nach Profilimport und Neustart — R02

- [ ] Die bekannte PIN funktioniert nach dem Import und nach einem Neustart.

1. Öffne **Einstellungen → Datenschutz → App lock**. Richte eine bekannte
   Test-PIN ein und notiere sie privat. Verwende eine kurze Sperrzeit, damit du
   die Sperre prüfen kannst.
2. Erstelle über **Export and Import** einen Export deiner aktuellen Profile.
   Wähle alle Profile, die erhalten bleiben sollen; sichere ihre Zugangsdaten mit,
   falls diese für den unveränderten Profilbestand benötigt werden.
3. Importiere diesen eigenen Export wieder. Wähle für diesen Test nur die
   Profilkategorie aus. Prüfe bei **Replace** die Vorschau: Es darf kein Profil
   unerwartet verschwinden. Bestätige erst dann und führe den angebotenen
   App-Neustart aus. Die App-Sperre soll durch diesen Profilimport nicht ersetzt
   werden.
4. Lasse die App gegebenenfalls durch kurzes Wechseln zum Startbildschirm sperren.
   Gib einmal eine falsche PIN ein. Warte eine angezeigte Sperrfrist ab und gib
   danach die richtige PIN ein.
5. Starte die App vollständig neu und entsperre erneut mit derselben PIN.
6. Ändere die PIN über **Change PIN**, sperre und entsperre mit der neuen PIN.
   Schalte die Test-PIN anschließend wieder aus oder stelle deine ursprüngliche
   Sperre wieder her.

**Erwartet:** Die falsche PIN wird abgewiesen; die richtige funktioniert auch nach
Profilimport und Neustart. Ändern und Ausschalten funktionieren weiterhin.
Dieser Ablauf wurde bereits im Emulator geprüft; hier zählt der Handy-Durchlauf.

## 3. Gespeicherte Such-Metatags — R10

- [ ] Leere und teilweise gefüllte Metatag-Listen bleiben gespeichert.
- [ ] Dasselbe funktioniert direkt nach dem Profilimport mit Suche als Startseite.

1. Öffne ein Danbooru-Profil und dessen Suche. Notiere die vorhandenen Einträge
   im Bereich **METATAGS**.
2. Tippe auf den Stift neben **METATAGS**, entferne alle Einträge und beende die
   Bearbeitung mit dem Häkchen. Die Änderungen an den Einträgen werden direkt
   gespeichert.
3. Starte die App vollständig neu und öffne dieselbe Suche.
4. Füge anschließend nur zwei Einträge hinzu, zum Beispiel `rating` und `user`.
   Starte erneut vollständig neu und kontrolliere die Liste.
5. Für die zweite Checkbox: Stelle im bearbeiteten Danbooru-Profil unter
   Aussehen/Layout **Home screen → Search** ein, sofern verfügbar. Erstelle danach
   einen neuen Profilexport mit dieser Einstellung und importiere ihn wie in
   Test 2. Prüfe, welche Seite danach tatsächlich zuerst erscheint. Wähle keine unerwarteten Löschungen in der Importvorschau.
6. Nur wenn nach dem Import wirklich die Danbooru-Suche als Startseite erscheint:
   Lösche einen Metatag, füge ihn wieder hinzu und kontrolliere die Speicherung
   nach einem vollständigen Neustart. Erscheint stattdessen eine andere
   Startseite oder ist die Startseitenoption nicht verfügbar, notiere diese
   zweite Checkbox als **nicht prüfbar**.
7. Stelle die ursprünglichen Metatags und die ursprüngliche Startseite wieder her.

**Erwartet:** Eine leere Liste bleibt leer; danach bleiben genau die zwei gewählten
Einträge erhalten. Auch nach dem Import lassen sich die Einträge weiter ändern.
Die leere/teilweise Liste wurde bereits im Emulator geprüft. Der spezielle
Suche-als-Startseite-Fall bleibt gesondert zu bestätigen.

## 4. Favorisieren ohne doppelte Aktion — R01

- [ ] Favorisieren und Entfernen funktionieren im angemeldeten Testkonto.

1. Öffne einen noch nicht favorisierten Testbeitrag in einem Profil mit deinem
   angemeldeten Testkonto.
2. Tippe genau einmal auf Favorisieren. Warte auf das Ergebnis.
3. Verlasse den Beitrag, öffne ihn erneut und kontrolliere den Favoritenstatus.
4. Entferne den Favoriten mit genau einem Tippen und kontrolliere erneut.
5. Falls dabei ohnehin eine Schutzabfrage, Wartezeit oder Fehlermeldung erscheint,
   notiere sie. Tippe während einer laufenden Anfrage nicht wiederholt.

**Erwartet:** Die sichtbare Änderung wird einmal übernommen und bleibt nach dem
Wiederöffnen korrekt. Vorübergehende Fehler werden verständlich angezeigt.
Dieser Handytest kann nicht beweisen, wie viele Netzwerkanfragen gesendet wurden;
dafür gelten die vorhandenen automatischen Anfragezähler-Tests.

## 5. Sehr flache Vorschaubilder und große Schrift — R03

- [ ] Flache Kacheln und ihre Schaltflächen sind sauber bedienbar.

1. Öffne eine Bildliste mit einem bekannten sehr breiten Panoramabild. Wähle ein
   Profil, bei dem Score/Markierungen und zwei Vorschauaktionen vorhanden sind.
   Falls nötig, aktiviere die Aktionen in den Profileinstellungen über
   **Primary thumbnail action** und **Secondary thumbnail action**.
2. Stelle die Rastergröße zunächst auf **Mittel**, danach auf **Winzig**.
3. Stelle in den Android-Einstellungen die Schriftgröße auf 200 %, falls dein
   Handy das anbietet, sonst auf die größte verfügbare Stufe und notiere diese.
4. Schaue dir die besonders flachen Kacheln an. Tippe die sichtbaren Aktionen
   einzeln an. Kontrolliere auch das Favoritenherz während seiner Animation.
5. Wiederhole das bei normalen Kacheln und, soweit einstellbar, bei einer einzelnen
   Aktion sowie nebeneinander und übereinander angeordneten Aktionen.

**Erwartet:** Kein Überlaufen von Text oder Symbolen. Bei Platzmangel dürfen
Informationen und Aktionen ausgeblendet werden. Unsichtbare Aktionen dürfen keine
Berührung abfangen; sichtbare Aktionen dürfen nicht die Nachbaraktion auslösen.
Das Herz bleibt auf seinem runden Hintergrund zentriert. Fehlen passende Bilder
oder Anzeigeoptionen, notiere den nicht geprüften Teil.

## 6. GIF-Vorschau und Qualität — R04

- [ ] GIF-Autoplay und statische Vorschau funktionieren bei verschiedenen Größen.

1. Verwende ein Danbooru-Profil mit bekannten GIF-Beiträgen: möglichst eines mit
   kleinem Original und eines mit einem Original über 5 MiB. Notiere die Beiträge
   und die bekannte Originalgröße. Fehlen solche Angaben, bleibt der Größenfall
   **nicht prüfbar**.
2. Öffne **Einstellungen → Aussehen** und schalte **GIF automatisch abspielen**
   aus. Prüfe, dass die GIF-Vorschaubilder in der Liste stillstehen.
3. Probiere bei **Thumbnail quality** nacheinander Niedrig, Mittel, Hoch und
   Automatisch. Wiederhole jeweils mit Rastergröße Mikro, Winzig und Mittel;
   prüfe anschließend auch Klein und Groß.
4. Schalte GIF-Autoplay wieder ein. Wiederhole mit kleinem und großem Original,
   auch in einer Following-Liste, falls du dort passende Beiträge hast.

**Erwartet:** Ohne Autoplay bleiben alle GIF-Vorschaubilder statisch. Mit Autoplay
können geeignete kleine Originale animiert werden; Originale über 5 MiB bleiben
statisch. Die Qualitätseinstellung beeinflusst die statische Vorschau. Ein im
Cache liegendes Bild oder bloßer Schärfeeindruck beweist die geladene Auflösung
nicht. Ohne verlässliche Ressourcenangaben bleibt diese technische Teilprüfung
offen. Für statische GIF-Fallbacks mit vorhandenen Varianten gilt:

| Thumbnail quality | Mikro | Winzig | Klein / Mittel / Groß |
| --- | --- | --- | --- |
| Niedrig | 180 | 180 | 360 |
| Mittel / Automatisch | 180 | 360 | 720 |
| Hoch | 360 | 720 | 720 |

Die Zahlen bezeichnen die Ressourcenvarianten. Der Fall mit großer GIF-Datei,
Mittel-Raster und Automatisch wurde im Emulator kontrolliert geprüft; die gesamte
Matrix und unterschiedliche Live-Beiträge bleiben zusätzliche Prüfungen.

## 7. Lange drücken und Menüs schließen — R05

- [ ] Kontextmenüs lassen sich auf dem Handy korrekt öffnen und schließen.

1. Drücke länger auf einen Beitrag in einer Bildliste.
2. Kontrolliere anhand der angebotenen Aktionen, dass das Menü zu diesem Beitrag
   gehört. Tippe anschließend außerhalb des Menüs.
3. Kontrolliere, dass das Menü geschlossen wurde und kein darunterliegender
   Beitrag geöffnet oder eine Aktion ausgelöst wurde.
4. Öffne anschließend das Menü eines anderen Beitrags. Wiederhole das in den
   Bookmarks und schließe ein Menü auch mit Android-Zurück.

**Erwartet:** Das passende Menü öffnet sich; Schließen löst keine andere Aktion
aus. Der zusätzliche Rechtsklick-Wechsel zwischen Beiträgen benötigt eine echte
Maus. Ohne angeschlossene Maus bleibt dieser Teil offen; langes Drücken ersetzt
den Rechtsklick-Test nicht.

## 8. Video, Sperre und Medientasten — R06

- [ ] Medientasten funktionieren entsperrt und verändern gesperrtes Video nicht.
- [ ] Video-Details erhalten Position und Wiedergabestatus.

1. Öffne ein wirklich geladenes Video und lasse es einige Sekunden laufen.
   Notiere die angezeigte Zeit. Prüfe zunächst die normalen Wiedergabe-/Pause-
   Schaltflächen auf dem Bildschirm.
2. Wenn du eine Tastatur oder ein Headset mit Medientasten hast, teste dessen
   Wiedergabe-/Pause-Taste bei geöffnetem, ungesperrtem Video. Teste separate
   Play-/Pause-Tasten zusätzlich, falls vorhanden. Nur Tasten, die hier sichtbar
   funktionieren, eignen sich für den folgenden Sperrvergleich. Ohne solches
   Zubehör ist der Medientastentest **nicht prüfbar**.
3. Pausiere, notiere die Zeit und aktiviere das Sperrsymbol **im Videoplayer**.
   Das ist eine andere Sperre als Androids Bildschirmsperre oder die App-PIN.
   Drücke die zuvor funktionierenden Medientasten. Entsperre den Player und
   kontrolliere, dass das Video weiterhin pausiert und die Zeit unverändert ist.
4. Wiederhole bei laufendem Video: sperren, Pause beziehungsweise Umschalten
   drücken, entsperren. Die Wiedergabe muss weiterlaufen. Eine weiterlaufende
   Zeitanzeige ist hier das erwartete Verhalten.
5. Prüfe nach dem Entsperren dieselben Tasten erneut. Wiederhole, soweit möglich,
   mit geöffnetem Texteingabefeld im Vordergrund und nach Verlassen des Viewers;
   die Tasten dürfen dann nicht den verdeckten alten Viewer steuern. Fehlt dort
   ein geeignetes Eingabefeld, notiere diesen Teil als **nicht prüfbar**.
6. Für die zweite Checkbox: Öffne bei laufendem Video die Beitragsdetails und
   schließe sie zweimal. Wiederhole im pausierten Zustand, möglichst mit MP4
   und WebM.

**Erwartet:** Sperren verhindert Änderungen durch die getesteten Medientasten;
Entsperren gibt die Bedienung wieder frei. Details öffnen/schließen setzt das
Video nicht auf 0:00 zurück, friert es nicht ein und hebt Pause nicht auf.
Im Emulator sind die entsperrten positiven Kontrollen und gesperrt-pausiert mit
Play/Umschalten bereits belegt. Die übrigen Fälle brauchen eigene Beobachtungen.

## 9. Bookmark-Downloads mit Begleitdateien — R07

- [ ] Aus, TXT und JSON liefern beim Bookmark-Sammeldownload die richtigen Dateien.

1. Stelle die allgemeine Downloadqualität auf **Vorschau** beziehungsweise
   **Thumbnail**. Wähle drei unterschiedliche kleine, noch nicht heruntergeladene
   Testbeiträge und speichere sie als Bookmarks.
2. Stelle **Save metadata** zunächst auf **Off**. Öffne die Bookmark-Gruppe,
   drücke länger auf den ersten Beitrag und wähle **Select** beziehungsweise
   Auswählen. Kontrolliere die Anzeige „1 item selected“ und tippe auf Download.
   Verwende genau diese Auswahlfunktion der Bookmark-Liste.
3. Öffne die Android-Dateien-App und kontrolliere den Testordner. Es muss die
   Original-Mediendatei vorliegen, ohne neue TXT-/JSON-Begleitdatei.
4. Stelle **Save metadata → Tags (.txt)** ein und wiederhole mit dem zweiten
   Bookmark. Öffne die TXT-Datei: Sie soll dessen Tags enthalten.
5. Stelle **Save metadata → Metadata (.json)** ein und wiederhole mit dem dritten
   Bookmark. Öffne die JSON-Datei mit einer Textansicht, falls vorhanden:
   Beitrags-ID und Quelle müssen zum dritten Beitrag passen;
   `media.quality` muss `original` sein. Vergleiche die Bildabmessungen in der
   Dateien-App mit den Originalangaben des Beitrags, falls dort verfügbar.
6. Wähle zwei weitere Bookmarks gemeinsam aus und wiederhole einen kleinen
   Sammeldownload mit TXT. Prüfe beide Medien- und Begleitdateien.

**Erwartet:** Dieser Bookmark-Auswahlweg lädt Originale trotz allgemeiner
Vorschau-Einstellung. TXT/JSON gehören jeweils zum richtigen Beitrag; ohne
Metadatenoption entsteht keine neue Begleitdatei. Nach erfolgreichem Speichern
darf keine unbegründete Meldung **Metadata needs attention** bleiben. Fehlt eine
Text-/Auflösungsansicht auf deinem Handy, notiere den betreffenden Dateinachweis
als offen. Der gewöhnliche Downloadknopf im geöffneten Bookmark-Beitrag ist ein
anderer Weg und darf der normalen Qualitätswahl folgen. Die Auswahlfälle wurden
bereits im Emulator geprüft; hier wird das Verhalten auf deinem Handy wiederholt.

## 10. Ausdrücklich gewählte Downloadqualität — R08

- [ ] Die ausgewählte Qualität passt zur Datei und zu den JSON-Metadaten.

1. Aktiviere JSON-Metadaten und stelle die allgemeine Downloadqualität auf
   **Original**.
2. Öffne einen neuen Testbeitrag, halte dessen Downloadknopf gedrückt und wähle
   ausdrücklich **Vorschau/Thumbnail**. Verwende nicht nur den kurzen Standardtap.
3. Prüfe in der Dateien-App die Datei und, soweit möglich, die JSON-Begleitdatei.
   Vergleiche mit den verfügbaren Varianten des Beitrags.
4. Stelle die allgemeine Qualität auf Vorschau und wähle bei einem weiteren
   Beitrag ausdrücklich **Original**. Wiederhole mit **Beispiel/Sample** und
   weiteren tatsächlich angebotenen Größen.
5. Falls deine Seite eine gewählte Variante nicht anbietet und eine erlaubte
   Ersatzvariante verwendet, kontrolliere, dass die JSON-Angabe die tatsächlich
   gespeicherte Qualität beschreibt. Prüfe den Fall auch bei einem Sammeldownload,
   sofern dort dieselbe Qualitätswahl angeboten wird.

**Erwartet:** Die ausdrückliche Wahl hat Vorrang vor der allgemeinen Einstellung.
JSON beschreibt die tatsächliche Datei, auch bei zulässigen Ersatzvarianten;
eine unbekannte Qualität darf als `custom` erscheinen. Nicht vorhandene
Moebooru-Varianten Large/JPEG dürfen nicht als scheinbar erfolgreiche Wahl
heimlich ein Original speichern. Seltene fehlende Varianten ohne passenden
Beitrag bleiben **nicht prüfbar**.

## 11. Medien-Mirror beim Bookmark-Download — R09, nur mit passendem Mirror

- [ ] Der Download verwendet den Mirror des ursprünglichen Bookmark-Profils.

1. Führe diesen Test nur durch, wenn du einen erreichbaren, für deine Quelle
   vorgesehenen Mirror kennst. Sonst notiere **nicht prüfbar: kein passender
   Mirror**. Verwende nicht die lokale Emulatoradresse aus dem Prüfbericht.
2. Öffne das Ursprungsprofil A → Profil bearbeiten → Netzwerk →
   **Media host overrides**. Notiere vorhandene Regeln. Trage über **Add override**
   den ursprünglichen Medienhost und den vorgesehenen Ersatzhost ein, aktiviere
   die Regel und speichere. Die Felder erwarten Hostnamen, keine vollständigen
   URLs mit Pfad.
3. Speichere einen Beitrag aus A als Bookmark. Wechsle danach zu einem anderen
   Profil B, das diese Mirror-Regel nicht hat.
4. Öffne die Bookmark-Gruppe und lade den Beitrag über Auswahl → Download wie
   in Test 9. Prüfe, ob die Datei ankommt und JSON weiterhin die ursprüngliche
   Beitragsquelle aus A nennt.
5. Falls du vertrauenswürdige Mirror-Protokolle oder andere geeignete
   Netzwerknachweise hast, kontrolliere dort das Ziel und die Behandlung von
   Anmeldedaten. Teile keine Cookies, Schlüssel oder Zugangsdaten.

**Erwartet:** Der Download verwendet die Regel von A, obwohl B aktiv ist. Ein
sichtbar erfolgreicher Download allein beweist weder den Zielhost noch das
Entfernen unpassender Zugangsdaten oder die Freigabe des Zielhosts. Ohne solche
Nachweise bleibt diese technische Teilprüfung offen. Im Emulator wurde die
korrekte umgeschriebene Task-URL bestätigt, aber kein erfolgreicher Mirror-Transfer.

## 12. Nicht verfügbares Zerochan-Original — R11, nur mit bekanntem Beispiel

- [ ] Fehlendes Original meldet einen Fehler und lädt keine kleinere Ersatzdatei.

1. Verwende ein Zerochan-Profil und einen Beitrag, bei dem nachweislich kein
   Original verfügbar ist. Hast du kein bekanntes Beispiel, notiere **nicht
   prüfbar: passender Beitrag fehlt**. Flugmodus erzeugt einen anderen Fehler
   und ersetzt diesen Test nicht.
2. Öffne den Beitrag, halte Download gedrückt und wähle ausdrücklich **Original**.
3. Prüfe die Fehlermeldung und den Testordner. Falls geeignete Netzwerknachweise
   verfügbar sind, prüfe zusätzlich, dass keine Vorschau/Sample-Datei angefordert
   wurde.

**Erwartet:** Die App meldet, dass das Original nicht verfügbar ist. In englischer
Anzeige lautet die Meldung: „The original media file is unavailable. Retry.“
Es darf keine kleinere Datei als erfolgreiches Original gespeichert werden.
Ein dauerhafter fehlgeschlagener Eintrag ist nicht nötig, wenn gar kein Download
angelegt wurde. Der kontrollierte Emulatorfall ist bereits bestanden; der
Live-Fall auf dem Handy bleibt eine gesonderte Prüfung.

## 13. Downloads im Hintergrund und Wiederholen

- [ ] Ein tatsächlich noch laufender Download läuft im Hintergrund weiter.
- [ ] Metadaten lassen sich nach einem Fehler getrennt wiederholen.
- [ ] Optional: Ein unterbrochener Testdownload lässt sich sinnvoll fortsetzen.

1. Starte einen ausreichend großen Testdownload mit TXT oder JSON. Kontrolliere,
   dass er wirklich noch läuft, bevor du die Android-Home-Taste drückst.
2. Öffne nach etwas Wartezeit Boorusama erneut. Prüfe den Status und die Dateien
   im Testordner. War er schon vor Home fertig, wiederhole mit einer größeren
   Datei oder notiere, dass nur Rückkehr zur App geprüft wurde.
3. Falls **Metadata needs attention** erscheint, öffne die Meldung. Prüfe die
   Berechtigung des Testordners und einen eventuell genannten Dateikonflikt.
   Behebe nur den eigenen Testkonflikt und wähle die Metadaten-Wiederholung.
4. Kontrolliere danach, dass die Begleitdatei lesbar ist und die vorhandene
   Mediendatei gleich geblieben ist. Dateigröße und Änderungszeit helfen beim
   Vergleich; ohne Hash-/Anfragenachweis ist „nicht erneut geladen“ nur begrenzt
   belegt. Tritt kein Metadatenfehler auf, ist der Fehlerfall **nicht prüfbar**.
5. Nur in der entbehrlichen Testinstallation: Starte einen weiteren Download,
   beende die App während des laufenden Downloads über Android-App-Info und
   öffne sie erneut. Prüfe, ob der Download sinnvoll fortgesetzt oder verständlich
   zum Wiederholen angeboten wird und keine unvollständige Datei als fertig gilt.

**Erwartet:** Abgeschlossene Medien und Begleitdateien lassen sich öffnen. Nach
Metadaten-Wiederholung verschwindet die Fehlermeldung. Ein einzelner
Unterbrechungstest beweist nicht jede Absturz- oder Stromausfall-Situation.

## 14. Navigation, Tastatur, große Schrift und Dateiauswahl

- [ ] Die wichtigen Ansichten bleiben im Hoch-/Querformat und mit Tastatur bedienbar.

1. Gehe nacheinander durch Bildliste → Beitrag → Bookmarks → Einstellungen.
2. Wiederhole im Querformat und mit der großen Android-Schrift aus Test 5.
   Ein echtes Tablet muss, falls gewünscht, zusätzlich separat geprüft werden.
3. Öffne die Suche, tippe Text ein und lasse die Tastatur offen. Scrolle, wähle
   einen Vorschlag, führe die Suche aus und schließe die Tastatur mit Zurück.
4. Öffne einen Dialog mit Texteingabe, zum Beispiel zum Benennen eines
   Bookmark-Ordners. Tippe einen Testnamen ein und kontrolliere, dass du das Feld,
   Speichern und Abbrechen auch mit offener Tastatur erreichen kannst.
5. Öffne **Export and Import → Import file** und wähle deinen eigenen Export aus
   Android-Downloads. Prüfe die Vorschau, ohne unnötig erneut zu importieren.
   Wiederhole mit einem anderen Dokumentanbieter, sofern vorhanden, und brich
   einmal die Dateiauswahl ab.

**Erwartet:** Keine neuen Abstürze oder blockierten Schaltflächen. Zurück schließt
jeweils die oberste Ebene. Die Exportdatei lässt sich auswählen; Abbrechen bleibt
ohne Fehlermeldung. Langes-Menü-Scrollen und der bereits bekannte Zeilenumbruch
von „Download network“ bei großer Schrift sind keine neu eingeführten Fehler
und gehören nicht zu den hier behobenen Regressionen.

## 15. Aufräumen und Ergebnis notieren

- [ ] Eigene Teständerungen sind zurückgesetzt und Ergebnisse dokumentiert.

1. Stelle Schriftgröße, Rastergröße, Qualität, GIF-Autoplay, Downloadoptionen,
   PIN, Startseite, Metatags und Mirror-Regeln auf deine ursprünglichen Werte.
2. Entferne nur die von dir angelegten Test-Bookmarks, Profile, Ordner und Dateien.
   Stelle bei Bedarf den bisherigen Downloadordner wieder ein. Eine vorher
   fehlende Ordnerfreigabe lässt sich in der App möglicherweise nicht wieder
   auf „nicht gesetzt“ zurückstellen; notiere diese Ausnahme.
3. Halte für jeden Abschnitt fest: **bestanden**, **Fehler** oder **nicht prüfbar**.
   Bei Fehlern notiere Beitrag/Seite, gewählte Einstellungen, die Schritte davor
   und die sichtbare Meldung. Notiere keine PINs oder Zugangsdaten im Testbericht.
4. Bewahre den Sicherungsexport auf, bis du mit dem Ergebnis zufrieden bist.

Vorlage für deine Notizen:

| Test | Ergebnis | Beobachtung / Grund für nicht prüfbar |
| --- | --- | --- |
| Nummer und gegebenenfalls Teilprüfung | bestanden / Fehler / nicht prüfbar | kurze Notiz |

Die früheren Emulatoren wurden separat aufgeräumt und ihre Leases freigegeben.
Dort blieben die frischen Entwicklungsinstallationen, ein leerer Downloadordner
mit Android-Ordnerfreigabe und ein synthetischer eingeplanter WorkManager-Eintrag
zurück; die Details stehen im Prüfbericht. Diese Reste befinden sich nicht durch
diese Anleitung auf deinem Handy. Windows, macOS und iOS sowie der Maus-Rechtsklick
sind weiterhin eigene Prüfbereiche.
