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

Vor Umsetzung [Entwicklungsworkflow](../../development_workflow.md) und [Engineering Guidelines](../../engineering_guidelines.md) beachten. Produktimplementierung folgt erst nach Mockup-Freigabe und benötigt einen Implementer gemäß Queue-Regeln.

## Entscheidung

2026-10-05: Nutzer hat die kompakte Darstellung, reine Bookmark-Anzahlen pro Gruppe und den Verzicht auf die Unterscheidung zwischen vollständiger Löschung und Gruppenentfernung bestätigt. Vor Umsetzung ist ein HTML-Mockup zur gemeinsamen Detailbesprechung erforderlich. Work Item erstellt; Mockup und Produktimplementierung noch nicht erstellt oder freigegeben.

## Claim und Fortschritt

- Coordinator/session: /root, 2026-10-05 priority program.
- Implementer: /root/data015.
- Branch: feature/data-015-import-preview.
- Dedicated worktree: /home/timber/code/Boorusama/.worktrees/data-015-import-preview.
- Base: local develop 46a20296bdd74c5eaf99f8917d1a1d1f69c0d0cd.
- Current phase: Produktimplementierung und Nutzerreview abgeschlossen; lokale Integration freigegeben.

## HTML-Designphase · 2026-10-05

- Review artifact: [compact import preview mockup](../../superpowers/mockups/2026-10-05-compact-import-change-preview.html).
- External copy: `/tmp/boorusama-priority-program-2026-10-05/data015-mockup.html`; rationale, verification and limitations: `data015-report.md` in the same directory.
- Sample complete-category Replace shows extensive narrow-screen content, concrete added/removed/renamed groups and membership totals, individual pins/folders/feeds/profiles, readable settings keys, masked profile credentials, and scoped blacklist rules. Alternate invented Update/Merge/Copy/Skip/identical/stale-plan states demonstrate effects and hidden no-ops. Update follows reviewed BM-005 behavior: preserve local group name and UUID.
- Verification: actual inline-script scenario assertions in Node VM/DOM stub passed; `git diff --check` passed. No browser renderer available in checked conventional locations, so screenshots and rendered narrow/wide overflow checks remain unverified. No installs, Flutter changes, builds, or devices used.
- Current gate: mockup awaits coordinator and explicit user design review/approval. Product implementation has not started; task remains in-progress.

## Rendered mockup verification · 2026-10-06

- Later bounded rendering with an already installed Windows Edge browser succeeded in a unique temporary browser profile. Seven actual captures cover extensive Replace at 280/390/1200 CSS pixels, expanded details at 280/390, Merge and Skip. The earlier lack of browser-render evidence is superseded by these captures.
- Root independently inspected the 280px expanded top/bottom captures: names and membership counts wrap, concrete settings/blacklist changes remain readable, credential values stay masked, and Cancel/Import fit at the document bottom. Long lists require vertical scrolling. Keyboard/focus interaction was not tested.
- External evidence: `/tmp/boorusama-priority-program-2026-10-05/data015-render-report.md` and `data015-render-owned/` screenshots, metrics and cleanup records. Root verified external/repository HTML SHA256 both `49b79eda562004eeb6929f878ee2d3ae7e6ee96496fc868f016b534c7699ae14`; source unchanged. Owned browser process count0/server closed/profile directories removed; existing browser state and other port owners preserved.
- This verifies the sample design rendering only. Explicit user approval of the discussed layout remains pending; no Flutter/product implementation or integration has started.

## Mockup-Rückmeldung umgesetzt · 2026-10-07

