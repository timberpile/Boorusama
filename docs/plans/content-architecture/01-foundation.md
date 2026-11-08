# Stage 01: shared references, Group contracts and loading

**Issue:** #154. **Branch:** `maintenance/154-content-group-contracts`.
**Base:** verified stage 00 candidate, or latest develop already containing it.
**Goal:** add the approved typed boundaries without changing the established Post/Pool/Related UI or persistence.
**Specification:** [approved contract](approved-contract.md), sections 1-6. **Final reviewer:** independent Astra High.

Follow the test/commit/review loop in [README](README.md). New paths below are proposed destinations; existing equivalent files should be extended, not duplicated. Any path substitution must be documented in the issue handoff.

## Existing code to inspect

- `lib/core/posts/post/src/types/post.dart`, `post_core_data.dart`, `post_origin.dart`, `post_repository.dart`, `booru_post_data.dart`, `booru_post_capability.dart`.
- `lib/core/posts/links/boorusama_post_link.dart` and its existing tests.
- `lib/core/bookmarks/src/types/bookmark_identity.dart`.
- `lib/core/posts/details/src/types/viewer_entry.dart` and neighboring source-binding/sequence/capability files.
- `lib/core/boorus/engine/` registration, `lib/core/http/client/coordination.dart`.
- `lib/boorus/pixiv/posts/post_data.dart`, `lib/core/posts/related/related_family.dart`.
- `docs/post_architecture.md`, `docs/bookmark_groups.md`, current `pubspec.yaml` and AGENTS.md.

## File and responsibility map

Create focused files under `lib/core/content/`: `types.dart` (exports), `content_reference.dart`, `content_reference_codec.dart`, `content_entry.dart`, `content_page.dart`, `content_access.dart`, `groups/group_summary.dart`, `groups/group_details.dart`, `groups/group_metadata.dart`, `groups/group_member.dart`, `groups/group_source.dart`, `groups/group_capability.dart`, and `groups/group_members_provider.dart`. A combined reference/codec library or validated factory is allowed to preserve private construction. Keep Flutter presentation imports outside pure identity/persistence code.

Create tests in `test/core/content/`: `content_reference_test.dart`, `group_metadata_test.dart`, `group_member_batch_test.dart`, `group_members_provider_test.dart`, `group_access_isolation_test.dart`. Add safe fixtures under `test/core/content/fixtures/`. Do not copy private service payloads.

## Task 1: canonical addresses without an identity migration

**Consumes:** PostOrigin, stable Post keys and current normalizers. **Produces:** ContentKind, ContentIdentity, ContentReference, ContentKeyCodec and ContentReferenceCodec with the exact fields/methods in the contract.

1. Add failing cases preserving `id:123`, string source IDs and `work-page:120:2`, including `tryFromPost` returning null for unprovable legacy identity.
2. Test full address equality separately from semantic identity: HTTP/HTTPS canonical namespace handling matches the deployed normalizer; ports and installation paths remain distinct; profile changes do not change semantic identity. Equal identity with incompatible engine/payload is rejected at the consumer validation seam, not silently merged.
3. Test `post/id:42`, `group/pool:42` and `group/related:42` all differ; Pool Series-to-Collection metadata change preserves identity. Unverified aliases remain different.
4. Implement codec-owned grammar, canonicalization and version-safe JSON. Reuse actual portable-link URI validation; reject user-info, bad escaping, unsupported kind, invalid numeric ranges and hostile path/query/fragment inputs. Test string-keyed dynamic Hive maps as well as decoded JSON.
5. Retain all old Post link/parser tests. No widespread Post field replacement or key rewrite is needed. Commit this boundary with `Refs #154`.

Example assertions to realize using the actual codec factories:

```dart
expect(pool.reference.identity, isNot(related.reference.identity));
expect(work.reference.identity, isNot(page.reference.identity));
expect(page.reference.sourceKey, 'work-page:120:2');
expect(seriesSummary.reference.identity, collectionSummary.reference.identity);
```

## Task 2: immutable metadata and source extensions

**Produces:** Summary, Details, cover/description/tag/creator/date values and separate typed Summary/Details payload interfaces.

