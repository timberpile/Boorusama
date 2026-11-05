# Visual Explainer Style Guide

Status: **approved authoring workflow**, not an approved application UI design or an architecture implementation. This guide covers diagrams, illustrated explanations and exploratory mockups. App UI still follows [Boorusama UI Style Guide](../ui_style_guide.md), Kurumi conventions and current code.

## The three-stage workflow

Choose the format by **purpose**, not by a desire to make every illustration editable immediately.

### 1. Discussion: image first

For exploratory architecture explanations, UI concepts and comparisons, generate an explanatory image first when a visual is useful.

- Show the **actual information hierarchy**: a clear heading, relevant concept groups, meaningful relationships, short labels, visual examples and concise callouts.
- Prefer a small number of accurate examples over dense posters. Mark existing facts, proposed designs and unresolved questions.
- Generate different **layouts/compositions** when comparing alternatives, not merely recolored copies.
- Discuss and select the composition with the user before treating it as documentation.
- A generated image is a rendered illustration, **not editable source**. Keep it as reference/evidence, not a replacement for a technical specification.
- This stage is optional when the source and structure are already agreed or the user specifically requests an editable document directly.

### 2. Documentation: faithful SVG reconstruction

When the user wants a chosen static explanation in the repository, redraw the approved image as **real editable SVG**. Preserve the selected content, layout, relative grouping and main visual style as closely as practical.

- Use actual SVG text, shapes, icon paths and connectors. Verify arrow direction and explicit relationships.
- Avoid text-heavy boxes and ornamental complexity; preserve readability at documentation and mobile widths.
- Record deviations from the image prototype. Manual vector reconstruction is **not** guaranteed to be pixel-perfect.
- **Never** substitute a PNG/JPEG embedded into an SVG and call the file editable.
- Store the SVG with the Markdown document and embed it using a relative link. Keep meaning and current decisions in nearby Markdown rather than hiding requirements only inside an image.
- SVG can reference external images, but external images are often blocked when an SVG is embedded as an image (e.g. in GitHub). Prefer image-free SVG for dependable documentation; avoid remote assets for required meaning.
- Simple already-specified diagrams may be drawn directly as SVG without a preceding generated image.

### 3. Interaction: standalone HTML/CSS/JavaScript

For zoom, gestures, state switching, responsiveness, custom images and clickable diagrams, use **one directly executable HTML file**.

- Build regular UI layout from native HTML and CSS (cards, headings, grids, flexbox and forms).
- Use only the JavaScript needed for real interaction. Do not wrap giant repeated SVG posters in an HTML shell.
- Inline all CSS/JS; no build process or local server. External image URLs are permitted for optional visual examples, with a fallback. Local user images stay browser-local.
- Preserve the target device aspect ratio, show the relevant state and make comparisons reproducible.
- Clearly distinguish a browser simulation from verified Flutter or Android behavior.
- When a static screenshot or diagram from the HTML becomes an accepted documentation asset, recreate/export a standalone editable SVG if useful. The interactive HTML remains the source for its behavior.

**Default decision:** exploratory explanatory visual → image; selected static repo reference → SVG; working behavior study → HTML. Do not create all three formats by default.

## Visual style: information structure before colors

Our preferred visual palette is **Soft Pastel**: off-white canvas, restrained blue/lavender/green/amber areas, dark high-contrast typography, rounded cards and a few well-drawn icons. The palette is a starting point, not the main criterion.

1. Begin with a one-sentence takeaway, then organize 4–8 core concepts into obvious sections.
2. Use solid connectors for real containment/data flow, dashed connectors for conceptual or optional relationships. Never draw misleading inheritance.
3. Keep text brief within nodes; put nuanced explanations in the adjacent Markdown.
4. Include grounded concrete examples (e.g. Pixiv Work 120 / Page 2).
5. Keep domain values, access context, viewer occurrence and local bookmark membership distinct. Remote Groups are not local Bookmark Groups.
6. UI images should explain what is visible in **Image View** versus **Overview**, how page paging differs from Work switching, and which controls are optional or temporary.
7. Preserve exact device ratios when given; test narrow screens and text scaling.
8. Label fictional UI/media and experimental settings. Do not imply proposed controls or external API capabilities are implemented.

Older comparison palettes, Editorial Neutral and Night Blueprint, remain archived as alternatives; future variants should change **structure** when structural comparison is the question, not merely the palette. Historical draw.io/Mermaid reproductions remain for reference but were not satisfactory for these polished concept posters.

## Asset provenance and media

- Images produced by an image-generation tool are synthetic output and do not have original public image URLs.
- Do not claim a hand-redrawn SVG is a one-to-one automatic conversion of such an image.
- Use optional HTTPS image URLs in **HTML** when the image is legitimately available at a stable address. Reuse the same images across comparison variants, supply a missing-image fallback, and disclose that remote hosts receive image requests.
- Do not commit user-supplied images, private content, credentials, or third-party fonts.

## Verification and publication

For **images**: inspect the rendering and compare factual labels to inspected source or the accepted design. For **SVG**: parse XML, inspect a rendered preview, verify text, connectors and lack of flattened raster payloads. For **HTML**: open it in a real browser, test meaningful controls and screen sizes, inspect JavaScript errors and network behavior. Do not claim tests that were not run.

Use isolated task branches, make incremental English commits for significant changes, and document remaining uncertainties. Documentation-only work needs direct artifact checks, not full Flutter regression. Do not merge without authorization.

## Existing examples

- [Editable architecture poster, derived manually from selected image](diagram-examples/architecture-poster-faithful.svg)
- [Previous four-format experiment](diagram-examples/README.md) (historical, not the required workflow)
- [Interactive Image View / Overview lab](mockups/2026-11-04-viewer-interaction-lab.html)
- [Native HTML structure experiment](diagram-examples/content-native-html.html)
