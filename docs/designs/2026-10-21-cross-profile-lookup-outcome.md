# Find on Other Profiles — Delivered Behavior

**Purpose:** Post-merge documentation correction for completed [Issue #49](https://github.com/timberpile/Boorusama/issues/49). The previous issue description is stale: the delivered flow no longer requires a manually selected target, and matching is no longer MD5-only. The authoritative implementation details remain in [`lib/core/posts/cross_profile_lookup/README.md`](../../lib/core/posts/cross_profile_lookup/README.md).

## Delivered behavior

- Opening **Find on Other Profiles** from a post automatically searches all supported configured target profiles other than the source, using bounded concurrency. Unsupported targets appear in a compact footer.
- Search each target using the verified methods available for it, in preference order: **Exact File Match (MD5)** → **Pixiv Artwork Match** → **Source URL Match**. Results state the actual kind of evidence; a source match is not falsely described as an exact file match.
- Danbooru supports all three modes, Gelbooru supports MD5 and source URL, and supported Rule34 API targets support MD5. Other access modes/hosts remain explicitly unsupported rather than inferred.
- Empty completed results may fall through to a supported next method. Request failures, invalid/incomplete responses and cancellation do not silently change the method.
- Show thumbnails, progress, unsupported/no-match/errors and explicit load-more. Keep even a unique complete result on the results page until the user chooses to open it.
- Use each target's credentials, endpoint, restrictions and blacklist. Opening a post uses the target context, without changing the globally active profile; Back returns to the previous screen. Never assume post IDs are portable across independent databases.
- Shared results components can be reused by [Issue #54 — Pixiv Share](https://github.com/timberpile/Boorusama/issues/54). Android Share handling is not part of #49.

## Proposed correction to the closed GitHub issue

The following text is ready to replace the stale **Problem** / **Expected behavior** in #49 after review. **This file does not modify the GitHub issue or reopen it.**

### Problem

Finding a post across configured Booru profiles requires manual searching and can confuse an exact-file match with a match by artwork or source reference.

### Expected behavior

- Offer **Find on Other Profiles** from the single-post actions and automatically query compatible profiles with bounded concurrency. Summarize unsupported targets separately.
- For each target, try supported lookups in order: **MD5 → Pixiv artwork ID → source URL**. Display the match kind clearly and never claim a source match is an identical file.
- Show results by profile with thumbnails, loading and error states, and explicit pagination. Keep results visible until the user chooses a post.
- Respect target-specific credentials, visibility and blacklists. Open matched posts with their target profile and preserve the original navigation and active profile.
- Use the shared result interface for the separate Pixiv Android Share workflow tracked by #54. Android Share handling, visual matching and bulk lookup remain out of scope.

Delivered code behavior and supported capability details should be checked against the repository README before editing the closed issue body.
