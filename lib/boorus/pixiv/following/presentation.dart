import 'package:booru_clients/pixiv.dart';

String? pixivFollowingImageUrl(String? value) {
  final uri = Uri.tryParse(value ?? '');
  if (uri == null || uri.scheme != 'https' || uri.port != 443 ||
      uri.userInfo.isNotEmpty ||
      !(uri.host == 'pximg.net' || uri.host.endsWith('.pximg.net'))) return null;
  return value;
}

/// Only supplied previews: no detail or artist-artwork requests are scheduled.
List<String> pixivFollowingPreviewUrls(
  PixivFollowingArtist artist, {required int maxRestriction}
) => [
  for (final artwork in artist.illusts.take(3))
    if (artwork.visible != false && artwork.isMuted != true &&
        (artwork.xRestrict ?? 0) <= maxRestriction &&
        (artwork.user?.id == null || artwork.user!.id == artist.user.id))
      if (pixivFollowingImageUrl(
        artwork.imageUrls?.squareMedium ?? artwork.imageUrls?.medium,
      ) case final url?) url,
];
