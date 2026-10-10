# Following / Topics — interactive concept (v2)

This revises the previous `Pinned searches + Following Feeds` mockup. It is a **design prototype, not a Flutter implementation**. The directory retains its original name to keep the earlier mockup location and branch stable.

Open **`index.html`** in a modern browser, or serve the directory with `python -m http.server 8000`. The HTML is self-contained and needs no network, build, assets, packages, or real booru account. Search results, profiles, and thumbnails are illustrative fixtures. The browser stores demo edits under `boorusama.topics-following.mockup.v2`; open **Design notes → Reset demo** to discard them.

## Adopted product model

- **Following** is the *only* navigation entry, replacing both **Pinned searches** and **Following Feeds**. We do not use **Saved searches**; Danbooru already uses that name for another feature.
- **Topic** is a followed artist, tag, or arbitrary profile-bound search query. Selecting a topic opens the **ordinary search-results view**, with independent pagination. The mock implements repeatable **Load more posts** controls solely to illustrate that existing behavior; production should reuse its existing search page and pagination.
- **Folder** organizes topics and nested folders. It opens to its **contents (folders and individual topics)**, not automatically to an aggregate post grid.
- **Open Feed** is an action in the folder's **actual top app bar**. It opens a chronologically merged post view for the folder and all descendants. **No separate Feed model, feed creation, feed subscriptions, or feed management page** is required for the UX.
- Editing a topic changes the original shared search definition. Linking an existing topic into another folder never creates a duplicate search. **Remove from this folder** keeps the topic followed (moving it to the Following root if its last folder reference was removed); **Unfollow everywhere** is a separate confirmed destructive action.
- Topics can be mixed across profiles within a folder and consequently within its feed. Duplicate matches from the same origin are merged; numeric IDs from different booru sites remain distinct.

Root-level topics are accessible under Following; only folders have the Open Feed action. The mock uses English product copy, as should the Flutter implementation.

## Walkthrough

1. **Following** → see three folders and two top-level topics. There is no separate feeds screen.
2. Open **Daily inspiration** → see **Mosslight** and **Night trains** as individual topics, plus the **Landscapes** subfolder. The folder is a normal topic list, not a feed.
3. Select **Mosslight** → its normal post grid appears. Click **Load more posts** repeatedly to illustrate regular, independent search pagination. Return to the folder through **Back to folder**.
4. In **Daily inspiration**, choose **Open Feed** from the **top app bar**. The combined grid includes the nested Landscapes topics and multiple simulated sites. Switch profile or upload order; use **View Topics** to return to the same folder.
5. At the bottom of the feed, the explicit **End of feed preview** note distinguishes the *simulated short cached window* from the unresolved problem of historical feed pagination. There is deliberately **no Load more** button in the feed.
6. Edit **Mosslight** from its topic menu. Revisit **Color & form**: the same underlying topic is updated. Use **Add existing** to reference a followed topic without copying it, or **Follow topic** to add a new artist, tag, or query.
7. Long-press a topic or Shift-click to select multiple topics. Remove a folder reference without unfollowing; separately confirm **Unfollow everywhere**. Create a new folder and see that it immediately offers **Open Feed**, without a **Create feed** step.
8. Try **Phone preview**, **Light mode**, and **Gelbooru offline** in the prototype toolbar.

## Feed pagination deliberately deferred

This change is a UX and data-model proposal **only**. It does **not** assert that the existing feed can retrieve arbitrarily old posts or that storing the latest N per topic is a scalable pagination design. Feed previews display five synthetic cached posts per topic and stop, visibly marking that boundary. The normal individual-topic search uses an independent synthetic page generator to demonstrate the expected *existing* unlimited search behavior.

A later engineering work item should investigate actual retained snapshots (currently roughly the most recent 50 per source), history pagination, API request and per-host batching, memory usage, refresh/read state, cache expiry, missing upload timestamps, and partial failures. None are promised or hidden behind a mock infinite-scroll control.

## Technical implications for a future implementation

1. Existing pinned search records can serve as canonical Topics. Convert/migrate existing feed sources into the same collection, reconciling duplicates and preserving folder membership, names, profiles, and refresh/read state. Folders should reference topics; removing a link must not delete a canonical topic still used elsewhere.
2. Treat a feed as a **folder view**, not as independently managed data. A feed runtime/cache may still be a separate internal service. Remove the one-profile assumption at the boundary of source resolution; resolve adapters and repositories per search source and post origin. Deduplicate by **site/instance + post ID** (also preserve profile context for authorization/actions), not by raw numeric ID.
3. Query edits invalidate all affected feed views even if referenced topic IDs remain the same. Descendant topics count once when a topic is referenced through multiple paths.
4. Account removal, backup/import/export, migration from existing Following Feeds, offline failures, request limits, refresh scheduling, and actual feed pagination require dedicated implementation/design work. The mock does not perform this migration.
5. Flutter screens should reuse the existing search viewer, pinned-search/folder management and selection patterns, folder-tree picker and Kurumi popups. This conceptual styling is not a new Flutter design system.

## Verification

Run `python test_mockup.py` in this directory. Chromium and Python Playwright are required; set `CHROMIUM_PATH` if needed. The suite runs the self-contained HTML in an isolated browser with a local-storage double and no network.

**20 Chromium checks passed** for navigation, regular topic pagination, Open Feed, descendant inclusion, cross-profile deduplication, filtering/sorting, shared edits, follow/reuse, safe remove/unfollow, new folders, long-press/Shift selection, menu dismissal, validation, simulated offline state, persisted fixtures, HTML escaping, and narrow layouts including a 390 × 420 viewport. These are mockup checks, not real Flutter, Android, or API acceptance tests.

The repository's Flutter/FVM-wide verification suite was **not run** in this environment. No production app code is changed in this branch.