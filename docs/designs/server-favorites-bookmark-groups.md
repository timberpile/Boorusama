# Fetch account favorites into regular bookmark groups

## Goal

Offer an optional, additive download of server-side Favorites to ordinary local bookmark groups across supported profiles. Do not create a destructive or bidirectional synchronization system.

The optional **Ignore synced groups for bookmark status** preference excludes all assigned favorites groups from toolbar bookmark highlighting and counts. It is on by default, persists locally with sync preferences, and does not change memberships or picker icons. Membership in any other group still highlights the button. Settings changes remain drafts until Save.

## Expected behavior

Every profile's Favorites page provides **Favorites Sync** in its overflow menu. There is no separate Server Favorites settings page. The same compact, scrollable dialog always shows:

1. **Default bookmark group**: a labeled bookmark group picker or **None**.
2. **All available profiles**, in saved profile order: name and icon, a labeled **Bookmark group** field, **Use default / None / Use different group**, and an override picker. Inherited values include the resolved group path, such as **Use default · Favorites**.
3. **Unavailable profiles**, in saved profile order at the bottom: only name, icon, and the concrete local availability reason, including unsupported engines and missing credentials. None, missing target groups, and transient fetch failures remain in the configurable list.

The single-line title uses the application's app bar text fitter and has an **Info** button. The main introduction says **Save server favorites to local bookmark groups.** The **About Favorites Sync** panel explains organizing, searching, and exporting favorites from multiple profiles; additive fetches; direct favorite/unfavorite updates; and the absence of server changes from local bookmark edits or automatic background fetching. All available profiles remain expanded. Visible **Save & Fetch all** and **Save & Fetch** text buttons with download icons sit below their respective target fields; failed jobs show **Save & Retry**. **Close** and **Save** share the footer row, with an outlined Close button. Save closes the dialog. Global and per-profile fetch actions save the draft and keep the dialog open to display progress, cancellation, errors, and retry, plus cancellation of all running jobs. Closing manually leaves jobs running; reopening displays their progress.

Changes remain drafts until saved. Global and all profile choices persist atomically, preserving unavailable profile assignments. Save & Fetch saves the whole draft before starting its selected profile. Save & Fetch all includes every supported, authenticated profile with a valid resolved target, including overrides; None, unavailable accounts, and missing targets are skipped. Capture each profile/account and target before launching work. Individual jobs remain independently cancellable/retryable and one failure must not prevent other profiles from fetching. An idle or failed profile can fetch while another job runs, using the saved assignments. Assignment controls, Save, and the global batch action stay locked during running jobs; an unsaved draft must not change another job's target through a fetch action. Successfully favoriting or unfavoriting a post directly updates the currently resolved local target after the server confirms success.

Every target remains a regular group: editable, renameable, and exportable.

## Accepted decisions and edge cases

- Select any existing ordinary group, including populated groups, through a dedicated single-choice destination picker. Reuse ordinary bookmark folder navigation and include **None**. Selecting one option immediately returns it to the form without changing bookmark memberships. Create a new group in the picker's current folder through the existing group-name dialog. Nested picker and creation routes provide their own compatibility scope for reused Flutter Material content.
- A first binding to a populated group requires a separate confirmation explicitly warning that all its existing bookmarks will be cleared. Clearing happens only when that save is confirmed, never merely by selecting the group. Bookmarks in other groups remain intact. Reject stale contents or changed accounts before clearing. Restore removed content if saving fails. This confirmed first-binding clear is the explicit exception to preserving content on assignment changes.
- An already assigned group may be shared without clearing or another destructive confirmation. Empty/new groups need no destructive confirmation. Names have no reserved value; assignments store UUIDs. No assignment starts a fetch.

