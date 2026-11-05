# Content Architecture Discussion — Start Here

Date: 2026-11-04. Branch: `maintenance/content-architecture-design`.
Application baseline: `e306ff5338a2255a89731c61bd0672336a933344`.

**Design/research only.** No runtime implementation, new issue, PR or develop merge. Proposed types, Work layouts, zoom constants and filter placement still need user decisions. GitHub Issues remain the task tracker.

## Structure-first HTML experiment (2026-11-05)

[Try the native HTML/CSS architecture and Pixiv Work comparison](diagram-examples/content-native-html.html). Soft Pastel is preferred visually, while layout and clarity matter more than palette. This newer comparison uses real HTML/CSS components, remote photo URLs (not stored media), and a direct HTTPS image URL field. The older SVG/draw.io/Mermaid/inline-SVG experiments are retained as references, not required output formats.

## Latest review: start here

[Open the Image View / Overview Lab with local images](mockups/2026-11-04-viewer-interaction-lab.html).
Select several files to make one temporary Work; select again to make another. Test square, tall and wide images, view-mode transitions, Work skipping and Classic versus aspect-aware zoom. Files stay in your browser. Navigation test buttons are outside the simulated phone, not proposed application controls.

Read [Model and Viewer Clarifications](2026-11-04-content-model-and-viewer-clarifications.md) before the detailed type diagram. It explains Pool/Series/Collection/Gallery and each proposed responsibility with an example. The diagram does not require eleven new public classes.

[Local-Image Experiment and Verification](2026-11-04-viewer-interaction-review.md) records behavior, privacy, limits and 35 passing browser assertions. Work-skipping gestures, exact zoom constants and Favorites scope placement remain proposals. The newer lab corrects the earlier lab's non-equivalent Comic/Classic comparison.

GitHub displays HTML source: download the raw file and open it locally. Each HTML file is standalone and needs no build, server or external assets.

## Earlier alternatives and architecture diagrams

[Open the original Content Design Lab](mockups/2026-11-04-content-design-lab.html). Keep it for the A/B/C and Favorites placement comparisons; it has not been silently replaced by an approved final design.

| Tab | Contents |
| --- | --- |
| Architecture | Clickable data/state/UI responsibilities and nested Series -> Work -> Page relationships. |
| Work & Group Screens | Cover-first, inline gallery and viewer/details variants; nested Manga Series, Pool and nhentai Gallery. |
| Double-Tap Zoom | Earlier geometry candidates. Use the newer lab for the corrected current-Classic reference. |
| Favorites Scope | Public/Private row, Header menu and Timeline Toolbar selector. |

## Supporting documents

- [Visual Architecture Guide](2026-11-04-content-architecture-visual-guide.md): seven Mermaid diagrams, proposed properties, composition, ownership and action targets. Content is a conceptual umbrella, not mandatory Post inheritance.
- [Model and Viewer Clarifications](2026-11-04-content-model-and-viewer-clarifications.md): plain-language examples and the separate page/Work navigation problem.
- [Feedback and Research Supplement](2026-11-04-content-architecture-feedback.md): accepted constraints and unresolved choices, including Related Works API evidence.
- [Preserved Rereview](2026-11-03-content-architecture-rereview.md): detailed prior findings and limits; structured preservation, not a byte-identical original attachment.
- [Original Lab Verification](2026-11-04-content-design-lab-verification.md): original checks and limits.
- [Local-Image Lab Verification](2026-11-04-viewer-interaction-review.md#verification): current checks and reproduction instructions.

Later explicit user feedback takes precedence over earlier recommendations.

## Accepted direction

Android first; desktop optional; Web is not a current prerequisite. Finish current work/bugs and establish a clean baseline before architecture implementation; remaining Pixiv/nhentai features follow it. Architecture-dependent Work features cannot simultaneously be prerequisites for that architecture: agree the stabilization cohort rather than silently creating a circular dependency.

Keep existing Post/snapshot/media foundations. Separate resource identity, source access, viewer occurrence and local membership. Reuse Danbooru/Kurumi sections while allowing media-first Works and description-first Pools. Work/Page bookmarks remain independent; remote favorites target the Work and account.

Viewer Controls on Open initializes only a new session. Paging preserves the user's visibility choice. Double-tap uses one-in/next-out; aspect-aware target constants remain experimental. Horizontal member browsing is preferred over vertically stacked pages. Persistent previous/next application buttons are not wanted; desktop mockup helpers must remain separate.

For nhentai, five popular general-tag pages are a warmup candidate based on the user's observation, not proof of complete taxonomy or Work coverage. Resolve visible unknown IDs in batches and build complete coverage over time. A bundled seed remains an option to evaluate, not an approved dependency.

Public/Private placement remains open; no unverified All scope is introduced. The current recommendation is the compact Timeline Toolbar selector because this is a list filter. Related Works are optional recommendations, not canonical group members. Refer to issues using descriptive titles plus numbers.

## Compare the Work experiences

**A — Cover First:** media then artist/actions/details; tap into the existing viewer for all pages. Simple gesture ownership, one extra tap.

**B — Inline Gallery:** swipe preview pages above details, expand for the viewer. Fast sampling, requires clear inner/outer gesture ownership. The user prefers this over A; final navigation remains unresolved.

**C — Viewer + Details:** open the image viewer directly; reveal the familiar details sheet. Close to the current visual approach, not proof that Work grouping and Work actions are already implemented.

**New experiment — Image View / Overview:** one selected image switches smoothly between a centered media view and an image-first details page. Separate image swipes from deliberate Work changes. Preserve comic reading position when returning from Overview. This experiment explores the user's suggested interaction; it is not a new approved default.

The original prototype includes nested Back restoration, unavailable page positions and separate Work/Page save simulations. Built-in media, names, dates and counts are fictional fixtures; actions do not call source APIs. Ugoira is one animation placeholder, not frame pages.

## Published increments

`97bf745` preserves findings; `b4ea23c` records feedback; `26e78bf` adds diagrams; `f015630` publishes the original prototype; `c5ecb2a` adds browser checks; `687f920` publishes the original index/verification; `fdd599f` clarifies model and navigation.

`b06ef6c` adds the local-image lab; `185693b` corrects native image-drag cancellation; `b9613cc` publishes repeatable checks; `488e402` records privacy, behavior and verification. This index update connects those increments.

Final type names, layout choice, zoom thresholds, skip gestures and Favorites placement remain jointly decidable rather than silently approved by a prototype.
