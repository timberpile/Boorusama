# Fetch account favorites into regular bookmark groups

## Goal

Offer an optional, additive download of server-side Favorites to ordinary local bookmark groups across supported profiles. Do not create a destructive or bidirectional synchronization system.

**Count Synced Groups as Bookmarks** in **Settings → Appearance** includes assigned favorites groups in toolbar bookmark highlighting and counts when enabled. It is off by default and uses the inverse of the existing stored preference. Membership in any other group still highlights the button. The switch leaves memberships and picker icons intact.

## Expected behavior

Every profile's Favorites page provides **Favorites Sync** in its overflow menu. There is no separate Server Favorites settings page. The same compact, scrollable dialog always shows:

1. **Default Group** shows the resolved group path or **None** and opens the bookmark group picker.
2. **Profiles** lists available profiles in saved order. Each row shows the profile name, source icon, destination, and a separate Fetch action. Inheriting profiles show **Default**. One editor can expand at a time with **Use Default**, **Disabled**, and **Different Group**. Collapsing a row keeps its draft.
3. **Unavailable (N)** starts collapsed. Expanding it shows the affected profiles in saved order, their retained destinations, and their availability reasons. Disabled profiles, missing target groups, and transient fetch failures remain configurable.

The header shows **Favorites Sync**, Info, and Close. The Info panel describes additive fetches, direct favorite and unfavorite updates, and what can be done with the local groups. The footer keeps **Close** and **Save** visible while the content scrolls. Closing with unsaved changes prompts for confirmation. Save persists the draft and leaves the dialog open, with zero fetches. **Fetch All Favorites** appears beneath the profiles. Active jobs show downloading or saving counts and Cancel in their profile rows. Failed or cancelled rows offer Retry. An active bulk fetch also shows aggregate counts and **Cancel All**. Closing leaves jobs running, and reopening shows their progress.

Global and profile assignments persist atomically and preserve unavailable profile assignments. Fetch and Retry require a clean draft and use saved assignments. Bulk fetch includes each supported, authenticated profile with a valid resolved target, including overrides. Capture each profile account and target before launching work. Individual jobs can be cancelled or retried independently, and one profile can fetch or retry while another job runs. Assignment controls, Save, and bulk fetch stay locked during running jobs. A direct favorite or unfavorite updates the currently resolved local target after the server confirms success.

Every target remains a regular group: editable, renameable, and exportable.

## Accepted decisions and edge cases

- Select any existing ordinary group, including populated groups, through the shared single-choice destination picker. The default picker also offers **None**. Selecting an option returns it to the draft and leaves bookmark memberships intact. Create a group in the picker's current folder through the existing group-name dialog.
- Assigning or changing a target is always non-destructive, including the first binding. Preserve existing Posts, Pool/Series/Collection/Related references, snapshots, local IDs, all group memberships, and their added dates. There is no first-use clearing, destructive confirmation, or clearing rollback. A failed settings write leaves both the saved assignment and library unchanged.
- A populated group may be shared by any compatible profiles without clearing. Empty/new groups use the same assignment path. Names have no reserved value; assignments store UUIDs. Saving an assignment starts no fetch. Only the explicitly invoked fetch actions start network work.

- **Use global** resolves to no group when a global default is unset. There is no second per-profile enable switch.
- Fetch per profile with pagination, cancellation, and safe retry/resume behavior. Download the complete server listing before saving pages and posts in reverse listing order. This preserves favorite chronology where the source lists favorites newest first. Report fetched pages separately from saved pages. A download failure or cancellation adds no buffered posts; already committed pages during saving survive interruption and retry. Repeating pages must be idempotent using canonical post identity and group membership.
- Manual imports use the existing HTTP coordinator's bulk-transfer context, including nested post-detail lookups for thumbnail-only listings. Same-origin profiles share bulk pacing; cancelling a job prevents queued requests from starting. Do not automatically replay cooldown failures. Direct favorite/unfavorite projections retain interactive request handling.
- Pixiv fetches a verified account's Public and Private listings through independent cursors. Both can appear in ordinary bookmark exports. Each artwork uses its existing local Work or Ugoira bookmark type. The saved order follows each listing, with new Public entries displayed before new Private entries. The separate Pixiv Favorites visibility control applies to browsing.
- A failure, sign-out, cancellation, restart, timeout, or HTTP 429 preserves successfully added favorites. Retry must continue or safely repeat pages without dropping progress.
- Fetch is additive only: never remove locally saved posts on the basis of server-side changes. Manually removed favorites may reappear in later fetches. A deliberate rebuild is accomplished by clearing the ordinary group then fetching again.
- Do not describe this as an authoritative sync. No startup, lifecycle, periodic, or background fetch.
- A successful direct server favorite adds to the resolved group; a successful direct unfavorite removes from that group. Failed remote actions leave the group unchanged. Do not add per-profile provenance tracking to shared groups solely for rare overlapping server accounts.
- Successful additions publish the committed bookmarks and group membership while reusing existing decoded snapshots and indexes. Do not reload the entire saved library for each favorite. Keep serialized persistence and full-reload recovery after errors.
- Manual group changes must never write to server Favorites. Changes to profile, account binding, target choice, or global default never transfer, purge, or reconcile existing group content.
- Opening from any profile produces the same configuration and fetch scope. Reject stale settings or changed profile accounts before saving or starting a fetch. Signed-out Favorites pages retain the overflow entry; unauthenticated profiles appear in Unavailable profiles with their reason and retain their saved assignments.
- A direct projection must validate the captured session against the original action credentials after asynchronous capture. Account replacement rejects the local update rather than redirecting it; acknowledged remote results remain successful.
- Direct local projection has its own capability check and does not require an account-favorites query or API key after a successful remote mutation. Unsupported engines are silent during ordinary favorite actions; capability messages belong only in configuration. Realbooru and the Gelbooru V2 engine reuse the existing favorites-list client with its configured pagination, cookie/API credentials, raw post retrieval, and source identity. Realbooru sync saves explicit preview-only snapshots from validated listing pages. Existing complete bookmarks retain their media and dates. Viewing or requesting full media can resolve an exact Post under its captured source and current access policy. The preview-only marker survives backup and transfer, and a thumbnail cannot supply an original download or share.
- Export/import the group as an ordinary unbound bookmark group. Exclude credentials, profile assignments, cursors, and active Favorites behavior. Respect current import/export compatibility.

