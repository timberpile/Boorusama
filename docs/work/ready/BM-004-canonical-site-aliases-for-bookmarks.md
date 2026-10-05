# Gemeinsame Post-Datenbank-Identität für bekannte Website-Aliase

Priority: Normal
Affected feature: Website-Verzeichnis, Bookmark-Identität und Profil-Kompatibilität

## Problem und Ziel

Bookmarks desselben Upstream-Posts sollen über unterschiedliche Zugänge derselben Post-Datenbank dieselbe Identität haben. Der Nutzer nennt `danbooru.donmai.us` und `safebooru.donmai.us` als Beispiel. Aktuell unterscheidet die Bookmark-Identität normalisierte Website und stabilen Post-Key. Gleichzeitig müssen identische Dateien auf unabhängigen Websites getrennte Bookmarks bleiben.

Die gemeinsame Zuordnung wird auch für die Auswahl kompatibler Zielprofile bei „Favorite with…“ benötigt.

## Vereinbartes Design und Akzeptanzkriterien

- Ein zentrales, repository-eigenes Website-Verzeichnis ordnet bestätigte Domain-Aliase derselben Post-Datenbank einer stabilen internen Kennung zu, z. B. `danbooru-main`.
- Nur die mitgelieferte Liste wird verwendet; keine Nutzeroberfläche oder Konfiguration für eigene Alias-Zuordnungen anbieten.
- Bookmark-Identität besteht aus der kanonischen Datenbank-Kennung und dem stabilen Upstream-Post-Key. Bestehende zusammengesetzte Keys wie Pixiv-Seiten bleiben erhalten. MD5, Medien-URL und Profil-ID sind keine Identitätskomponenten.
- Für nicht registrierte Websites bleibt der normalisierte Website-Namespace einschließlich relevantem Port und Installationspfad der Fallback. Kein vollständiger Katalog aller Boorus erforderlich.
- Zuerst die gemeinsame Post-Datenbank und stabilen Post-Keys von Danbooru und dessen Safe-Zugang anhand maßgeblicher Site-Informationen bzw. API-Beispielen bestätigen und die Zuordnung aufnehmen. Safebooru.org, Test-Instanzen und unabhängige Danbooru-Installationen nicht versehentlich gleichsetzen. Gleiche Engine, gleicher physischer Server, gleicher MD5 oder Redirect allein sind kein Nachweis.
- Derselbe Post-Key über bestätigte Aliase ergibt einen Bookmark. Andere Post-Keys bleiben getrennt, auch bei gleichem Bildinhalt; unabhängige Websites bleiben selbst bei gleichem Post-Key und MD5 getrennt.
- Bekannte Domainwechsel können durch neue Alias-Einträge die stabile Identität erhalten. Unbekannte Umzüge werden nicht automatisch geraten. Wartungsort, Nachweisanforderung und Regel für kollisionsfreie interne Kennungen dokumentieren.
- Vorhandene Bookmarks und aktuell unterstützte Export-/Importdaten werden konsistent auf die neue Identität überführt. Duplikate derselben bestätigten Identität verlieren keine Gruppenmitgliedschaften; lokale Referenzen werden korrekt remappt. Regeln für konkurrierende Snapshots und erforderliche Schema-/Migrationsänderungen vor Umsetzung festlegen und reviewen.
- Live-Lookup, Speicherung, Export und Import verwenden dieselbe kanonische Identität. Bestehende Prüfungen zwischen exportierter Identität und Post-Snapshot bleiben wirksam; kein genereller Verzicht auf Validierung.
- Tatsächliche Herkunfts-URL, Ziel-Host, Profil-/Account-Auflösung und Sichtbarkeitsregeln bleiben getrennt von Bookmark-Gleichheit. Alias-Gleichheit darf keine Credentials automatisch an andere Hosts weiterreichen oder Safe-Zugriffsregeln umgehen.
- „Favorite with…“ verwendet dasselbe Verzeichnis für die Datenbank-Kompatibilität, prüft zusätzlich die Favoritenfähigkeit und Berechtigungen des gewählten Zielprofils.

## Kontext und Abhängigkeiten

Erweiterung von [IDEA-004 stabile Bookmark-Identität](../done/IDEA-004-stable-bookmark-post-identity.md). [Bookmark-Regeln](../../bookmark_groups.md), [Post-Architektur](../../post_architecture.md). Liefert die gemeinsame Website-Zuordnung für [POST-011 Favorite with…](POST-011-favorite-with-another-profile.md).

Vor Umsetzung [Entwicklungsworkflow](../../development_workflow.md) und [Engineering Guidelines](../../engineering_guidelines.md) beachten. Dieses Ticket ist unclaimed; Umsetzung benötigt einen eigenen Branch/Worktree und einen Implementer gemäß Queue-Regeln. Die Architektur- und Migrationsdetails werden vor Produktänderungen konkretisiert und reviewt.

## Entscheidung

2026-10-05: Nach Einzelbesprechung hat der Nutzer eine zentrale, mitgelieferte Alias-Liste ohne eigene Nutzer-Zuordnungen bestätigt. Die besprochene Richtung umfasst stabile Datenbank-Kennungen, Website-Namespace als Fallback, kein MD5-Matching und ausdrücklich registrierte Domainwechsel. Work Item erstellt; Alias-Nachweise, genaue Migrationsregeln und Umsetzung noch nicht durchgeführt.
