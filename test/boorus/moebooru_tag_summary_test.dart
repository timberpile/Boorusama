import 'package:booru_clients/moebooru.dart';
import 'package:boorusama/boorus/moebooru/tag_summary/repo.dart';
import 'package:boorusama/boorus/moebooru/tag_summary/types.dart';
import 'package:boorusama/boorus/moebooru/tags/providers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/tags/categories/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final auth = BooruConfig.defaultConfig(
    booruType: BooruType.moebooru,
    url: 'https://example.test',
    customDownloadFileNameFormat: null,
  ).auth;

  test(
    'fresh and cached tag maps agree with the searchable summaries',
    () async {
      final records = [
        '1`artist`alias',
        for (var i = 0; i < 12000; i++) '0`tag_$i',
      ];
      final client = _SummaryClient(TagSummaryDto(data: records.join(' ')));
      final store = _SummaryStore();
      final repo = MoebooruTagSummaryRepository(client, store);
      final container = ProviderContainer(
        overrides: [
          moebooruTagSummaryRepoProvider(auth).overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      final provider = moebooruAllTagsProvider(auth);
      final fresh = await container.read(provider.future);
      expect(fresh, hasLength(records.length));
      expect(fresh['artist']?.category, TagCategory.artist());
      expect(fresh['tag_11999']?.category, TagCategory.general());
      expect(fresh.containsKey('alias'), isFalse);
      final summaries = await repo.getTagSummaries();
      expect(summaries.first.otherNames, ['alias']);
      expect(summaries.map((row) => row.name), orderedEquals(fresh.keys));
      expect(await container.refresh(provider.future), equals(fresh));
      expect(client.requests, 1);
    },
  );

  test(
    'empty tag data and malformed tag data produce distinct results',
    () async {
      final store = _SummaryStore()..data = TagSummaryDto(data: '');
      final client = _SummaryClient(TagSummaryDto());
      final container = ProviderContainer(
        overrides: [
          moebooruTagSummaryRepoProvider(auth).overrideWithValue(
            MoebooruTagSummaryRepository(client, store),
          ),
        ],
      );
      addTearDown(container.dispose);
      final provider = moebooruAllTagsProvider(auth);
      expect(await container.read(provider.future), isEmpty);
      for (final malformed in [null, 'missing_fields']) {
        store.data = TagSummaryDto(data: malformed);
        await expectLater(container.refresh(provider.future), throwsException);
      }
      expect(client.requests, 0);
    },
  );
}

class _SummaryStore extends EmptyTagSummaryStore {
  TagSummaryDto? data;

  @override
  Future<TagSummaryDto?> get() => Future.value(data);

  @override
  Future<void> save(TagSummaryDto dto) {
    data = dto;
    return Future.value();
  }
}

class _SummaryClient extends MoebooruClient {
  _SummaryClient(this.data);

  final TagSummaryDto data;
  var requests = 0;

  @override
  Future<TagSummaryDto> getTagSummary() {
    requests++;
    return Future.value(data);
  }
}
