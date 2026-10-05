# Thumbnail-Overlays vereinheitlichen und Favoriten-Icon verkleinern

Priority: Normal
Affected feature: Post-Thumbnails / Profil-Icons, Status-Badges und Quick Favorite

## Problem und Ziel

Thumbnail-Overlays verwenden unabhängig geregelte Größen: geladene Profil-/Website-Icons 32, gebündelte Logos 28, Status-Badges 24 logische Pixel. Das Fehler-Globus-Symbol hat bei einer 32er Außenfläche eine Referenzgröße von 26. Die Icons sollen weniger Bild verdecken und einheitlich groß erscheinen; das Favoriten-Icon soll ebenfalls kleiner werden.

## Vereinbarte Zielmaße und Akzeptanzkriterien

- Profilbilder, Website-Logos, Fehler-/Ladeplatzhalter und quadratische Status-Badges auf Thumbnails haben ein gemeinsames Außenmaß von 20 × 20 logischen Pixeln. Bildinhalte werden nicht verzerrt.
- Symbole innerhalb der Status-Badges verwenden grundsätzlich 16 logische Pixel. Der GIF-Schriftzug darf bei Bedarf etwas größer sein, bleibt aber innerhalb derselben Außenfläche lesbar.
- Video-Dauer mit Tonsymbol und AI-Kennzeichnung erhalten dieselbe Höhe von 20; ihre Breite richtet sich nach dem lesbaren Inhalt. Keine feste quadratische Breite für Text erzwingen.
- Das Quick-Favorite-Herz erhält eine explizite Größe von 20 und einen kleineren sichtbaren Hintergrund mit passendem Padding. Die Touch-Fläche bleibt ausreichend groß; Animation, Ladezustand und Favoritenfunktion bleiben nutzbar.
- Die Größenregel gilt konsistent für die betreffenden Thumbnail-Overlays, einschließlich gemischter Bookmark-Grids und anderer Nutzer dieser Darstellung. Website-Logos und Icons außerhalb von Thumbnails behalten ihre bisherigen Maße.
- Die Maße werden über eine gemeinsame, auf Thumbnail-Overlays begrenzte Regel geführt. Nicht die globalen Website-Logo-Konstanten ändern, um einen Thumbnail-Anwendungsfall zu lösen.
- Eigene Profilbilder, gebündelte Logos, Netzwerk-Logos, Fehler-/Ladezustände, GIF, Video mit/ohne Dauer, Kommentare, Übersetzung, Bildserie, AI sowie Favoritenzustände sichtbar prüfen. Kleine Kacheln und längere Dauerangaben dürfen keine Überläufe oder unlesbaren Inhalte erzeugen.

## Umsetzbarkeit und Review

Der Nutzer hat diese Zielmaße unter der Bedingung einer sauberen Umsetzung bestätigt. Vor Änderungen die bestehenden Constraints und das Verhalten von LikeButton prüfen. Falls ein Zielmaß Lesbarkeit, Layout oder Bedienbarkeit beeinträchtigt, die konkrete Abweichung beim Review zeigen und begründen; keine stillschweigende globale Größenänderung. Vorher/Nachher-Darstellung dient der visuellen Abnahme.

## Kontext

[Post-Architektur](../../post_architecture.md). Betroffene Einstiegspunkte: `lib/core/config_widgets/website_logo.dart`, `lib/core/widgets/website_logo.dart`, `lib/core/bookmarks/src/widgets/bookmark_scroll_view.dart`, `lib/core/posts/post/src/widgets/image_overlay_icon.dart`, `lib/core/posts/post/src/widgets/image_grid_item.dart`, `lib/core/videos/player/src/widgets/video_play_duration_icon.dart` und `lib/core/posts/favorites/src/widgets/quick_favorite_button.dart`.

Vor Umsetzung [Entwicklungsworkflow](../../development_workflow.md) und [Engineering Guidelines](../../engineering_guidelines.md) beachten. Dieses Ticket ist unclaimed; Umsetzung benötigt einen eigenen Branch/Worktree und einen Implementer gemäß Queue-Regeln.

## Entscheidung

2026-10-05: Nach Einzelbesprechung vom Nutzer bestätigt, sofern sauber umsetzbar. Work Item erstellt; keine Umsetzung beauftragt oder erfolgt.
