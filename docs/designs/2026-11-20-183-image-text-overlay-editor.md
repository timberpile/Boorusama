# Simple Image Text Editor — #183

Status: **Design draft for owner review; not implemented.**
Issue: https://github.com/timberpile/Boorusama/issues/183
Depends on: #180.

## Goal and deliberately limited V1

Quickly caption an existing still image while viewing it in Boorusama, then save a separate image into Local Media. The target interaction is a direct-manipulation overlay (similar in simplicity to Snapchat's basic text placement), **not** a general-purpose photo or video editor.

- Open from an available local or remote still-image Post. Resolve the correct source media/auth and existing exact original/sample quality using the current Post origin, never an unrelated globally selected profile.
- Enter white text. Provide **2–3 font choices**, a **visible dark drop shadow**, drag to reposition and pinch/resize to scale. The text placement must be clear on small images and enlarged screens.
- V1 can use one editable text overlay at a time; do not build a complex layer stack, timeline, effects gallery, filters or animated text.
- Show an accurate live preview with the same visible text, shadow and placement that the encoder writes. Keep rotation, aspect ratio and output dimensions sensible; text should not unexpectedly clip or move when exporting.
- Save the result as a **new Local Media item** via #180; never modify original media bytes or replace a remote Post.

## Metadata / identity

- Copy meaningful semantic metadata from the source (tags and categories, rating if known, relevant source information) to the **new** local item. Recalculate SHA-256, MD5, format, size, dimensions and timestamps for the output rather than copying the original byte identity.
- An optional plain `sourceMd5` field can record the exact source image's MD5, from source metadata only when it genuinely describes the edited input bytes, or from those bytes while editing. Do not invent a generalized `derivedFrom` link/parent graph.
- A simple editor-created marker may be useful for filtering, but do not require multiple redundant provenance fields or server post IDs. Do not silently embed unrelated private/local path metadata in output image EXIF.
- The saved local item can subsequently use #182's sharing flow.

## UI and behavior

Use established Kurumi actions and localized short labels (e.g. **Save**, **Cancel**). Keyboard-driven text editing must not obscure the overlay or trap focus. Provide a straightforward way to correct text/placement before saving; Back/Cancel discards the draft without saving anything. Progress/errors and retry must not publish a partial local file.

Keep editor storage/transient previews separate from the library until Save completes. For remote sources, respect access revocation and avoid silently downloading a lower-quality sample while labeling it original.

## Acceptance / tests

- Text rendered in white with an obvious dark shadow, each font, drag/scale, image rotation, small screens, large text, IME open, cancellation, save/reopen consistency.
- Remote and local originals unchanged, valid output in Local Media with new SHA-256, inherited meaningful metadata, and optional source MD5; duplicate edits of byte-identical results dedupe normally.
- Network/auth failures and unavailable original media fail safely; no stray partial files.
- Native codec/rendering/platform coverage must be established during implementation; source inspection here is not a device test.

## Deferred

GIF/video overlay editing, video-frame extraction, complex text animation, filters, other colors, typography controls and multi-track editing are outside this initial issue. Reevaluate those only after the simple still-image flow succeeds.
