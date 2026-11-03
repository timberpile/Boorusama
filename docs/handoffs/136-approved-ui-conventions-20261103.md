# Issue #136: Approved UI convention clarification

Branch: `feature/136-kurumi-ui-design-system`.
Guide/agent-rule commit: `ca129d6750fd3ad5ebf4e9bbf98c62544ea3cf4f`.
The subsequent handoff commit changes documentation only.

The existing guide now distinguishes the **opaque semantic parent** from the
**distinct rounded Kurumi search input**, matching Browse. Other individual
toolbar controls stay transparent. Header, Search Bar and Timeline Toolbar
terminology remains unchanged. Adjacent surfaces use consistent semantic colors;
comparable navigation/back controls use Kurumi, and context action icons normally
lead while counts, state and submenu indicators may trail. #105 still owns radii.

AGENTS.md retains this branch's guide pointer and now includes #145's stricter
binding Kurumi rule, including `showDialog` routing and justified exceptions.
It was reconciled with the current rule, not replaced by older menu guidance.
No runtime app-wide navigation, menu or radius migration was performed.

Existing source audits, original 30-image/Penpot evidence and the ten-image
timeline supplement are preserved. The guide labels the earlier transparent
Bookmark field captures as historical; they do not supersede the user's later
#139 correction. No Penpot board or screenshot was overwritten.

Checks: four audit-tool unit tests passed; guide local links resolve;
`git diff --check` and scoped diff review passed. No Flutter tests/build for this
documentation-only update. The broader baseline still requires owner acceptance.
Local delivery only; no push, PR, merge or issue closure.

For the requested Bookmark toolbar assessment, `TimelineToolbar` can host the
existing sort/shuffle/source/count children and fixed grid action. Its inline
count placement differs from Bookmark's current far-edge distribution. This
small layout decision is recorded in #148; no new #114/#115 issue or unrelated
toolbar refactor was introduced in the implementation branches.
