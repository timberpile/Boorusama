# Visual Explainer Style Guide (Candidate)

Status: **style comparison**, not a globally approved Boorusama runtime design rule.
This is for diagrams, architecture explanations and UX studies; actual UI follows `docs/ui_style_guide.md`.

## Current design preference (2026-11-05)

**Structure before palette.** The preferred visual tone is **Soft Pastel**, but the critical design work is information grouping, hierarchy, clear arrows, concise examples, comparison of interaction states, and readable mobile UI regions. Do not treat three color schemes of the same layout as three useful design alternatives. When offering alternatives, vary the **composition and information flow**, and explain their tradeoffs.

**Prefer semantic native HTML/CSS for interactive concept sheets**: one self-contained file, ordinary headings, cards, CSS Grid/Flexbox, minimal JavaScript for actual interactions. Do not create an HTML shell that merely embeds three giant copies of the same SVG. Keep SVG for static diagrams directly displayed in GitHub Markdown, or for genuinely complex vector connections. Mermaid and draw.io were visually unsatisfactory for these specific polished architecture/UI sheets and are not required default deliverables.

Illustrative media can be linked with remote HTTPS `<img>` URLs, reused across all relevant views without downloading assets into the repository. Use a graceful placeholder when images cannot load (offline, hotlink restriction, deleted URL). Stable public URLs must be verified where practical. The earlier generated example illustrations have no public source URLs, so replacements must be described honestly rather than claimed to be identical. Remote image requests expose the viewer's IP address to the host.

Current [HTML-native structure comparison](diagram-examples/content-native-html.html) is a prototype for evaluating maintainability and content hierarchy, not a new runtime UI contract.

## Goals
- Prefer a concrete, accurate explanation over decorative complexity.
- Show existing, proposed, approved and unverified concepts distinctly.
- Use readable text, short labels, labeled arrows, and clear sections.
- Keep domain identity, access context, local membership and viewer occurrence separate.
- Reuse the same information for comparison variants. Do not silently choose the visual style.

## Candidate styles
| Style | Visual language | Best use |
| --- | --- | --- |
| **Soft Pastel** | Off-white background, muted blue/lavender/green/amber zones, rounded cards | Friendly architecture and UX explainers |
| **Editorial Neutral** | White, blue-gray and charcoal, restrained borders, substantial whitespace | Dense technical documentation |
| **Night Blueprint** | Dark navy background, bright but controlled accents | Dark-themed presentation and screen comparisons |

All three styles are illustrative choices, not application theme definitions. Preserve sufficient text contrast in every variant.

## Diagram grammar
1. Lead with one sentence stating the point of the diagram.
2. Distinguish real inheritance from conceptual grouping: solid edges for real data flow or membership; dashed edges for conceptual or optional relationships.
3. Use a single box per concept. Do not confuse remote Content Groups with local Bookmark Groups.
4. Include an example for every unfamiliar abstraction, e.g. Pixiv Work 120 / Page 2.
5. Keep source/API data, temporary state and UI composition separate.
6. Put exceptions in small callouts and detailed explanations in accompanying Markdown.
7. Mark illustrative UI and fictional data explicitly, including interaction choices not yet approved.
8. Respect target device ratios and narrow screen / enlarged text when depicting UI.

## Preferred outputs
| Format | Strength | Weakness |
| --- | --- | --- |
| **SVG** | Lightweight, crisp, GitHub renders, editable real vector objects | Complex spatial editing may need an editor |
| **draw.io** | Convenient GUI editing of individual shapes and connectors | XML is bulkier; exported render needs checking |
| **Mermaid** | Excellent compact source, Git diffs, native diagram preview | Weak control of phone layouts and decorative callouts |
| **Single HTML file with inline SVG** | Accurate, theme-switching and interactive UX experiments | More code, GitHub usually shows source, not an embedded UI |

When visually rich posters are hand-redrawn as vectors, describe them as **editable approximations**, never lossless or pixel-exact conversions. No raster images embedded as fake vector sources, bundled fonts or external build/CDN dependencies.

## Checks
- Parse SVG/draw.io as XML and ensure editable text/shapes.
- Render screenshots of the variants and inspect layout and readability.
- Test responsive standalone HTML without network and check interaction/console failures.
- Validate Mermaid with a renderer when available; report if not validated.
- Test with real image dimensions where relevant; keep local user images browser-only.
- Publish explanatory Markdown with direct links to the source, examples and any known verification limits.

## Example
Compare [architecture and Pixiv Work concepts in four formats](diagram-examples/README.md). The sample set is not the final architecture decision.
