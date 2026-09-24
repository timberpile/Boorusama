// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/posts/post/types.dart';

void main() {
  test('equivalent post payloads reuse one presentation provider', () {
    final container = _container();

    for (var i = 0; i < 500; i++) {
      final presentation = container.read(
        booruPostPresentationProvider(
          PostPresentationRequest(
            origin: PostOrigin.fromSource(
              booruType: BooruType.danbooru,
              booruId: BooruType.danbooru.id,
              source: 'https://danbooru.donmai.us/posts/$i',
              profileIdHint: i,
            ),
            data: LegacyPostData(
              typeKey: 'legacy_danbooru',
              custom: {
                'postId': i,
                'tags': [for (var tag = 0; tag < 20; tag++) 'tag_${i}_$tag'],
              },
            ),
          ),
        ),
      );

      expect(presentation, isA<GenericPostPresentation>());
    }

    expect(_presentationProviderCount(container), 1);
  });

  test('different presentation contracts keep separate provider state', () {
    final container = _container();
    final requests = [
      _request(BooruType.danbooru, 'legacy_a', 1),
      _request(BooruType.danbooru, 'legacy_b', 1),
      _request(BooruType.danbooru, 'legacy_b', 2),
      _request(BooruType.e621, 'legacy_b', 2),
    ];

    for (final request in requests) {
      container.read(booruPostPresentationProvider(request));
    }

    expect(_presentationProviderCount(container), requests.length);
  });
}

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [
      booruEngineRegistryProvider.overrideWithValue(BooruEngineRegistry()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

PostPresentationRequest _request(
  BooruType type,
  String typeKey,
  int schemaVersion,
) => PostPresentationRequest(
  origin: PostOrigin.fromSource(
    booruType: type,
    booruId: type.id,
    source: 'https://${type.name}.example',
  ),
  data: LegacyPostData(
    typeKey: typeKey,
    schemaVersion: schemaVersion,
    custom: const {},
  ),
);

int _presentationProviderCount(ProviderContainer container) => container
    .getAllProviderElements()
    .where(
      (element) => element.provider.name == 'booruPostPresentationProvider',
    )
    .length;
