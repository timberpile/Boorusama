import 'package:booru_clients/nozomi.dart' as nozomi;
import 'package:booru_clients/szurubooru.dart' as szuru;
import 'package:boorusama/boorus/nozomi/client_provider.dart';
import 'package:boorusama/boorus/nozomi/posts/providers.dart';
import 'package:boorusama/boorus/szurubooru/client_provider.dart';
import 'package:boorusama/boorus/szurubooru/posts/providers.dart';
import 'package:boorusama/boorus/szurubooru/tags/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final isNozomi in [true, false]) {
    for (final data in [
      (total: 25, page: 1, limit: 10, more: true),
      (total: 25, page: 3, limit: 10, more: false),
      (total: 0, page: 1, limit: 10, more: false),
      (total: null, page: 1, limit: 10, more: null),
      (total: 150, page: 1, limit: 200, more: isNozomi),
    ]) {
      test(
        'source stride controls continuation despite missing posts ($isNozomi, $data)',
        () async {
          final nozomiClient = _Nozomi(data.total);
          final szuruClient = _Szuru(data.total);
          final container = ProviderContainer(
            overrides: [
              nozomiClientProvider.overrideWith((ref, auth) => nozomiClient),
              szurubooruClientProvider.overrideWith((ref, auth) => szuruClient),
              szurubooruTagCategoriesProvider.overrideWith(
                (ref, auth) => [],
              ),
            ],
          );
          addTearDown(container.dispose);
          final config = BooruConfig.empty.search;
          final repository = isNozomi
              ? container.read(nozomiPostRepoProvider(config))
              : container.read(szurubooruPostRepoProvider(config));
          final result = await repository
              .getPosts(
                '',
                data.page,
                limit: data.limit,
                options: PostFetchOptions.raw,
              )
              .run();
          result.fold((error) => fail('Unexpected source error: $error'), (
            value,
          ) {
            expect(value.posts, isEmpty);
            expect(value.total, data.total);
            expect(value.hasMore, data.more);
          });
          expect(isNozomi ? nozomiClient.page : szuruClient.page, data.page);
          expect(
            isNozomi ? nozomiClient.limit : szuruClient.limit,
            isNozomi ? data.limit.clamp(1, 100) : data.limit,
          );
        },
      );
    }
  }
}

class _Nozomi extends nozomi.NozomiClient {
  _Nozomi(this.total);
  final int? total;
  int? page;
  int? limit;

  @override
  Future<({List<nozomi.NozomiPostDto> posts, int? total})> getPostsWithTotal({
    List<String>? tags,
    int page = 1,
    int? limit,
    nozomi.NozomiPostOrder order = nozomi.NozomiPostOrder.date,
  }) async {
    this.page = page;
    this.limit = limit;
    return (posts: <nozomi.NozomiPostDto>[], total: total);
  }
}

class _Szuru extends szuru.SzurubooruClient {
  _Szuru(this.total) : super(baseUrl: 'https://example.invalid');
  final int? total;
  int? page;
  int? limit;

  @override
  Future<({List<szuru.PostDto> posts, int? total})> getPosts({
    int? page,
    int? limit,
    List<String>? tags,
  }) async {
    this.page = page;
    this.limit = limit;
    return (posts: <szuru.PostDto>[], total: total);
  }
}