1. Tests distinguish unknown versus known-empty tags/creators/counts; reject invalid dimensions/negative count and non-group Summary references. Test immutable input collections.
2. Implement the contract fields, using existing rating/media/markup helpers where applicable. No members, account flags, local membership or source access goes into metadata.
3. Implement one engine codec registration accepting the two payload families. Validate typeKey/schemaVersion and cross-engine compatibility. Do not add empty payload classes to engines without extra data.
4. Test that Summary refresh cannot destroy cached Details and that native group tags are never replaced by a sampled member union. Keep authoritative removal handling adapter-owned rather than generic null-coalescing.
5. Add Pixiv Work and nhentai-shaped synthetic fixture values to prove the contracts are sufficient, but do not ship those adapters in this stage. Preserve explicit unknown metrics instead of zero defaults. Commit.

## Task 3: memberships and hydrated batches

**Consumes:** ContentReference and existing Post. **Produces:** GroupMember, ContentEntry union, ContentPage/ContentCursor, GroupMemberBatch and GroupMemberQuery.

1. Test duplicate references in two member occurrences survive; one Post can be supplied once in resolved data while both membership slots remain.
2. Test source positions 0 and 2 remain 0 and 2 if the middle slot is unavailable. A filtered result array must not become the source position array.
3. Test a group containing Group references without loading descendants; test a cycle fixture remains inert data, not recursive fetching.
4. Implement members/resolved separation. PostContentEntry carries the actual existing Post; no new snapshot or DTO reaches media widgets. Validate resolved objects match their references and batch source scope.
5. Test a response that already contains ten Posts makes zero extra Post-detail calls while building member entries. Out-of-order batch responses must map by identity and retain source sequence.
6. Do not change `PostResult<T extends Post>` or every PostRepository. The new page boundary is a sibling only for native Group/mixed lists. Commit.

## Task 4: scoped loader/controller behavior

**Produces:** ContentGroupSource with TaskEither methods, access/load keys and manual Riverpod controller. Consumes existing BooruError, HTTP cancellation/pacing and profile source bindings.

1. Implement a fake source with completer-controlled summary, detail and member requests. Test initial load, next page, retry, refresh and disposal. Initial error uses AsyncValue; next-page error preserves previous members and retry cursor.
2. Test raw page progress when all results are filtered. Never use visible length or requestedLimit to prove exhaustion. Bound auto-continuation using the existing viewer policy where reused; otherwise expose explicit continuation rather than a new unbounded loop. Reject repeated/stalled cursors.
3. Test changing order/authEpoch/policyEpoch while a request is pending, then completing the old response. It must neither append nor populate the new scope. Concurrent loadNext calls join one request.
4. Test shared metadata requests within one access scope, distinct requests across two accounts on the same host, no global profile change, and cache invalidation after account removal/replacement. Credentials must never appear in key equality, serialized data or diagnostics.
5. Share one raw detail/member envelope when the adapter already returns both. Cancelling an observer must not corrupt another legitimate observer; route disposal removes listeners and bounded state.
6. Add the capability to the existing registry through one compatible extension point. Preserve legacy ViewerEntryContentCapability as an adapter while existing callers still use it. No second global resolver/registry and no live anonymous requests until #143.
7. Compile against pinned Riverpod 2.6.1 manual family APIs; declare scoped dependencies through the entire provider chain. Commit.

## Review focus and concrete test ownership

- Source identity versus transport/access equality: Task 1 plus Task 4.
- Missing/repeated member positions and hydration without N+1 requests: Task 3.
- Unknown/partial metadata and incompatible payload envelopes: Task 2.
- Late responses after source/account/filter changes: Task 4.
- Existing media/link/bookmark behavior accidentally routed through Group types: old consumer suites plus whole-delta review.

## Verification and exit

Run the new content suite, existing Post/link/bookmark/viewer tests identified from imports, formatting and affected analysis. Because shared core boundaries are added, run `./scripts/run_regression_tests.sh` on the final candidate. No new source/UI is enabled, so a new full device campaign is unnecessary here; do not claim Android behavior from fixture tests.

Delegate mechanical fixture creation or existing-key inventory to lower-cost agents with read-only/file-limited scopes. The main high-capability implementer owns normalization, equality, cache/auth keys and registry contracts. Independent Astra High must inspect this full stage and verify it does not silently introduce a new identity/persistence policy. Resolve findings and review the revised commit before stage 02.

Deliver a per-issue handoff with exact base/head, new contract locations, passing commands, skipped/unrun checks and reviewer identity/verdict. Keep #154 open until its approved publication in origin/develop.
