// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/search/histories/providers.dart';
import 'package:boorusama/core/search/histories/src/types/search_history_repository.dart';
import 'package:boorusama/core/search/histories/types.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';

void main() {
  test(
    'stores search history with the profile that launched the search',
    () async {
      final repository = _SearchHistoryRepository();
      final container = ProviderContainer(
        overrides: [
          searchHistoryRepoProvider.overrideWith(
            (ref) => Future.value(repository),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(searchHistoryProvider.future);

      await container
          .read(searchHistoryProvider.notifier)
          .addHistory('tag', _pageConfig.auth);

      expect(repository.siteUrl, 'page.example');
      expect(repository.booruTypeName, BooruType.e621.name);
    },
  );
}

class _SearchHistoryRepository implements SearchHistoryRepository {
  String? siteUrl;
  String? booruTypeName;

  @override
  Future<List<SearchHistory>> addHistory(
    String query, {
    required QueryType queryType,
    required String booruTypeName,
    required String siteUrl,
  }) async {
    this.siteUrl = siteUrl;
    this.booruTypeName = booruTypeName;
    return [
      SearchHistory.now(
        query,
        queryType,
        booruTypeName: booruTypeName,
        siteUrl: siteUrl,
      ),
    ];
  }

  @override
  Future<bool> clearAll() async => true;

  @override
  Future<List<SearchHistory>> getHistories() async => [];

  @override
  Future<List<SearchHistory>> removeHistory(SearchHistory history) async => [];
}

final _pageConfig = BooruConfig.defaultConfig(
  booruType: BooruType.e621,
  url: 'https://page.example',
  customDownloadFileNameFormat: null,
);