- **Use global** resolves to no group when a global default is unset. There is no second per-profile enable switch.
- Fetch per profile with pagination, cancellation, and safe retry/resume behavior. Download the complete server listing before saving pages and posts in reverse listing order. This preserves favorite chronology where the source lists favorites newest first. Report fetched pages separately from saved pages. A download failure or cancellation adds no buffered posts; already committed pages during saving survive interruption and retry. Repeating pages must be idempotent using canonical post identity and group membership.
- Manual imports use the existing HTTP coordinator's bulk-transfer context, including nested post-detail lookups for thumbnail-only listings. Same-origin profiles share bulk pacing; cancelling a job prevents queued requests from starting. Do not automatically replay cooldown failures. Direct favorite/unfavorite projections retain interactive request handling.
- A failure, sign-out, cancellation, restart, timeout, or HTTP 429 preserves successfully added favorites. Retry must continue or safely repeat pages without dropping progress.
- Fetch is additive only: never remove locally saved posts on the basis of server-side changes. Manually removed favorites may reappear in later fetches. A deliberate rebuild is accomplished by clearing the ordinary group then fetching again.
- Do not describe this as an authoritative sync. No startup, lifecycle, periodic, or background fetch.
- A successful direct server favorite adds to the resolved group; a successful direct unfavorite removes from that group. Failed remote actions leave the group unchanged. Do not add per-profile provenance tracking to shared groups solely for rare overlapping server accounts.
- Successful additions publish the committed bookmarks and group membership while reusing existing decoded snapshots and indexes. Do not reload the entire saved library for each favorite. Keep serialized persistence and full-reload recovery after errors.
- Manual group changes must never write to server Favorites. Except for an explicitly confirmed populated first binding, changes to profile, account binding, target choice, or global default never transfer, purge, or reconcile existing group content.
- Opening from any profile produces the same configuration and fetch scope. Reject stale settings or changed profile accounts before saving, clearing, or starting a fetch. Signed-out Favorites pages retain the overflow entry; unauthenticated profiles appear in Unavailable profiles with their reason and retain their saved assignments.
- A direct projection must validate the captured session against the original action credentials after asynchronous capture. Account replacement rejects the local update rather than redirecting it; acknowledged remote results remain successful.
- Direct local projection has its own capability check and does not require an account-favorites query or API key after a successful remote mutation. Unsupported engines are silent during ordinary favorite actions; capability messages belong only in configuration. Realbooru and the Gelbooru V2 engine reuse the existing favorites-list client with its configured pagination, cookie/API credentials, raw post retrieval, and source identity. Thumbnail-only listings resolve full post details before bookmarking.
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

Current supported sources do not supply a verified per-account favorite timestamp to the importer. New bookmarks therefore retain their local import time; existing canonical bookmarks retain their original local date, including when added to another group or fetched again. Do not substitute upload dates, global last-favorited dates, vote dates, or invented times.

- [Danbooru's favorites table](https://github.com/danbooru/danbooru/blob/master/db/structure.sql) stores only ID, user ID, and post ID.
- e621 [stores a timestamp](https://github.com/e621ng/e621ng/blob/master/db/structure.sql), but its [favorites API](https://github.com/e621ng/e621ng/blob/master/app/controllers/favorites_controller.rb) serializes posts after the [favorite relation is discarded](https://github.com/e621ng/e621ng/blob/master/app/logical/post_sets/favorites.rb).
- Moebooru's [post API and vote serialization](https://github.com/moebooru/moebooru/blob/master/app/models/post/api_methods.rb) include post creation time and vote scores, not favorite times.
- Szurubooru's [post serializer](https://github.com/rr-/szurubooru/blob/master/server/szurubooru/func/posts.py) exposes favorite users without their relationship timestamps. `fav-date` denotes the last favorite by anyone, not necessarily the importing account.
- Gelbooru's [documented API](https://gelbooru.com/index.php?page=wiki&s=view&id=18780) has no favorite timestamp resource. The Gelbooru/Realbooru listing data consumed by the app has no verified favorite-time field; an anonymous Realbooru favorites-page inspection also found none. This does not establish that every third-party installation behaves identically.

Exact remote dates require a source that exposes that information. Local bookmarks currently share one creation date across group memberships and accounts, so differing remote dates would also need an explicit storage policy before replacing existing local dates.

## Acceptance boundaries

Test draft/save behavior, global inheritance and overrides, populated first-binding confirmation/cancellation, stale-content rejection and save rollback, shared groups without clearing, ordinary folder navigation and creation, None, unavailable accounts, target-existence validation, additive repeats, partial recovery, direct-action success/failure, deleted/changed targets, and export without binding metadata. Exercise the dialog at narrow width, enlarged text, and with the creation keyboard open.

Depends on stable bookmark identity and existing network-request coordination. The target identity must survive nested-folder renames and moves. Relevant documentation: [Bookmark architecture](../bookmark_groups.md).
