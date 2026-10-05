# Stable Bookmark Post Identity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Identify bookmarks by installation and stable upstream post key across profiles and engine metadata changes.

**Architecture:** Keep canonical installation normalization in `PostOrigin`, so stored posts and profile resolution agree. Derive bookmark keys from engine post data only when the shared numeric `Post.id` is not an upstream ID. Use the same identity in live membership, group membership, and package preflight.

**Tech Stack:** Dart, Flutter, Hive, `.bsexport` source codecs.

**Spec:** `docs/work/done/IDEA-004-stable-bookmark-post-identity.md`

## Global Constraints

- The canonical equality components are normalized site namespace and stable upstream post key; engine and profile are metadata.
- Host is lowercase; non-default port and installation path remain; scheme, credentials, query, fragment, and trailing slash do not.
- Missing upstream IDs do not use 0, generated IDs, hashes, media URLs, or local row keys.
- Old local bookmarks and old exports need not remain readable.
- IDEA-002 owns profile UUID changes to `PostOrigin.profileIdHint`.

## Review Focus

- Two installations below one host stay distinct; test origin resolution and bookmark membership.
- Sankaku StringId survives a change in generated `Post.id`; test bookmarks built from two parser outputs.
- Pixiv pages of one work stay distinct even when the synthetic-ID algorithm changes; test explicit work/page keys.
- Missing upstream ID cannot merge unrelated posts; test an unavailable bookmark action or explicit error.
- A package identity disagreeing with its snapshot fails before mutation; test codec rejection.

---

### Task 1: Canonical site namespace

**Files:** Modify `lib/core/posts/post/src/types/post_origin.dart`; test `test/core/posts/post/post_origin_resolver_test.dart` and `test/core/bookmarks/bookmark_identity_test.dart`.

**Interfaces:** `normalizePostSourceHost(String source) -> String` continues to supply `PostOrigin.sourceHost` and profile resolution, now including the installation path.

- [x] Add failing cases for path separation, host case, default/non-default ports, scheme, query, fragment, credentials, and trailing slash.
- [x] Run focused tests and confirm the expected failures.
- [x] Implement canonical namespace normalization and run focused tests green.

### Task 2: Stable engine-specific post keys and unavailable posts

**Files:** Modify `lib/core/bookmarks/src/types/bookmark_identity.dart`, bookmark action entry points, and user-facing i18n as needed; test `test/core/bookmarks/bookmark_identity_test.dart` and focused provider tests.

**Interfaces:** `BookmarkIdentity.fromPost(Post)` builds a key from numeric upstream ID, `SankakuPostData.sankakuId`, or `PixivPostData.illustId/pageIndex`. An explicit failure represents an unkeyable post.

- [x] Add failing cases for engine-independent equality, distinct media sharing, Sankaku string/numeric ID, Pixiv pages, and absent upstream IDs.
- [x] Run focused tests and confirm the expected failures.
- [x] Implement stable key derivation, remove normal URL fallback, and make bookmark actions report unavailable IDs clearly.
- [x] Run focused tests green.

### Task 3: Package identity and documentation

**Files:** Modify `lib/core/backups/sources/bookmark_backup_codec.dart`, `lib/core/backups/sources/bookmarks_source.dart`, `docs/bookmark_groups.md`, and focused backup tests.

**Interfaces:** New bookmark source version carries `site` and `postKey`; decoding validates the supplied identity against the snapshot before an import plan can run.

- [x] Add failing round-trip and malformed-identity tests, including group membership and two installations.
- [x] Run focused tests and confirm the expected failures.
- [x] Implement the new source version and validation; document the contract.
- [x] Run focused tests green, format, analyze changed files, and run the full test suite.
