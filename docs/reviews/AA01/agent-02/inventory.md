# Scope inventory

Explicit frozen list, observed 2026-10-29T17:25:37.350Z; each target's merge base is `422aeae087c1108e655d85d1a3dac25120456cd6` against `develop` at `422aeae087c1108e655d85d1a3dac25120456cd6` (all five are one commit ahead and zero behind in the observed compare). No targets outside this exact list may be added. No issue-free targets in scope. No in-scope PR found by issue-number search.

| ID | Branch | Issue | Head SHA | Merge-base SHA | Status |
|---|---|---|---|---|---|
| T001 | `bug/113-collection-pagination` | [#113](https://github.com/timberpile/Boorusama/issues/113) | `a1bc1d42903861a46e7230349515946bae678357` | `422aeae087c1108e655d85d1a3dac25120456cd6` | Complete static passes 1 + 2 + 3 + 4; F0008 inherited, F0011 #113 acceptance defect |
| T002 | `feature/114-timeline-toolbar` | [#114](https://github.com/timberpile/Boorusama/issues/114) | `5bb52794468b172b7d6878fb825b42b00d654675` | `422aeae087c1108e655d85d1a3dac25120456cd6` | Complete static passes 1 + 2 + 3; F0001 gap, F0009 and F0010 inherited defects |
| T003 | `feature/116-compact-follow-button` | [#116](https://github.com/timberpile/Boorusama/issues/116) | `5ac3ad9bc5f852f000012499c19468151c73734b` | `422aeae087c1108e655d85d1a3dac25120456cd6` | Complete static passes 1 + 2 + 3; no finding |
| T004 | `feature/117-pixiv-favorites` | [#117](https://github.com/timberpile/Boorusama/issues/117) | `e2929259b7725c484d11483d6ea48270079eb2f4` | `422aeae087c1108e655d85d1a3dac25120456cd6` | Complete static passes 1 + 2 + 3; F0002 cross defect, F0003 gap; cross F0005/F0007; linked F0008 |
| T005 | `feature/118-pixiv-following-artists` | [#118](https://github.com/timberpile/Boorusama/issues/118) | `1d02bef637966999fbd0b72ecb9c6f0e1eedce8a` | `422aeae087c1108e655d85d1a3dac25120456cd6` | Complete static passes 1 + 2 + 3; F0004/F0006 plus cross F0005/F0007 |

No exclusions in this explicitly assigned list. All targets have two completed static passes at these pinned heads. Remote branch heads and develop were rechecked after cycle 2 on 2026-10-29; all six source SHAs remained unchanged, so no source drift/delta review was needed. Merge-base remains develop at the recorded SHA. Runtime tests and final merged-source review were not executed. Duration is tracked separately.
