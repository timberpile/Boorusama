# Timeline evidence supplement — 2026-11-03

This supplements the [original 30-image set](../136-evidence/README.md); it does
not replace that audit or its Penpot board mappings. These ten reviewed captures
use safe public content and a temporary local Bookmark Group. See
[the manifest](manifest.json) for hashes, source/APK correspondence, theme and
device metadata. No account credentials or private content are included.

| Capture | Evidence and limits |
| --- | --- |
| [01: before](01-before-related-28.png) | Previous #145 APK: 28 dp Related/source overlay, separate Search Bar fill, info action. |
| [02: Midnight](02-midnight-24.png) | Corrected #139 APK: 24 dp aligned Collection/Series/Related overlays; one opaque Search Bar/Timeline Toolbar surface; no info action. Midnight is the applied AMOLED preset. |
| [03: Light](03-light-24.png) | Applied Light preset, dynamic color off; same three saved references. |
| [04: Dark](04-dark-24.png) | Applied Dark preset, dynamic color off. |
| [05: dynamic](05-dark-dynamic.png) | Applied Dark with Dynamic Theme Color enabled; this is a real timeline, not a theme preview. |
| [06: keyboard](06-dark-keyboard.png) | Narrow Bookmark search with a draft and the soft keyboard visibly open. Suggestions retain their own surface. |
| [07: Collection top](07-collection-top.png) | Existing embedded Collection navigation and Timeline Toolbar at the top. |
| [08: down](08-collection-down.png) | Existing Header hidden after downward scroll; media reaches behind the status bar. This demonstrates drift from the new opaque status-bar contract. |
| [09: reveal](09-collection-reveal.png) | Existing Header returns after slight upward scrolling; the Timeline Toolbar remains translucent. This is current behavior, not target acceptance. |
| [10: enlarged text](10-dark-large-text.png) | Applied Dark, system font scale 2.0; compact count fallback and horizontally scrollable toolbar. Keyboard is closed. |

Maestro controlled the exclusively leased Android 17 emulator at 360×800 logical
pixels (720×1600 physical, 320 dpi) in gesture-navigation mode. Installed current
APK hash matched the local build. The current runtime matches #139 `eb315fd69`;
the baseline was the previous #145 `f1412fa12` build. New saved references change
content between 01 and 02, so do not interpret them as an exact pixel diff.

The surface and badge correction is scoped to #139 and inherited by #145.
Broader runtime implementation remains deferred: [Browse overlap #146](https://github.com/timberpile/Boorusama/issues/146),
[Android system bars #147](https://github.com/timberpile/Boorusama/issues/147), and
[Header scrolling #148](https://github.com/timberpile/Boorusama/issues/148).
The [guide's capture matrix](../../ui_style_guide.md#required-timeline-capture-matrix)
is a future acceptance requirement. These captures do not cover all routes,
independent visibility preferences, bottom search, three-button navigation, RTL
on-device, physical devices or assistive input. There is no visual pass for
those missing cells.

The original global Midnight preset and dynamic-color-off state were restored.
Device restoration and removal of the temporary QA group are recorded in the
#139/#145 continuation handoffs. Normal navigation/search can change transient
history; this is not a byte-for-byte application-state restoration claim.
The original Colors “Default” representation became an explicit Midnight choice;
the editor has no action to restore that null override. Appearance is restored,
but this small preference representation difference remains.
