import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_libavif/flutter_libavif.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../boorus/booru/types.dart';
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/manage/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../developer_options/providers.dart';
import '../../../../images/providers.dart';
import '../../../../posts/listing/providers.dart';
import '../../../../posts/listing/types.dart';
import '../../../../posts/post/types.dart';
import '../../../../settings/providers.dart';
import '../types/search_following_feed.dart';
import 'search_subscriptions_notifier.dart';

final feedMemberPreviewProvider = FutureProvider.autoDispose
    .family<List<ImageProvider>, ({String feedId, String sourceId})>((
      ref,
      key,
    ) async {
      final state = ref.watch(searchSubscriptionsProvider).valueOrNull;
      final feed = state?.feeds.where((f) => f.id == key.feedId).firstOrNull;
      final source = state?.subscriptions
          .where((s) => s.id == key.sourceId)
          .firstOrNull;
      final profiles = ref.watch(booruConfigProvider);
      final owner = profiles
          .where((p) => p.id == source?.profileId)
          .firstOrNull;
      final global = ref.watch(settingsProvider.select((s) => s.listing));
      final loading = ref.watch(automaticMediaLoadingEnabledProvider);
      if (!loading ||
          feed == null ||
          source == null ||
          owner == null ||
          source.profileId != feed.profileId ||
          !feed.sourceIds.contains(source.id)) {
        return const [];
      }
      final listing = switch (owner.listing) {
        final override? when override.enable => override.settings,
        _ => global,
      };
      final settings = GridThumbnailSettings(
        imageQuality: listing.imageQuality,
        animatedPostsDefaultState: listing.animatedPostsDefaultState,
        gridSize: listing.gridSize,
      );
      final resolver = ref.watch(gridThumbnailUrlGeneratorProvider(owner.auth));
      final codec = ref
          .watch(booruPostCapabilityProvider(owner.auth.booruType))
          ?.codec;
      final byId = {
        for (final snapshot in feed.posts) feedPostId(snapshot): snapshot,
      };
      final candidates = <List<Future<Uint8List?>>>[];
      for (final preview in source.previews.take(4)) {
        final snapshot = byId[preview.postId];
        if (snapshot == null) continue;
        try {
          final post = decodeFeedPost(snapshot, dataCodec: codec);
          if (post.origin.booruType != BooruType.unknown &&
              (post.origin.booruType != owner.auth.booruType ||
                  normalizePostSourceHost(owner.url) !=
                      post.origin.sourceHost)) {
            continue;
          }
          final media = resolver.resolve(post, settings: settings);
          final urls = <String>{
            media.url,
            ?media.placeholderUrl,
            ?media.fallbackUrl,
          }..removeWhere((url) => url.isEmpty);
          candidates.add([
            for (final url in urls)
              ref.watch(defaultCachedImageFileProvider(url).future),
          ]);
        } on FormatException {
          // One invalid snapshot must not hide the rest of the member's previews.
        }
      }
      var disposed = false;
      ref.onDispose(() => disposed = true);
      final images = <ImageProvider>[];
      for (final variants in candidates) {
        for (final bytesFuture in variants) {
          try {
            final bytes = await bytesFuture;
            if (disposed) return const [];
            if (bytes == null || bytes.isEmpty) continue;
            final image = _cachedImage(bytes);
            if (await _decodeCachedImage(image, ref)) {
              images.add(image);
              break;
            }
          } on Object {
            // Optional cache lookup/decode failures never trigger transport.
          }
        }
      }
      return List.unmodifiable(images);
    });

ImageProvider _cachedImage(Uint8List bytes) {
  if (_hasAvifBrand(bytes)) return AvifMemoryImage(bytes);
  return MemoryImage(bytes);
}

bool _hasAvifBrand(Uint8List bytes) {
  if (bytes.length < 12 ||
      String.fromCharCodes(bytes.sublist(4, 8)) != 'ftyp') {
    return false;
  }
  final length = ByteData.sublistView(bytes).getUint32(0);
  final limit = length < bytes.length ? length : bytes.length;
  for (var offset = 8; offset + 4 <= limit; offset += 4) {
    if (offset == 12) continue; // The minor version is not a compatible brand.
    final brand = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    if (brand == 'avif' || brand == 'avis') return true;
  }
  return false;
}

Future<bool> _decodeCachedImage(ImageProvider image, Ref ref) {
  final result = Completer<bool>();
  final stream = image.resolve(ImageConfiguration.empty);
  late ImageStreamListener listener;
  void finish(bool decoded) {
    if (result.isCompleted) return;
    stream.removeListener(listener);
    result.complete(decoded);
  }

  listener = ImageStreamListener((info, _) {
    info.dispose();
    finish(true);
  }, onError: (_, _) => finish(false));
  ref.onDispose(() => finish(false));
  stream.addListener(listener);
  return result.future;
}
