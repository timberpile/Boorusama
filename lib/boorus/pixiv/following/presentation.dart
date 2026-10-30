import 'package:booru_clients/pixiv.dart';

import '../../../core/posts/rating/types.dart';
import '../posts/parser.dart';

String? pixivFollowingImageUrl(String? value) {
  final uri = Uri.tryParse(value ?? '');
  if (uri == null || uri.scheme != 'https' || uri.port != 443 ||
      uri.userInfo.isNotEmpty ||
      !(uri.host == 'pximg.net' || uri.host.endsWith('.pximg.net'))) return null;
  return value;
}

/// Only supplied previews: no detail or artist-artwork requests are scheduled.
/// Keep the rating with the URL so the card can apply the normal media cover.
List<({int? artworkId, String url, Rating rating})> pixivFollowingPreviews(
  PixivFollowingArtist artist, {
  required int maxRestriction,
}) {
  final previews = <({int? artworkId, String url, Rating rating})>[];
  for (final artwork in artist.illusts.take(3)) {
    final rating = pixivRatingFrom(
      xRestrict: artwork.xRestrict,
      sanityLevel: artwork.sanityLevel,
    );
    if (artwork.visible == false || artwork.isMuted == true ||
        (artwork.xRestrict ?? 0) > maxRestriction ||
        (rating.isExplicit && maxRestriction < 1) ||
        (artwork.user?.id != null && artwork.user!.id != artist.user.id)) {
      continue;
    }
    final url = pixivFollowingImageUrl(
      artwork.imageUrls?.squareMedium ?? artwork.imageUrls?.medium,
    );
    if (url != null) {
      previews.add((artworkId: artwork.id, url: url, rating: rating));
    }
  }
  return previews;
}

List<String> pixivFollowingPreviewUrls(
  PixivFollowingArtist artist, {
  required int maxRestriction,
}) => [
  for (final preview in pixivFollowingPreviews(
    artist,
    maxRestriction: maxRestriction,
  )) preview.url,
];