- Nutzer bestätigt die bestehende Richtung und wünscht unabhängige Kategorien-Akkordeons sowie einen insgesamt aufklappbaren, standardmäßig geschlossenen Bereich „Planned changes“. Beides ist im HTML-Mockup umgesetzt; Kategorien beginnen ebenfalls geschlossen. Jede geschlossene Zusammenfassung zeigt ihre Gesamtanzahl und grüne `+`, rote `−` und blaue `↔` Teilanzahlen. Einzelzeilen und ihre bisherigen Mitgliedschaftszähler bleiben erhalten.
- Revision implementer/session: /root/data015_mockup_revision, coordinated by /root; existing branch/worktree claim resumed.
- Zählregel: Bookmark-Mitgliedschaften zählen einzeln, zusätzlich neue/gelöschte Gruppen und tatsächliche Umbenennungen. Eine reine Mitgliedschaftsänderung zählt keine zusätzliche Gruppenänderung. Andere Elemente zählen einmal; aufklappbare Ordner-/Feed-Details erklären diese Änderung und werden nicht doppelt addiert.
- Beispielsummen: Replace insgesamt 136 (`+73 −55 ↔8`), Bookmark groups 113 (`+64 −48 ↔1`), Pinned searches 5 (`+3 −2 ↔0`). Update 16 (`+12 −4 ↔0`), Merge 12 (`+12 −0 ↔0`), Copy 29 (`+29 −0 ↔0`: 28 Mitgliedschaften und eine Gruppe). Ohne Bookmark-Auswahl insgesamt 23; Skip/identisch zeigen 0 und deaktivieren Import.
- Verification: actual inline-script Node assertions cover all scenarios, totals, inclusion/mapping updates, masked values, stale review, cancellation and initial accordion markup. Actual installed Edge assertions verify native open/close behavior, category independence, child state retention across overall collapse, scenario totals and selection/mapping/masking/stale flow. Eight fresh captures at 280/390/1200 CSS pixels show collapsed overall, collapsed categories, expanded bookmark/detail rows, Merge and Skip; no document horizontal overflow. Keyboard CDP injection remained inconclusive; keyboard interaction is not claimed as verified. `git diff --check` passed.
- Evidence: `/tmp/boorusama-priority-program-2026-10-05/data015-revision-verify.js`, `data015-revision-render/` screenshots/metrics/capture log/cleanup, and `data015-revision-report.md`. Updated external `data015-mockup.html` matches the repository artifact. Browser used a dedicated temporary profile; owned browser processes/server/profile cleaned up, existing browser state preserved.
- Current phase remains mockup review. No Flutter/product implementation, commit, integration or publication; ticket remains in-progress pending final design approval before product implementation.

## Produktimplementierung freigegeben · 2026-10-07

- Nutzer: „Ok das sieht so gut aus. Das kannst du so mal implementieren.“ Revidiertes Mockup explizit freigegeben; Produktimplementierung auf dieser Grundlage autorisiert.
- Coordinator: /root. Implementer/session: /root/data015_mockup_revision. Bestehender Claim/Worktree/Branch fortgesetzt.
- Branch auf aktuellen lokalen develop `d1eb12c33ec4a9f845d5b3e49e2c20f65d0531e7` aktualisiert; alle vorherigen dirty Mockup/Ticket/BM-005-Dateien mit explizitem Stash und separatem Snapshot erhalten und SHA256-verifiziert wiederhergestellt. Sicherheitsstash bleibt vorerst bestehen. AGENTS/Workflow nach Rebase erneut gelesen.
- [Umsetzungsplan](../../superpowers/plans/2026-10-07-compact-import-change-preview.md): zusammenhängende Implementierung mit unveränderter Transaktions-/Revisionsprüfung und separaten Vorschau-Zählregeln. Coordinator hat Architektur geprüft und Ausführung freigegeben.

## Produktimplementierung und Review-Evidenz · 2026-10-07

