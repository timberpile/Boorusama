---
name: visual-explainers
description: Create clear architecture and UI explanations with a staged image-first, editable SVG documentation, and standalone HTML interaction workflow. Use for diagrams, concept reviews, and visual comparisons.
---

# Visual Explainers

Read the current `AGENTS.md` and the [Diagram Style Guide](../../../docs/designs/diagram_style_guide.md) first. This skill covers visual communication, not runtime app implementation.

## Select one outcome

- **Discussing an unapproved visual concept:** Generate an explanatory image when a visual is useful. Optimize for readable structure, examples, informative relationships and concise labels, using the Soft Pastel style as a starting point. Compare meaningful layout alternatives rather than color variants.
- **Adding selected static content to repository documentation:** Faithfully redraw the chosen image as an editable SVG with native text, paths, shapes and arrows; include a Markdown explanation. Do not embed a flattened raster and claim it is editable. Document reconstruction differences.
- **Exploring interactive UI behavior:** Produce one self-contained browser-openable HTML file with native HTML/CSS plus minimal JavaScript. Support meaningful devices, input, state changes and optional example images. Do not merely paste full SVG posters into HTML.

Do **not** generate all three outputs automatically. An already specified simple static diagram may be authored directly as SVG. Keep source and design states distinct; a prototype is not acceptance of behavior.

## Steps

1. Identify the decision the visual should clarify and read the relevant repo sources.
2. Choose the format and diagram structure, then keep the number of concepts manageable.
3. Preserve separate identities for content, local bookmarks, access policy and viewer occurrence. Reuse Boorusama and Kurumi UI patterns.
4. Produce the selected output in English, with short captions and accurate example labels.
5. Validate image content; parse and render SVG; test HTML interactions, responsive layouts and errors in a browser. Report verification gaps.
6. Save selected documentation/assets on the designated task branch in incremental commits. Follow repo workflow and do not merge or create PRs without authorization.

## Constraints

Never invent source capabilities, identity relationships, confirmed UI behavior or completed tests. Do not commit private images or credentials. For remote HTML images, use external HTTPS references only as optional illustrations and provide fallback. Treat image-generation output as a rendered reference, not editable source.
