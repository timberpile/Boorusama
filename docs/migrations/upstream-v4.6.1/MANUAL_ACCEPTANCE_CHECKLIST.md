# Upstream v4.6.1 manual acceptance checklist

The user performs these checks on a disposable test installation after reviewing
the local migration candidate. Do not use irreplaceable data. Complete the
priority 0 checks before considering the branch for integration; priorities 1
and 2 provide broader UI and platform confidence.

## Priority 0 — data and upgrade safety

- Upgrade an installed `4.5.0-timberpile.5` production-signed APK to the matching
  v4.6.1 candidate for each supported ABI. Confirm the package identity, signer,
  effective version-code increase and retained app data.
- Open existing profiles, bookmarks and bookmark folders, pinned-search folders,
  Following feeds, favorite tags and automatic-backup settings. Confirm UUIDs,
  membership, ordering and saved credentials remain associated with the correct
  profile.
- Export a full backup, review it, then restore it into a disposable installation.
  Confirm bookmark/folder trees, pinned searches, Following feeds and favorite
  tags round-trip without duplicates or dropped entries.
- Confirm app-lock and privacy defaults did not change, and that existing user
  overrides still apply. Dismiss What's New, restart twice and confirm it does
  not reappear for the same version.

## Priority 1 — network, media and downloads

- Browse, search, paginate and refresh representative configured sites, including
  Rule34 and Sankaku. Confirm login state, Cloudflare recovery, rate-limit waits,
  favorites/votes/comments and error messages behave without duplicate actions.
- On Rule34, test a normal result page, a later page and a no-result query with a
  valid API key. On Sankaku, test ordinary tags plus date/rating/order metatags.
- Exercise static images, animated GIFs below and above 5 MiB, video source
  switches, cached-video replay, clear-cache during playback, zoom/pan/page swipe,
  retry and share. Confirm posters remain until the first video frame and active
  media is not deleted while in use.
- Download one item and a small bulk set with sidecars Off, TXT and JSON. Confirm
  genuine source IDs/URLs, no credentials in metadata, durable completion, retry
  of metadata alone, and no new sidecar when an existing media file is skipped.
- On Android, open the read-only cache document provider. Confirm only valid,
  completed cache files appear and cannot be modified through the provider.

## Priority 2 — responsive and input UI

- At phone width and tablet/desktop width, open Settings, toggle Settings Search,
  navigate to Topic Updates and Data & Storage, and verify dynamic titles and
  cache locations. Repeat at 200% text scale and with the soft keyboard open.
- In unified search, type above the keyboard, scroll history, move through
  suggestions with a keyboard/D-pad, submit, and dismiss nested UI one layer at a
  time with Escape/Back.
- Configure two thumbnail quick actions and verify each on normal, banned and
  mixed-origin posts. Check long press, right click, selection, Kurumi menus,
  bookmark-group actions and no tap-through after dismissal.
- Open the favorite-tag editor at phone and tablet widths. Confirm the compact
  sheet/dialog choice, all existing labels and keyboard accessibility.

Record the candidate commit, device/OS, installed source and destination
versions, ABI, results and any screenshots or logs that contain no credentials.

## Review repair acceptance

- Fail a grid/viewer image request, then use Retry. Check that ordinary tile taps
  and selection still work, and that the viewer retains its preview during retry.
- Create a metadata conflict after a successful download. Open the metadata
  notice from Downloads or Bulk Downloads, correct the folder/conflict and retry;
  the media must not download again.
- Use Sankaku Search Options on phone and desktop for rating, date, sort order,
  uploader, pool and user favorites; check chips, raw syntax and results together.
- Import a profile with an unknown thumbnail action or invalid media host option.
  Check the warning before approval and preservation of its UUID and other data.
- On Android, solve a challenge at a protected path and confirm cookie transfer
  works without making it eligible for HTTP or unrelated paths.

## Reported regression follow-up — 2026-10-17

These checks remain user-run acceptance on the final candidate; automated tests
cover the failure mechanisms but do not replace Android document-provider or
live-site playback/voting checks.

- From Settings → Backup and Restore, confirm there is one **Export & import**
  heading. Select a `.bsexport` from Android Downloads and another document
  provider; neither should be greyed out. Confirm `.zip` also reaches import
  review, an unrelated file shows the localized error, and cancellation is quiet.
- With GIF autoplay enabled, check eligible Danbooru GIFs in **Automatic** at
  small and large grid sizes. At every quality, originals larger than 5 MiB
  remain static; disabling autoplay makes all GIF previews static. Check both
  ordinary browsing and Following timelines. Original size/format, rather than
  a transcoded sample's extension, controls the limit.
- With Auto engine and an MP4, play beyond 0:00, open the post details panel,
  then close it twice. Position and playback must continue without resetting or
  freezing. Repeat while paused; opening/closing details must keep it paused.
  Other engines and WebM still need device coverage. The earlier whole-video
  freeze was no longer reproducible after the user's fresh installation.
- On Danbooru, favorite a post and remove its automatic upvote while keeping the
  favorite. Repeat after opening a fresh result page while votes are loading.
  Confirm ordinary upvote/removal also still works. The intermittent server
  toast needs live confirmation even though the stale-preload race is covered
  by a controlled regression test.
