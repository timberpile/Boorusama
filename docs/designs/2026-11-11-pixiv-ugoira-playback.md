# Pixiv Ugoira playback

Baseline: `22348b2fb20049088705ce38f5b261e191b148af`.

## Implemented foundation versus missing behavior

[PixivClient.getUgoiraMetadata](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/packages/booru_clients/lib/src/pixiv/pixiv_client.dart) already calls `/v1/ugoira/metadata` with the genuine illustration ID. [PixivUgoiraMetadataDto](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/packages/booru_clients/lib/src/pixiv/types/pixiv_ugoira_metadata_dto.dart) retains a medium ZIP URL and ordered frame file/delay values. [The Post parser](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/boorus/pixiv/posts/parser.dart) sets isUgoira, but uses image URLs, image-derived format, unknown duration and an empty video URL. [PixivBuilder](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/boorus/pixiv/pixiv_builder.dart) supplies the ordinary shared presentation. [PostMedia](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/posts/details/src/widgets/post_media.dart) dispatches only video versus PostDetailsImage, without an Ugoira branch.

Thus recognition and metadata retrieval exist, but this inspected Pixiv-to-Viewer path does not implement frame-sequence playback. #140's wording about an existing animation Post is a model/scope statement, not sufficient evidence that animation plays. Preserve Ugoira as one Post rather than converting its animation frames into Work Pages.

Pixiv's official [Ugoira description](https://www.pixiv.help/hc/en-us/articles/235584628-What-are-Ugoira) confirms image sequences with individually specified frame timing. Do not substitute an ordinary GIF decoder or assume a ZIP is playable by the existing video engine.

## Recommended implementation boundary

Add a Pixiv-owned, access-scoped metadata/media resolver keyed by genuine illustId and the pinned account. Reuse the existing client/DTO, and expose cancellation through the public metadata method. Request metadata only when the animation is actually needed, not for every grid card. Keep static poster thumbnails in timelines and bounded neighbor preloading.

Connect a frame-sequence media representation to the shared Viewer presentation, keeping Pixiv endpoint logic outside generic widgets. Implement a small bounded frame player rather than a second Viewer or an obligatory FFmpeg/transcoding pipeline. Use elapsed playback time and cumulative frame durations, not one accumulating Timer per frame. Decode ahead into a bounded buffer; do not hold every full-resolution frame in memory. Reuse current media caching with keys including source/access and metadata revision. Dispose decoders and cancel transport on loss of demand.

Honor the existing automatic-media-loading and appropriate animation-autoplay behavior; when autoplay is disabled, retain the poster with an explicit Play action. Reuse shared pause/resume, zoom, viewport, lifecycle and #164 Immersive/Details transitions. Only the settled active occurrence should play. Backgrounding, neighboring pages and route transitions must not leave hidden playback running. Keep sound controls absent for a silent frame sequence.

Preserve existing saved `work-page:<illustId>:0` identity and server-favorite identity. Animation frames are internal media data, never individual bookmarks. Preserve static-image fallback for unavailable metadata or unsupported payloads. Report duration only after valid frame timing is known; do not report the poster's JPEG format/size as the animation's original format/size.

## Safety, quality and download semantics

Fetch the validated Pixiv CDN ZIP through the same source-bound media policy and required image Referer as other Pixiv media; do not send API bearer credentials to arbitrary ZIP hosts. Bound compressed size, total expanded bytes, frame count, per-frame dimensions and decoded buffer memory. Reject traversal/absolute paths, symlinks, duplicate or missing frame names, invalid delays and malformed archives. Use metadata order, not ZIP entry or lexical filename order.

The current DTO exposes only the medium ZIP URL. Do not derive a supposed original-resolution archive by replacing substrings in that URL. Label actual quality honestly until an authoritative original rendition is available. An animation download must preserve both frame bytes and timing metadata in a documented bundle; downloading only the poster or a timing-less ZIP is not a faithful animation export. MP4/GIF conversion is an optional separate feature, not a prerequisite for playback.

## Verification

Fixtures: variable delays, frame order, missing/repeated names, malformed ZIP, oversized expansion, invalid dimensions/timing, cancellation and account changes. Player tests with a controlled clock for pause/resume/loop/seek and bounded decoded frames. Regression-check bookmarks, filenames, sharing, format/duration filters and static Pixiv works. Authenticate a real Ugoira on Android and exercise rapid navigation, backgrounding, Details transition and memory usage. No playback, archive download or runtime implementation was executed here.
