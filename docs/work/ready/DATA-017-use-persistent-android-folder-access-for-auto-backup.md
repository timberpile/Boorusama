# Automatische Backups mit dauerhaftem Android-Ordnerzugriff speichern

Priority: Normal
Affected feature: Auto Backup auf Android

## Problem

Auto Backup speichert einen Dateisystempfad und verwendet direkte Dateioperationen. Die Freigabe eines Ordners im Android-Systemdialog wird dabei nicht als dauerhaft nutzbarer Dokumentenbaum verwendet. Deshalb können ausgewählte Ordner unter Scoped Storage trotz Freigabe nicht beschreibbar sein. Die Empfehlung, Downloads oder Documents zu verwenden, beschreibt eine Einschränkung der aktuellen Implementierung und keine allgemeine Android-Regel. Die gemeinsame Pfadprüfung akzeptiert außerdem Pictures.

Der manuelle Export erhält einen separaten Fix auf `fix/android-export-save`. Dieser behebt Auto Backup nicht: Automatische Backups müssen auch nach einem App-/Geräteneustart ohne erneuten Dialog auf den gewählten Ordner zugreifen und dort Backups sowie das Manifest verwalten können.

## Reproduktion

1. Auf Android 11 oder neuer in Auto Backup einen vom System angebotenen Ordner auswählen und Zugriff erlauben.
2. Ein Backup auslösen und den tatsächlichen Inhalt des Zielordners prüfen.
3. Nach App-/Geräteneustart erneut prüfen, ob automatische Backups geschrieben werden können.

Direkter Pfadzugriff garantiert trotz erteilter Ordnerfreigabe keinen Erfolg. Die konkrete Fehlermeldung und das Verhalten nach Neustart sind bei Umsetzung gezielt zu reproduzieren.

## Erwartetes Verhalten und Akzeptanzkriterien

- [ ] Android verwendet den vom System freigegebenen Dokumentenbaum mit dauerhaft erhaltener Lese-/Schreibberechtigung. Vom System gesperrte Ziele bleiben gesperrt; keine pauschale Beschränkung der App auf Downloads/Documents.
- [ ] Backup-Dateien, Unterordner und Manifest werden über diesen Zugriff erstellt, gelesen, aufgelistet und gelöscht. Bestehende Aufbewahrungsregeln und Backup-Inhalte bleiben korrekt.
- [ ] Automatische Backups funktionieren nach App-/Geräteneustart ohne erneuten Auswahldialog, solange die Berechtigung und das Ziel verfügbar sind.
- [ ] Bei entzogenem Zugriff, nicht verfügbarem Ziel oder Schreibfehler wird kein erfolgreicher Backup-Status gemeldet. Die UI zeigt einen verständlichen lokalisierten Fehler und ermöglicht erneute Ordnerauswahl.
- [ ] Bestehende gespeicherte Pfade werden sicher behandelt: falls erneute Freigabe nötig ist, vor Schreib-/Löschoperationen verlangen; vorhandene Backups nicht verlieren. Abbruch verändert keine Backup-Dateien.
- [ ] Die UI-Hinweise erklären die tatsächliche Ordnerfreigabe und behaupten keine allgemeine Android-Beschränkung auf Downloads/Documents. Nicht-Android-Verhalten bleibt erhalten; keine umfassende Speicherberechtigung hinzufügen.
- [ ] Fokussierte Tests decken Berechtigungsverlust, Schreibfehler, Manifest und Aufbewahrung ab. Android-Validierung umfasst mehrere erlaubte Ziele sowie einen Neustart mit erhaltener Freigabe.

## Kontext

- [Export-/Import-Design](../../superpowers/specs/2026-10-01-unified-export-import-design.md)
- `lib/core/backups/auto/widgets.dart`, `lib/core/backups/auto/repo_io.dart`
- `lib/core/downloads/path/src/validator.dart` und gemeinsame Pfadwarnungen
- [Android: Zugriff auf Dokumente und dauerhafte Berechtigungen](https://developer.android.com/training/data-storage/shared/documents-files#persist-permissions)

## Entscheidung

2026-10-06: Nutzer möchte dieses Problem zunächst als Ticket erfassen und später beheben. Unclaimed; keine Implementierung in dieser Sitzung.
