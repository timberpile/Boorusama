# Boorusama link-file MVP

A small `.bslink` document opens a post or search in the recipient's app.
No domain, webserver, sender account export, or recipient configuration is
required. The HTTPS/webserver work is paused; this feature is not released.

## Sharing

- **Post > Share > Links > Boorusama Link File** sends one document.
  It does not download an image or video and works without a preview image.
- **Current search-results header > Share** sends one `.bslink` document.
  Following Topic and feed-member menus do not share `.bslink` files because
  those files represent post or search references, not local saved state.
- Raw `boorusama://` Copy/Share controls and image-plus-document sharing are
  removed. The validated URI remains an internal field of the document, not
  a separately shared or copyable URL. Ordinary website/source/image links,
  media sharing, and post-ID copying are unchanged.
- Each handoff owns its file independently of the image cache. Expired handoffs
  are cleaned up on later shares after a 24-hour grace period. A successful
  platform handoff does not prove that the messenger delivered the attachment.

## Message UX

The **Boorusama Link File** entry in the post share sheet uses a solid,
monochrome, three-faced box derived from the app logo (without the tape or T),
and follows the current icon theme. The search toolbar keeps the standard
Share icon so its purpose is recognizable. Sharing sends a standalone
attachment with a single-line caption. No raw link, file extension, extra
instruction line, or Markdown is inserted into the message.

Examples, using the sender's configured source-profile name:

```text
Post 123456 by example_artist on My Danbooru
Post 123456 on My Danbooru
Search 'one_piece -rating:safe' on My Danbooru
```

The source profile is selected by post-origin hint and matching site/engine,
rather than an unrelated account selected in a mixed viewer. Search-result
sharing uses the current search profile. Profile names are displayed only in
the caption, not persisted to the portable document. If the source profile is
not available, the source host is a fallback.

Posts show the genuine site ID, not synthetic Pixiv page IDs. One known artist
may be shown when existing post metadata provides it; unknown-artist/request
tags are ignored, and nothing is fetched solely to build the caption. Searches
use the actual raw query or readable typed tags. Displayed terms are bounded,
but the attachment always contains the complete query. External artist,
profile and search text is sanitized to prevent line-break or bidi-control
injection. German UI uses localized grammar.

## Opening

Open the attachment on the receiving device, using **Open with** or
**Share > Boorusama** when offered. Both devices need a build with this MVP.
The existing recipient profile selection and profile-creation flow apply;
opening a file never follows a search or imports account settings.

For manual testing in a development build, save the attachment, then use
**Settings > Developer Options > Open in Boorusama (.bslink)**. The manual opener
is absent from the main menu, desktop sidebar, and Data and Storage settings.
It follows the existing development-flavor visibility of Developer Options;
opening a received attachment remains available in production builds.
Cancelling the picker does not navigate; renamed files are accepted only after
content validation.

## Reported device results

The user reported these results on 2026-10-20; they are not automated tests:

- **Signal:** standalone `.bslink` sharing and opening work. A mixed share
  advertised two files in Android's chooser but delivered only the image.
- **WhatsApp:** mixed sharing delivered only text. Opening a standalone file
  did not offer Boorusama. The MIME/URI delivered by that installed WhatsApp
  version has not been captured; association remains an open limitation.

Mixed-file output is removed instead of promising delivery the app cannot
verify. The working receiver and file format are unchanged. Do not register the
app as the generic viewer for every file merely to work around a messenger.

## Document and trust boundary

Extension: `.bslink`. MIME: `application/vnd.boorusama.link`.
Apple UTI: `com.timberpile.boorusama.link`.

```json
{"format":"boorusama-link","version":1,"uri":"boorusama://post/open?v=1&engine=danbooru&site=https%3A%2F%2Fsite.test&key=id%3A42"}
```

The bounded, strict parser only permits a supported post or search reference.
Data is never executable code, an arbitrary URL to launch, or a profile/backup
import. A `.bslink` suffix alone does not validate a document.

## Verification for this cleanup

Regression sources cover single-file handoffs, absence of raw/mixed controls,
post sharing without image acquisition, readable and bounded captions, exact
Pixiv/Sankaku identity, current search sharing, absence of link-file actions
from Following Topic and feed-member menus, disabled and re-entrant sharing,
developer-only manual opening and picker cancellation, and absence of the
opener from the main menu/sidebar at narrow/desktop widths and large text.
The obsolete raw-URI tests are replaced by file-based behavior tests; unrelated
following-topic tests are preserved unchanged.

The initial editing environment had no Flutter/FVM SDK. Local integration on
2026-10-20 subsequently regenerated the merged translations, formatted the Dart
changes, passed focused analysis, completed the full application/package/CLI/
tooling gate, and built the combined Android dev APK. The integration combines
feature tip `7bb59ee85` with develop base `7d58c7d867`; the source/test evidence is retained in Git history. The current contract
is documented in [Post architecture](post_architecture.md#portable-boorusama-post-links)
and this MVP document.
No patch files, standalone test scripts, or CI workflows are included. The
reported messenger limitations above and outstanding Apple/device acceptance
remain documented; integration does not claim those checks were repeated.
