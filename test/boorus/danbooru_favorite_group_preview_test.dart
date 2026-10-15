// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/boorus/danbooru/favgroups/listing/src/providers/post_previews_notifier.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';

void main() {
  final config = BooruConfig.defaultConfig(
    booruType: BooruType.danbooru,
    url: 'https://danbooru.example',
    customDownloadFileNameFormat: null,
  ).search;

  for (final postId in <int?>[null, 42]) {
    test('returns an empty preview before caching for post $postId', () {
      final container = ProviderContainer(
        overrides: [
          currentReadOnlyBooruConfigSearchProvider.overrideWithValue(config),
        ],
      );
      addTearDown(container.dispose);

      // Keep both providers real so missing dependency declarations surface.
      expect(
        container.read(danbooruFavoriteGroupPreviewProvider(postId)),
        isEmpty,
      );
    });
  }

  test('reads cached thumbnails and follows preview cache updates', () {
    final previewsProvider = danbooruFavoriteGroupPreviewsProvider(config);
    final container = ProviderContainer(
      overrides: [
        currentReadOnlyBooruConfigSearchProvider.overrideWithValue(config),
        danbooruFavoriteGroupPreviewsProvider.overrideWith(
          _TestFavoriteGroupPreviewsNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    final previewProvider = danbooruFavoriteGroupPreviewProvider(42);
    final subscription = container.listen(previewProvider, (previous, next) {});
    addTearDown(subscription.close);

    expect(container.read(previewProvider), 'https://images.example/first.jpg');

    final notifier =
        container.read(previewsProvider.notifier)
            as _TestFavoriteGroupPreviewsNotifier;
    notifier.replacePreviews({42: 'https://images.example/updated.jpg'});

    expect(
      container.read(previewProvider),
      'https://images.example/updated.jpg',
    );
  });
}

class _TestFavoriteGroupPreviewsNotifier extends FavoriteGroupPreviewsNotifier {
  @override
  Map<int, String> build(BooruConfigSearch arg) => {
    42: 'https://images.example/first.jpg',
  };

  void replacePreviews(Map<int, String> previews) {
    state = previews;
  }
}