- Freigegebenes Layout in Flutter umgesetzt: Gesamtbereich und Kategorien starten geschlossen, lassen sich unabhängig öffnen und zeigen Gesamtzahl sowie farbige `+`, `−`, `~` Teilzahlen auch geschlossen. Kategorienzustände bleiben beim Schließen/Öffnen des Gesamtbereichs erhalten. Relevante Elementdetails sind zusätzlich aufklappbar; englische/deutsche Texte mit `./gen.sh i18n` generiert.
- Vorschau folgt den tatsächlichen aufgelösten Executor-Auswirkungen. Gruppen zählen Mitgliedschaften plus neue/gelöschte Gruppen bzw. tatsächliche Umbenennungen; reine Mitgliedschaftsänderungen zählen keine zusätzliche Gruppenänderung. Sonstige Bookmark-Änderungen erscheinen aggregiert als „No Group“/„Bookmark data“, ohne Einzelbookmark-Liste. Profilzuordnungen vorhandener Bookmarks werden berücksichtigt. Suchen werden ausschließlich innerhalb ihrer Ordner/Home bzw. Feeds gezeigt und einzeln gezählt; reine Inhaltsänderungen zählen den Container nicht zusätzlich. Neue/gelöschte Container und echte Metadatenänderungen zählen separat; Home selbst zählt nie. Profilbezogene Blacklist-Regeln sind konkrete `+`/`−` Details einer gezählten Profiländerung.
- Settings zeigen konkrete interne Keys mit lesbaren Werten, globale Blacklist/Favoriten konkrete ersetzte Elemente einschließlich lokal fehlender Löschungen. Verschachtelte Zugangsdaten/Header und URL-Geheimnisse werden vor Darstellung maskiert; Änderungen bleiben erkennbar. SQLite zeigt ausdrücklich eine Datenbank-Ersetzung statt erfundener Zeilenzahlen.
- Veraltete Revision bricht weiterhin vor Anwendungsdaten-Schreibvorgängen ab. Der bereits verifizierte Staging-Inhalt wird mit frischem lokalem Zustand neu geplant, gültige Entscheidungen/Profilzuordnungen bleiben erhalten, Warnungsbestätigung wird zurückgesetzt. Danach ist ein zweiter ausdrücklicher Import nötig; funktioniert auch, wenn die ursprüngliche empfangene Datei bereits gelöscht wurde.
- Verification: 74 fokussierte Tests erfolgreich (`/tmp/data015-product-focused2.log`); nach rein mechanischer Lint-Korrektur 39 betroffene Tests erfolgreich (`data015-product-mechanical-verification.log`). Abschließend 34 Projector-/Widget-Tests erfolgreich (`data015-product-final-detail-tests2.log`), einschließlich tatsächlich aufgeklappter langer URL-/maskierter Credential-Details bei 280px und doppelter Textgröße, unabhängiger Akkordeons und Zustandserhalt. Scoped analysis: keine Fehler/Warnungen, 23 informative Style-Lints (`data015-product-final-analysis4.log`); `git diff --check` erfolgreich.
- Independent review: `/tmp/data015-product-review.md`, keine bestätigten blockierenden Findings. Die dort benannte begrenzte Detail-Widget-Testlücke wurde anschließend mit obigem konkreten Test geschlossen. Ausführlicher Implementierungs-/Verifikationsbericht: `/tmp/data015-product-report.md`.
- Nutzerreview abgeschlossen; lokale Integration am 2026-10-07 mit „ok, ready to merge“ freigegeben. Kein APK-/Emulator-/manueller Geräte-Test und keine Publikation. Ursprünglicher BM-005-Backlink im Integrations-Snapshot erhalten; Link zeigt nach Abschluss auf dieses Done-Ticket.

## Abschluss und lokale Integration · 2026-10-07

- Nutzerkorrekturen umgesetzt: kein Hinweistext; Pins und Ordner unter Pinned Searches; Searches ausschließlich innerhalb ihrer Ordner/Home bzw. Feeds mit gemeinsamer Darstellung. Individuelle Suchänderungen zählen einzeln, Container nur bei Erstellung/Löschung oder eigenen Metadatenänderungen. Beispiel: neuer Feed mit zwei Suchen `+3`, eine zusätzliche Suche im vorhandenen Feed/Ordner `+1`. Änderungen überall als blaues `~`; Importaktion „Custom“/„Einzeln“.
- Fokussierte Abschlussprüfungen: 53 Projector-/Widget-/Query-Tests bestanden, einschließlich 280px und doppelter Textgröße; danach alle sechs Widget-Tests für die Symboländerung bestanden. Analyse ohne Fehler oder Warnungen. Mockup aktualisiert und alle sieben Szenarien geprüft.
- Lokale Squash-Integration auf develop mit den vorhandenen Thumbnail-Änderungen geprüft: 94 Tests in neun direkt betroffenen Dateien bestanden (`/tmp/data015-integration-tests.log`); Analyse ohne Fehler/Warnungen, 32 informative Style-Lints (`/tmp/data015-integration-analysis.log`). Feature-Dateien bytegleich geprüft, bestehende develop-Änderungen erhalten, `git diff --check` erfolgreich. Keine Remote-Änderungen autorisiert.
