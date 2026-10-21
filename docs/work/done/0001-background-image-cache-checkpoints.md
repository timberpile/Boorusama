# Move image-cache checkpoint preparation off the UI isolate

> **Archive disposition (2026-10-20): Completed on `develop`.** The implementation is integrated. Earlier claims, status text, outstanding manual checks and verification notes below are historical, not an active local task.

- **Priority:** High
- **Feature:** Native image cache; performance diagnostics
- **Branch:** `fix/cache-performance-diagnostics`
- **Agent/session:** ChatGPT, 2026-10-11; user-approved checkpoint follow-up
- **Worktree:** Isolated GitHub Actions task worktree under `$RUNNER_TEMP/checkpoint-task`; no changes to the user's primary checkout
- **Dependencies:** Incremental occupied-byte accounting and LRU eviction from `develop` at `a46521eced78ae2f31a5c2517a43fc2e4e4a6072`; existing diagnostics on this task branch

## Problem

Even after the quadratic eviction regression and repeated sorting were fixed,
checkpoint preparation still constructs every entry map and serializes the full
cache index on the UI isolate. UTF-8 conversion adds another synchronous pass.
Checkpoints occur after 128 successful journal appends, during initialization,
on disposal, and during metadata recovery. The user supplied a report of roughly
58 ms average encoding time; that measurement has not been independently
reproduced in this task. At 90 Hz the frame budget is about 11.1 ms.

## Intended change

Capture only immutable scalar entry records (key, filename, bytes and use order),
revision and staging path. Use a short-lived `Isolate.run` worker to build the
JSON maps, encode directly with `JsonUtf8Encoder`, and write/flush/close the
partial file. Do not send the cache manager, live mutable entries, recorder or
Flutter providers to the worker.

The current serialized cache operation awaits that worker, then directly renames
the partial to the checkpoint and truncates the journal. Keep its queue slot
until all steps complete. Never enqueue the finalization behind that same slot,
and never allow journal appends to overtake the snapshot before truncation.

Preserve version-1 JSON, filenames, revision replay, the 128-record threshold,
per-record flush policy, LRU ordering, capacity accounting and file leases.
Do not change GIF playback, image quality, cache limits or user data.

## Acceptance criteria

- [ ] JSON-map construction, UTF-8 encoding and staged-file writing run in a
      background isolate; only a compact snapshot and dispatch remain on caller.
- [ ] Queue ordering survives a delayed worker with later touch/clear operations.
- [ ] Old checkpoint plus journal remain authoritative on preparation/rename
      failure; new checkpoint plus old journal recover after publication.
- [ ] File and worker-infrastructure failures preserve readable cached images
      and retry via metadata-dirty recovery; programming errors propagate.
- [ ] Checkpoint schema/revisions, cadence and recency remain compatible.
- [ ] Snapshot/dispatch sync spans are distinguished from worker/publish wall
      spans; worker elapsed time is never labelled UI CPU work.
- [ ] Targeted tests, formatting, analysis and the complete required repository
      suite pass on the pinned FVM SDK after the final edits.
- [ ] A release-device comparison with the same populated cache records frame
      delays, snapshot/dispatch cost, checkpoint wall time and cache queue wait.

## Verification and integration

Keep a reconciled diagnostics-only commit before this change for a controlled
comparison. Preserve current develop behavior while porting the older diagnostic
wrappers. No push to develop/master or PR is authorized by this task.

Tests exercise the real isolate/file boundary, UTF-8 compatibility, the 128-entry
threshold, scalar snapshot isolation, preparation/rename/truncation failures,
crash-window recovery without a dispose-induced checkpoint, queue ordering and
optional-metadata recovery. Infrastructure exceptions are distinct from normal
programming errors; there is no synchronous encoding fallback.

Pending verification must be reported as pending. Remote runner checks are not
local-device measurements or a claim that every reported stutter is fixed. Run
the complete local suite described in `docs/engineering_guidelines.md` before
integration, and retain the current populated device cache for acceptance.

## Out of scope

A persistent worker, nonblocking metadata queue/journal rotation, changing
checkpoint frequency, startup index decoding, and the remaining bookmark/feed/
media audit findings are separate follow-ups requiring measurements.

## Progress

Implementation and regression tests are being prepared on the existing task
branch. This item stays open until the required verification is complete.

## Runner verification and remaining blockers

Implementation is applied. The source-only diagnostic comparison commit is `145206e02a36a141e66010cef95c3f30484e1f0d`. It is not a verified device baseline.

- Whitespace: **passed**.
- Performance report analyzer: **passed**.
- Repository tooling: **passed**.
- test-pull-request-policy.sh: **passed**.
- test-android-release-scripts.sh: **passed**.
- Pinned FVM SDK: **passed**.
- Dart format: **passed**.
- Dependency resolution: **passed**.
- CLI dependency resolution: **passed**.
- Required generation: **passed**.
- Cache analysis: **passed**.
- Cache complete suite: **passed**.
- Foundation complete suite: **passed**.
- Application complete suite: **passed**.
- booru_clients complete suite: **passed**.
- boorusama_cli complete suite: **passed**.
- coreutils complete suite: **passed**.
- dtext complete suite: **passed**.
- extended_image complete suite: **passed**.
- filename_generator complete suite: **passed**.
- flutter_sqlite3_migration complete suite: **passed**.
- i18n_cli complete suite: **passed**.
- kurumi complete suite: **passed**.
- retriable complete suite: **passed**.

SDK setup: **success**. Verification step: **success** means the runner finished collecting outcomes, not that every check passed. See `docs/checkpoint_verification.json` for exact commands.

Required local FVM verification, any failed/unrun runner checks, and the same-cache release-device comparison remain outstanding. This item is blocked on that verification; it is not ready for integration. Do not infer improved device frame times from source changes.
