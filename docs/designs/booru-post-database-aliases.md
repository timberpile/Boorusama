# Verified booru host aliases and post identity

## Goal

Posts hosted through different access domains of the same underlying post database should share one bookmark identity. The motivating example to verify is danbooru.donmai.us and safebooru.donmai.us. Identical media on unrelated sites must continue to count as separate posts.

The same verified database identity can later determine which alternative profiles can favorite a given post.

## Approved behavior and constraints

- Maintain a built-in, repository-owned registry mapping **verified** host aliases to stable internal database identifiers (for example, **danbooru-main**). Do not add UI or user-configurable aliases.
- Derive bookmark identity from the canonical database identifier and stable upstream post key. Preserve compound keys, including Pixiv-page identities. MD5, media URL, and profile ID are not identity components.
- For unknown hosts, fall back to the normalized site namespace, retaining meaningful ports and installation paths. Do not attempt to enumerate every booru installation.
- Verify shared database ownership and compatible post IDs using authoritative site information or API examples before registering an alias. Engine type, redirects, common MD5, or hosting alone are insufficient evidence.
- Do **not** group safebooru.org, test instances, or unrelated Danbooru installations with the main Donmai database. Distinct IDs on the same database remain distinct; distinct databases remain distinct even with identical IDs or images.
- Registered host changes may keep stable identity through new explicit registry entries. Do not guess unregistered moves. Document where entries are maintained, evidence required, and how internal identifiers avoid collisions.
- Use identical canonicalization for live lookup, persistence, export, and import. Retain validation between exported identities and post snapshots; aliasing does not justify trusting inconsistent data.
- Migrate existing bookmarks and supported import/export records without losing group memberships or local references. Before implementation, design and review schema and migration behavior, duplicate reconciliation, conflicting snapshots, and remapping.
- Keep origin host, actual request host, profile/account resolution, and visibility/rating rules separate from canonical bookmark identity. Aliasing must **never** automatically forward credentials to another host or bypass safe-content restrictions.
- **Favorite with another profile** may reuse the registry for database compatibility, but must separately check the chosen target profile's capability and permissions.

## Before implementation

Confirm whether the Donmai safe and primary hosts truly expose shared stable post IDs; establish the migration/conflict rules before writing user-data changes.

Related architecture: [Bookmarks](../bookmark_groups.md), [Posts](../post_architecture.md), [stable bookmark identity](../bookmark_groups.md#backup-compatibility), and [alternative-profile favorite design](favorite-with-another-profile.md).
