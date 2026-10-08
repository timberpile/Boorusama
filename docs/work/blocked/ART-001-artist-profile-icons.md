# Show available artist profile images in post information

Priority: Normal
Affected feature: Artist identity and post information
Status: Frozen at user request on 2026-10-08; design unresolved.

## Problem

Post information shows artist names without their profile images. Pixiv exposes
an uploader profile image, and a Danbooru artist may link to that artist's
Pixiv profile, but the post information UI currently uses neither source.

## Expected behavior

Show a real profile image beside the corresponding artist name when it can be
resolved reliably. The artist name remains immediately usable while an optional
image loads. If no trustworthy image is available, show the name without any
icon or empty placeholder.

## Original acceptance criteria (require revision before resuming)

These criteria describe the original Pixiv-focused scope. They are retained
for context and are not an approved implementation specification for the
source-based approach discussed below.

- [ ] On a Pixiv post, resolve the uploader's profile image from its known
  Pixiv user identity. Reuse a profile image already present in post data when
  available; otherwise use the existing authenticated Pixiv user-detail API.
- [ ] On a Danbooru post, resolve the displayed artist tag through its
  Danbooru artist record. If active linked URLs identify exactly one Pixiv user
  and an authenticated Pixiv profile is configured, obtain that user's profile
  image with the existing Pixiv client. Repeated URLs for the same user count
  as one identity; conflicting Pixiv user IDs do not produce an icon. Do not
  change the app's active booru profile to fetch the image.
- [ ] Show an image only beside the artist name to which it belongs in the
  post information panel. Preserve the existing artist tap action, text,
  commentary, and Follow control. Posts with multiple artist tags must never
  show one artist's image as another artist's identity.
- [ ] Missing URLs, unrecognized links, missing Pixiv configuration, expired
  authentication, request failure, and broken image URLs leave the artist name
  visible without an icon, error placeholder, or login interruption. Optional
  icon loading must not block post details or trigger a request for every grid
  card.
- [ ] Deduplicate and cache lookups by artist/Pixiv user identity so rebuilding
  the visible panel does not repeatedly fetch the same profile. Use the selected
  Pixiv profile's image request configuration for protected Pixiv image URLs.
- [ ] Focused tests cover direct Pixiv identity, one Danbooru-to-Pixiv link,
  repeated and conflicting links, missing authentication, failed lookup/image,
  and the unchanged artist action. Validate the post information layout on
  Android with Maestro; use deterministic tests for a positive image case if
  no suitable live artist account is available.

## Context and dependencies

Use genuine artist-account profile images. Do not substitute an artwork,
website favicon, generated avatar, or generic artist symbol. Parsing external
data must tolerate missing fields. The first display target is post information;
other artist listings can reuse the resolver in a separate task.

- [Danbooru artist record](../../../lib/boorus/danbooru/artists/artist/src/types/artist.dart)
- [Pixiv user detail](../../../packages/booru_clients/lib/src/pixiv/types/pixiv_user_detail_dto.dart)
- [Post information](../../../lib/core/posts/details_parts/src/information_section.dart)
- [Danbooru artist information](../../../lib/boorus/danbooru/posts/details/src/widgets/details_widgets.dart)

Dependencies: None.

## Previous claim (implementation paused)

- Implementer: Codex, 2026-10-08 session.
- Branch: `agent/art-001-artist-profile-icons`.
- Worktree: `.worktrees/art-001-artist-profile-icons`.

## Deferral and open design questions

The user requested freezing this ticket on 2026-10-08 because the desired
source-based solution is broader and more difficult than the initial scope.
No application code was changed; work stopped after repository inspection and
creating the isolated worktree.

The preferred direction discussed is to start from a post's original source,
resolve its artist account on the source platform, and cache the account's real
profile image by canonical platform and stable account identity. This should
support platforms beyond Pixiv rather than force all artists through Pixiv.
The discussion is a design direction, not a completed or approved design.

Before resuming, resolve:

- Which platforms are supported initially and how each reliably exposes account
  profile images. X/Twitter access, authentication, costs, and the feasibility
  of public retrieval remain open; arbitrary website parsing cannot guarantee
  that a discovered image is a profile image rather than artwork.
- How source links identify the original artist, including reposts, direct
  image/CDN links, missing sources, and posts with multiple artist tags. A
  source account must not be assigned to an unrelated artist tag.
- Whether and when artist-record profile links serve as a fallback, and how
  conflicting account identities are handled.
- Persistent cache lifetime, refresh and failure retry rules, and canonical
  platform aliases such as twitter.com/x.com. Shared lookups should use stable
  platform/account identity rather than artist display names.
- How optional authenticated lookups fail silently. The existing Pixiv client
  can open a session-expired dialog, so catching lookup errors alone does not
  satisfy the original no-login-interruption requirement.

Resume only after the user requests it and the scope/design and acceptance
criteria have been revised. No Flutter tests or Android/Maestro checks were
run because implementation did not begin.
