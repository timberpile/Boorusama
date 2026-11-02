# Penpot design-system strategy for Boorusama

Date: 2026-11-02
Tracking: [#136](https://github.com/timberpile/Boorusama/issues/136)
Status: design proposal; **no Penpot file has been created or connected**.

## Decision

Use Penpot as a **curated visual contract**, not a full duplicate of the Flutter application. Build a reusable Kurumi-oriented component library and around 10 canonical screens with representative states. Code remains authoritative for existing runtime behavior until a new design is approved. Approved designs are the target for visual changes; tests and code define actual behavior and capability constraints.

Penpot supports shared component libraries, variants, design tokens, token themes, and DTCG-style JSON import/export. Its official MCP workflow is available for separately connected compatible clients. This does not imply this chat currently has access to a Penpot workspace. References: [Penpot design tokens](https://help.penpot.app/user-guide/design-systems/design-tokens/), [Penpot MCP](https://help.penpot.app/mcp/).

## Proposed file organization

| Penpot page | Content |
| --- | --- |
| `00 / Foundations` | Semantic color roles, typography, spacing and radius **after approval**, elevation, icon usage, interaction states |
| `01 / Components` | Kurumi menu family, buttons, chips, fields, settings cards/tiles, sheets/dialogs, app bars, focus and feedback |
| `02 / Patterns` | Search/editor toolbar, tag chips, post grid controls, selection actions, bookmark groups, empty/error states |
| `03 / Mobile` | Canonical narrow-screen reference frames, key overlays, screenshots linked to code and source commits |
| `04 / Wide & Desktop` | Navigation, split panes, menu anchor placement and large-screen variants |
| `05 / Flows` | Critical interaction sequences and annotation (search, bookmark groups, following, viewer) |
| `99 / Archive` | Replaced proposals; not authoritative |

**Component naming:** use names mirroring the public Dart component when practical (e.g., `Kurumi/SettingsCard`, `Kurumi/PopupMenu/Item`). For patterns that are app-specific, use `App/Search/SelectedTagChip` or `App/Viewer/Toolbar`. Associate the Penpot component with its Dart definition and a runtime screenshot.

**Minimum state variants:** default, pressed/hovered/focused where applicable, disabled, selected, loading, error; density/compactness where it changes real design. Do not generate all possible state combinations; document which ones are functionally relevant.

## Token strategy

- Build **semantic** token groups that map to `KurumiSemanticColors` and active Material `ColorScheme` (accent, surfaces, content, secondary, muted, outline, danger and overlays) rather than copying a single preset palette as the only contract.
- Include reference light and dark modes, plus AMOLED where visual hierarchy differs. Dynamic/premium/profile colors must still be resolved at runtime; Penpot can express *roles* and sample palettes, not every generated color.
- Introduce spacing, shape, and typography tokens only for reviewed, shared decisions. Do not export new radii into the application until [#105](https://github.com/timberpile/Boorusama/issues/105) is resolved.
- Prefer an explicit, versioned one-way token mapping. Initial authority is the **approved code/theme contract**; update Penpot from that contract. After future design decisions, intentionally update both. Do not turn on uncontrolled bidirectional synchronization or code generation in the first iteration.
- Keep an export artifact (Penpot DTCG JSON) in version control **only if** token synchronization becomes useful and verifiable. No export was produced in this investigation.

## Canonical screens (roughly 10)

1. Mobile home/navigation.
2. Search landing and edit with keyboard/suggestions.
3. Search result grid and selected-items toolbar.
4. Full-screen post viewer with details/actions.
5. Bookmark overview and nested groups.
6. Following Topics/folder/feed overview and edit.
7. Settings root, Appearance, and Data and Storage sections (grouped pattern family).
8. Profile chooser/configuration form.
9. Download Manager and action popup.
10. Danbooru artist/details screen (demonstrates engine-specific extension).

Each page should have a stable purpose, code entry-point, screenshot, source commit, supported platform/theme, and a limited set of overlays and error/loading states. Expand coverage only when a proposed redesign or recurring inconsistency justifies it. A complete 1:1 recreation of every feature, theme, site, locale, and state is neither practical nor a reliable validation system.

## Agent workflow

1. Read `AGENTS.md` and `docs/ui_style_guide.md`; inspect an existing analogous screen in code.
2. Read the approved Penpot component/screen if one exists; otherwise follow existing Kurumi patterns. An inaccessible Penpot file is not permission to invent a layout.
3. Make a **specific** proposed change, describe intentional deviations, and obtain approval for major UX changes before implementation.
4. Apply Flutter UI patterns with accessibility, responsive behavior, and engine/profile capabilities preserved.
5. Compare a real app screenshot with the accepted reference and run scope-appropriate tests, including keyboard/narrow/text-scale checks where relevant.
6. Update the corresponding Penpot reference **only after** the design change is accepted; do not create silent design drift.

Do not enforce pixel-perfect CI against Penpot exports in the first iteration: font rasterization, device insets, localization, dynamic colors, content, and image loading can differ legitimately. Use deterministic widget/golden tests only for intentionally stable, controlled components; preserve semantic assertions and manual screenshot review for larger flows.

## Integration requirements and limitations

The official Penpot MCP server can be run locally through `npx @penpot/mcp@stable`, with its browser plugin connected to a design file. A compatible client with that local MCP endpoint is needed to read/write designs. The MCP installation should be treated as a separate environment setup and access action; it was **not performed** here. See https://help.penpot.app/mcp/.

Do not expose credentials, private user content, or test account data in Penpot. The library may be maintained by a human designer and local agents; current chat tools do not provide a connected Penpot editor.

## Initial acceptance gate

A Penpot library can become an approved reference when it accurately contains a small sample of current Kurumi components (button, menu, settings card/tile, text field and chips), states, semantic color modes, and at least two canonical screens with screenshots checked against the current fork. The rest can be grown iteratively.
