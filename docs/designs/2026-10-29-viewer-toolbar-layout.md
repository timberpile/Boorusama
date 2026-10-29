# Configurable Post Viewer toolbar

Issue: [#112](https://github.com/timberpile/Boorusama/issues/112).
The user approved trying a visual arrangement editor, not an abstract action
priority list. This document captures the approved behavior and the remote
implementation's trial choices. Device acceptance is still required.

## Placement rather than priority

The editor has a live toolbar preview, a row of configured slots, and ordered
More actions. Users can drag to rearrange either section, drag between sections,
or select an action and use localized move/transfer controls. A full toolbar
requires choosing a replacement slot; its former action moves into the source's
More position. No action is deleted. Back discards the draft; Apply persists it.
Reset clears the customization and closes the editor.

The five-action trial limit matches the approved mockup. The editable seed is
Comments, Download, Bookmark, Favorite, Share. Merely opening the editor does
not install this seed. Existing installations and Reset continue to use each
engine's native order and visibility rules, including Danbooru's distinct row.

## Responsive projection

More remains at the physical far right, including RTL locales. Custom toolbars
reserve a 48-dp More target, 8-dp gaps, and at least 48 dp per ordinary action.
The middle contiguous run of configured, currently available actions stays
visible; outer actions move into More. On an equal-distance tie, remove the
left outer action first. Temporary overflow entries precede explicitly stored
More entries, preserving each group's order. Resizing never writes settings.

Availability is taken from the existing engine toolbar, not inferred by the
editor. Unauthorized/unsupported commands do not leave holes, and their saved
positions return when available again. Find on Other Profiles, Settings, and
any existing fixed utility entries remain in More. The preview uses inert
catalog actions, not live requests or account mutations; it demonstrates the
layout rather than claiming every action is supported by the current site.

## Storage and integration

`Settings.viewerToolbarLayout` is global and nullable. It is deliberately not
part of profile-level `ImageViewerSettings`/`ViewerConfigs`. The optional JSON
object contains `version: 1`, `toolbar`, and `more`, using stable action names.
Missing/malformed/unsupported schemas retain native defaults. Duplicate and
unknown IDs are ignored; known missing actions are appended to More. Both lists
are immutable. Normal settings serialization carries the value into backups.

Only standard and Danbooru viewer rows opt into the new renderer. Moebooru uses
the standard renderer already. Generic application adaptive rows are unchanged.
Bookmark, Favorite, Share, and Download gain menu presentations that reuse their
existing operations; Download keeps its quality submenu. Other typed actions
retain explicit callbacks, including conditional vote removal.

## Trial boundaries

The editor uses existing translated action/UI labels and framework-localized
move descriptions. No new locale generation or dependency is introduced.
Editable slots can scroll horizontally instead of shrinking touch targets; the
preview independently reflects the actual available width. This is intentionally
a compact settings page, not a copy of the mockup's desktop demonstration shell.

Validate the five-action limit, central retention, and editor affordances on
320/390/440-dp layouts, enlarged text, touch, keyboard, and RTL before finalizing.
Check popup lifetimes, engine-specific actions, mixed-origin viewers, and all
menu variants on an actual Android build. No remote Flutter or device pass is
claimed by this design document.
