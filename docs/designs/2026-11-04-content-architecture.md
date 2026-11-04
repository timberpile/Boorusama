# Content Architecture Discussion — Start Here

Date: 2026-11-04. Branch: `maintenance/content-architecture-design`.
Application baseline: `e306ff5338a2255a89731c61bd0672336a933344`.

**Design/research only.** No runtime implementation, new issue, PR or develop merge. Proposed types, Work layouts, zoom constants and filter placement still need user decisions. GitHub Issues remain the task tracker.

## Start visually

[Open the standalone Content Design Lab](mockups/2026-11-04-content-design-lab.html). GitHub displays HTML source: download the raw file and open it locally. The file needs no build, server or external assets.

| Tab | Contents |
| --- | --- |
| Architecture | Clickable data/state/UI responsibilities and nested Series -> Work -> Page relationships. |
| Work & Group Screens | Cover-first, inline gallery and viewer/details variants; nested Manga Series, Pool and nhentai Gallery. |
| Double-Tap Zoom | Aspect-aware Classic interaction; square, portrait, landscape, panorama and Comic comparisons. |
| Favorites Scope | Public/Private row, Header menu and Timeline Toolbar selector. |

## Supporting documents

- [Visual Architecture Guide](2026-11-04-content-architecture-visual-guide.md): seven Mermaid diagrams, proposed properties, composition, ownership and action targets. Content is a conceptual umbrella, not mandatory Post inheritance.
- [Feedback and Research Supplement](2026-11-04-content-architecture-feedback.md): accepted constraints and unresolved choices, including Related Works API evidence.
- [Preserved Rereview](2026-11-03-content-architecture-rereview.md): detailed prior findings and limits; structured preservation, not a byte-identical original attachment.
- [Verification record](2026-11-04-content-design-lab-verification.md): checks performed and reproduction instructions.

Later explicit user feedback takes precedence over earlier recommendations.

## Accepted direction

Android first; desktop optional; Web is not a current prerequisite. Finish current work/bugs and establish a clean baseline before architecture implementation; remaining Pixiv/nhentai features follow it. Architecture-dependent Work features cannot simultaneously be prerequisites for that architecture: agree the stabilization cohort rather than silently creating a circular dependency.

Keep existing Post/snapshot/media foundations. Separate resource identity, source access, viewer occurrence and local membership. Reuse Danbooru/Kurumi sections while allowing media-first Works and description-first Pools. Work/Page bookmarks remain independent; remote favorites target the Work and account.

Viewer Controls on Open initializes only a new session. Paging preserves the user's visibility choice. Double-tap uses one-in/next-out; aspect-aware target constants remain experimental.

For nhentai, five popular general-tag pages are a warmup candidate based on the user's observation, not proof of complete taxonomy or Work coverage. Resolve visible unknown IDs in batches and build complete coverage over time. A bundled seed remains an option to evaluate, not an approved dependency.

Public/Private placement remains open; no unverified All scope is introduced. Related Works are optional recommendations, not canonical group members. Refer to issues using descriptive titles plus numbers.

## Compare the Work experiences

**A — Cover First:** media then artist/actions/details; tap into the existing viewer for all pages. Simple gesture ownership, one extra tap.

**B — Inline Gallery:** swipe preview pages above details, expand for the viewer. Fast sampling, requires clear inner/outer gesture ownership.

**C — Viewer + Details:** open the image viewer directly; reveal the familiar details sheet. Strongest image focus, requires clear Work/Page actions.

The prototype includes nested Back restoration, unavailable page positions and separate Work/Page save simulations. All media, names, dates and counts are fictitious fixtures; actions do not call source APIs. Ugoira is one animation placeholder, not frame pages.

## Published increments

`97bf745` preserves findings; `b4ea23c` records feedback; `26e78bf` adds diagrams; `f015630` publishes the prototype; `c5ecb2a` adds browser checks. This index and verification are another documentation increment.

Start discussion with the three Work compositions and the data/state/UI diagram. Final type names, layout choice, zoom thresholds and Favorites placement remain jointly decidable rather than silently approved by the prototype.
