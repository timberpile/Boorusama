# Configurable Post Viewer toolbar

Issue [#112](https://github.com/timberpile/Boorusama/issues/112).

## Editing a profile

Image Viewer Settings opens the toolbar editor. The profile dropdown starts on
the active supported profile and displays its name and icon. The selected profile
owns the draft and saved arrangement. Selecting another profile with edits offers
Save, Discard, and Cancel. Apply saves the current profile. Reset restores its
native toolbar.

The preview and the Toolbar and More sections use the selected profile's action
catalog. Drag handles reorder actions and move them between sections. When
Toolbar is full, dropping before a specific action swaps that slot. A drop at
the end of a full Toolbar leaves the draft as it was. The preview uses the
production renderer with inert controls.

## Profile data and resolution

`ViewerConfigs.toolbarLayout` stores optional versioned Toolbar and More action
IDs in the existing profile record. It is independent of `ViewerConfigs.enable`,
which controls image-viewer options. In-place upgrades and profile imports
without the field retain the native arrangement. The global trial layout was
absent from public release `v4.6.1-timberpile.4` and is omitted from this design.

Apply changes the toolbar field against the latest persisted profile. A newer
layout, a different site, or a removed profile rejects the stale draft. The
viewer's presentation profile supplies the saved arrangement for its current
post, including mixed-source viewers. Temporary loss of an action hides it in
the editor and viewer while preserving its stored section and relative order.
Newly available actions with no saved placement start in More.

## Engine capabilities and layout

Standard, Danbooru, Pixiv, and Szurubooru use stable IDs for their available
actions. The viewer uses actual post permissions and operations. Pixiv Favorite
can appear in either section and keeps its public, private, and remove actions.
Szurubooru retains its vote and remove-vote operations. Hydrus and the required
controls in group viewers continue through their native layouts.

More stays at the physical right. At narrow widths the visible row retains the
central contiguous run of available actions and places the outer actions in
More, with the left edge removed first on ties. This projection is transient.

## Acceptance

On Android, exercise profile switching, the unsaved prompt, cross-section drag
and swap at narrow width or enlarged text. Confirm Szurubooru vote behavior and
Pixiv's favorite visibility from both toolbar locations using approved accounts.
No Android or live-service acceptance is recorded for this revision.
