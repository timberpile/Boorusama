# Safebooru (Danbooru) als Profil-Preset anbieten

Priority: Normal
Affected feature: Profil-Erstellung / Website-Presets

## Problem und Ziel

`safebooru.donmai.us` ist bereits als Danbooru-Website registriert, fehlt aber im Preset-Picker. Die Website soll ohne manuelle URL-Eingabe auswählbar und eindeutig von `safebooru.org` unterscheidbar sein.

## Akzeptanzkriterien

- Der Preset-Picker bietet den Eintrag „Safebooru (Danbooru)“ an.
- Auswahl füllt die URL `https://safebooru.donmai.us/`, die Danbooru-Engine und den Profilnamen „Safebooru (Danbooru)“ aus.
- Anmeldung bleibt optional; die bestehenden Profil-Einstellungen lassen sich weiter bearbeiten und speichern.
- Der Eintrag verwendet die bestehende Preset- und Logo-Pipeline.
- Danbooru, Safebooru.org und die manuelle URL-Eingabe bleiben separat verfügbar.

## Kontext und Abgrenzung

Ergänzung zu [IDEA-030](../done/IDEA-030-popular-booru-profiles.md). Registrierung: `packages/booru_clients/boorus.yaml`; für diese URL fehlt der `quick-profile`-Block. Bookmark-Aliase und kontoübergreifende Favoriten sind separate Diskussionen.

Vor Umsetzung [Entwicklungsworkflow](../../development_workflow.md) beachten. Dieses Ticket ist unclaimed; die Umsetzung benötigt einen eigenen Branch/Worktree und einen Implementer gemäß den Queue-Regeln.

## Entscheidung

2026-10-05: Nutzer hat Anzeigename, vorbelegte URL/Engine/Profilname und optionale Anmeldung nach Einzelbesprechung bestätigt. Work Item erstellt; keine Umsetzung beauftragt oder erfolgt.