## Favorite ordering

The importer previously created bookmarks in server listing order, so a newest-first server list became oldest-first under the local newest-bookmark sort. Reverse the whole listing, including page order, before creating missing bookmarks. Keep current creation times and use local insertion IDs to break equal-time ties; do not manufacture historical dates. Preserve existing bookmarks and their dates on repeated fetches or when another profile shares the group. This fixes future additions; it does not reorder already saved bookmarks.

Fetching has two phases: collect deduplicated pages with account/target validation and cancellation, then save from the last page backward with the same validation and mutation queue. A failed/cancelled download leaves no new bookmarks. A failed/cancelled save preserves its committed oldest prefix, and an idempotent retry appends the remaining posts in order. This avoids reversing only individual pages, and avoids rewriting dates when older pages arrive later.

- Danbooru uses `ordfav:` and Moebooru uses `order:vote`, preserving their server favorite/vote order.
- e621 uses its dedicated `/favorites.json` endpoint, whose [server implementation](https://github.com/e621ng/e621ng/blob/master/app/logical/post_sets/favorites.rb) sorts favorite records by creation time. The previous `fav:` post search did not guarantee favorite order.
- Gelbooru V2/Realbooru retains the order of the dedicated favorites listing.
- Gelbooru's `fav:` search and Szurubooru's `special:fav` search do not expose a verified account-specific favorite ordering. Preserve their returned list order rather than claiming true favorite chronology. Szurubooru's `fav-date` sorts the last favorite by anyone, so it is not an account-order substitute.
- Several profiles sharing a group have no global chronology because exact server dates are unavailable. Fetching one profile is additive and does not clear, retimestamp, or reorder another profile's existing bookmarks.

## Favorite dates

Current supported sources do not supply a verified per-account favorite timestamp to the importer. New bookmarks therefore retain their local import time; existing canonical bookmarks retain their original local date. Group-specific membership dates are independently governed by the Bookmark library; repeat fetches must not rewrite existing memberships. Do not substitute upload dates, global last-favorited dates, vote dates, or invented times.

- [Danbooru's favorites table](https://github.com/danbooru/danbooru/blob/master/db/structure.sql) stores only ID, user ID, and post ID.
- e621 [stores a timestamp](https://github.com/e621ng/e621ng/blob/master/db/structure.sql), but its [favorites API](https://github.com/e621ng/e621ng/blob/master/app/controllers/favorites_controller.rb) serializes posts after the [favorite relation is discarded](https://github.com/e621ng/e621ng/blob/master/app/logical/post_sets/favorites.rb).
- Moebooru's [post API and vote serialization](https://github.com/moebooru/moebooru/blob/master/app/models/post/api_methods.rb) include post creation time and vote scores, not favorite times.
- Szurubooru's [post serializer](https://github.com/rr-/szurubooru/blob/master/server/szurubooru/func/posts.py) exposes favorite users without their relationship timestamps. `fav-date` denotes the last favorite by anyone, not necessarily the importing account.
- Gelbooru's [documented API](https://gelbooru.com/index.php?page=wiki&s=view&id=18780) has no favorite timestamp resource. The Gelbooru/Realbooru listing data consumed by the app has no verified favorite-time field; an anonymous Realbooru favorites-page inspection also found none. This does not establish that every third-party installation behaves identically.

Exact remote dates require a source that exposes that information and an agreed policy for whether and where to retain it. They must not replace existing local membership dates implicitly.

## Acceptance boundaries

Test draft/save behavior, global inheritance and overrides, populated first and subsequent assignments without prompts or content mutation, concurrent content changes, stale-account rejection and settings-write failure, shared groups, ordinary folder navigation and creation, None, unavailable accounts, target-existence validation, additive repeats, partial recovery, direct-action success/failure, deleted/changed targets, and export without binding metadata. Exercise the dialog at narrow width, enlarged text, and with the creation keyboard open. Preserve mixed Post/Pool/Related memberships and dates across a cold reload.

Authenticated Pixiv acceptance is pending. The available Android test installations use the previous release's storage generation or have a signing certificate that prevents installing the candidate alongside their test data.

Depends on stable bookmark identity and existing network-request coordination. The target identity must survive nested-folder renames and moves. Relevant documentation: [Bookmark architecture](../bookmark_groups.md).
