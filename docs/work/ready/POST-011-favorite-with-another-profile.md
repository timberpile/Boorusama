# „Favorite with…“ per Gedrückthalten des Favoriten-Buttons

Priority: Normal
Affected feature: PostViewer / kontogebundene Server-Favoriten

## Nutzerfall und Ziel

Beim Browsen mit einem unsicheren Profil wird ein sicherer Post gefunden. Der Nutzer möchte ihn gezielt mit einem anderen, sicheren Profil/Konto favorisieren, ohne die aktuelle Ansicht zu verlassen.

## Vereinbartes Verhalten und Akzeptanzkriterien

- Im PostViewer öffnet Gedrückthalten des Favoriten-Buttons ein Kontextmenü „Favorite with…“ mit kompatiblen anderen Profilen. Normaler Tap bleibt unverändert.
- Die Aktion ist nur verfügbar, wenn mindestens ein anderes Profil derselben Post-Datenbank Favorisieren unterstützt. Gleiche Engine oder ähnliche Domain allein reichen nicht; Profile unabhängiger Websites ausschließen.
- Profilnamen und nötige Website-/Kontozuordnung machen das Ziel verständlich. Die Auswahl verwendet ausschließlich die Zugangsdaten des gewählten Zielprofils, niemals einen stillen Fallback auf das Ausgangskonto.
- Der Post wird im Zielkonto favorisiert, ohne Browse-Profil, Position oder aktuellen Post zu wechseln. Ein bereits dort favorisierter Post wird nicht entfavorisiert; die Aktion ist kein Toggle.
- Zielzugang und dessen Sichtbarkeits-/Rating-Regeln beachten. Nicht erreichbare Posts oder fehlende Berechtigung verständlich melden; keine Umgehung über Credentials eines anderen Profils.
- Favoritenstatus und Cache bleiben dem jeweils betroffenen Konto/Profil zugeordnet. Erfolg im Zielkonto darf keinen falschen Favoritenstatus im Ausgangskonto anzeigen.
- Abbruch verändert keine Favoriten. Fehler bleiben diagnostizierbar und ein erneuter Versuch ist möglich.
- Thumbnail-Favoriten-Buttons nur ergänzen, wenn dieselbe Lösung sehr einfach und ohne größeren Zusatzaufwand verwendbar ist. PostViewer ist der Pflichtumfang; fehlende Thumbnail-Unterstützung ist kein Blocker. Entscheidung und Gründe beim Review benennen.

## Gemeinsame Website-Zuordnung und Abhängigkeit

Kompatibilität soll aus einer zentralen Zuordnung bestätigter Domain-Aliase zu derselben Post-Datenbank stammen. Beispielsweise sind `danbooru.donmai.us` und `safebooru.donmai.us` dafür zu prüfen. Diese Zuordnung wird auch für Bookmark-Identität gebraucht; ihr Design wird als eigener Punkt mit dem Nutzer besprochen und ist noch nicht freigegeben.

Alias-Gleichheit erlaubt keine automatische Weitergabe von Credentials an andere Hosts. Ursprüngliche Herkunft, tatsächlicher Ziel-Host und Account-Auflösung bleiben getrennt von der Datenbank-Identität. Zwei lokale Profile desselben Serverkontos erzeugen keine getrennten serverseitigen Sammlungen; keine solche Trennung behaupten.

## Kontext

[Post-Architektur](../../post_architecture.md), [POST-007 kontogebundene Favoriten](../done/POST-007-key-moebooru-favorites-by-profile.md). Verwandt mit [IDEA-010](IDEA-010-fetch-server-favorites-to-bookmark-groups.md), aber kein Bulk-Fetch oder Synchronisationsauftrag.

Vor Umsetzung [Entwicklungsworkflow](../../development_workflow.md) und [Engineering Guidelines](../../engineering_guidelines.md) beachten. Dieses Ticket ist unclaimed; Umsetzung benötigt einen eigenen Branch/Worktree und einen Implementer gemäß Queue-Regeln. Gemeinsame Website-Zuordnung vor kompatibilitätsabhängiger Umsetzung klären.

## Entscheidung

2026-10-05: Nutzer hat „Favorite with…“ als Hold-Kontextmenü bestätigt, PostViewer als Pflichtumfang und Thumbnail-Unterstützung nur bei sehr einfacher Wiederverwendung. Work Item erstellt; Produktimplementierung nicht beauftragt oder erfolgt. Das separate Website-Verzeichnis ist noch zu besprechen.
