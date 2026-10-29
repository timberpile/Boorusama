# Cross-branch evidence

Canonical findings and interactions will be documented here after source verification. Do not treat overlapping paths as proof of an integration defect.

## Planned integration comparisons

- #113 shared pagination semantics consumed by #117 Favorites.
- #117 and #118 both touch Pixiv client part declarations and authenticated request options; integration must preserve both, without duplicating shared methods.
- #114 and #116 both affect toolbar/follow UX but have independent branches and later integration dependencies.
