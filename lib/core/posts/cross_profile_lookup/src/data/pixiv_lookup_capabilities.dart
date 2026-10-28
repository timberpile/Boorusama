import '../../../../boorus/booru/types.dart';
import '../../../post/types.dart';

/// These host/API pairs have positive and negative live-query controls recorded
/// in the #54 handoff. A shared engine name alone does not enable another host.
bool supportsSharedPixivOrigin(PostOrigin origin) => switch (origin.booruType) {
  BooruType.danbooru => true,
  BooruType.gelbooru => origin.sourceHost == 'gelbooru.com',
  BooruType.gelbooruV2 => const {
    'rule34.xxx',
    'safebooru.org',
  }.contains(origin.sourceHost),
  _ => false,
};

List<String> pixivSourceQueries(PostOrigin origin, String id) {
  if (!RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(id)) return const [];
  if (origin.booruType == BooruType.danbooru) return ['pixiv_id:$id'];
  if ((origin.booruType == BooruType.gelbooru &&
          origin.sourceHost == 'gelbooru.com') ||
      (origin.booruType == BooruType.gelbooruV2 &&
          origin.sourceHost == 'rule34.xxx')) {
    // These are candidate searches, not proof of identity. Returned metadata
    // must independently establish the exact artwork ID (123 must not match 1234).
    return [
      'source:*pixiv.net/*artworks/$id*',
      'source:*pixiv.net/*illust_id=$id*',
      'source:*pximg.net/*/${id}_p*',
    ];
  }
  return const [];
}
