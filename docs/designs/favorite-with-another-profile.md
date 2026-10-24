# Favorite a post through a different compatible profile

## User scenario

While browsing with one profile, a user discovers a post that should be favorited through a different compatible account without leaving the current post.

## Interaction

- A long press on the Post Viewer favorite button opens **Favorite with…** listing other compatible profiles. The normal tap behavior is unchanged.
- Offer this action only when another profile can favorite the same underlying post database. Similar hostnames or engine type alone are not sufficient evidence; exclude independent databases.
- Identify the destination by profile/account and site where needed. Use **only** the selected destination's credentials; never fall back silently to the browsing account.
- Favoriting through the destination keeps the current browsing profile, opened post, and viewer position unchanged. The command is **not** a toggle: an existing favorite stays favorited.
- Respect access, visibility/rating rules, and actual availability in the destination. Do not use credentials from the origin profile to bypass destination restrictions. Failures must be understandable, diagnosable, and retryable; cancellation makes no changes.
- Favorite status and cache must remain scoped to their actual account/profile. Success in the destination must not falsely mark the current profile's server favorite.
- Supporting thumbnail favorite buttons is optional **only** when the same implementation can be reused simply. Post Viewer support is required. Note the decision in review.

## Shared-host compatibility

Use the [verified booru database registry](booru-post-database-aliases.md) for compatibility. Confirm, rather than assume, whether danbooru.donmai.us and safebooru.donmai.us share one database.

Canonical database identity does not imply that credentials can cross hosts. Original post origin, destination host, profile/account selection, and authentication remain distinct.

Two configured profiles of the same remote account are not separate server-side favorite collections; do not claim otherwise.

## Boundaries

No bulk fetch, automatic server Favorite sync, or changes to local bookmark membership are part of this feature. See [Post architecture](../post_architecture.md), existing profile-scoped favorite handling, and the separate [server-favorites import design](server-favorites-bookmark-groups.md).
