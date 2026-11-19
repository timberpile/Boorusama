import 'dart:async';

import 'package:boorusama/boorus/danbooru/pools/pool/providers.dart';
import 'package:boorusama/boorus/danbooru/pools/pool/types.dart';
import 'package:boorusama/boorus/danbooru/pools/pool/src/widgets/pool_page_sliver_grid.dart';
import 'package:boorusama/boorus/danbooru/posts/post/providers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/widgets.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/search/queries/types.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../support/fakes/test_post.dart';

final _config = BooruConfig.defaultConfig(
  booruType: BooruType.danbooru,
  url: 'https://danbooru.donmai.us',
  customDownloadFileNameFormat: null,
);

DanbooruPool _pool(int id, List<int>? ids) => DanbooruPool(
  id: id,
  postIds: ids,
  category: DanbooruPoolCategory.collection,
  description: '',
  postCount: ids?.length,
  name: 'Pool $id',
  createdAt: null,
  updatedAt: null,
);

class _Lookups {
  final calls = <List<String>>[];
  final pending = <Completer<PostResult<Post>>>[];
  final _entered = <int, Completer<void>>{};
  Future<void> waitForCalls(int count) => calls.length >= count
      ? Future.value()
      : (_entered[count] ??= Completer<void>()).future;
  late final repo = PostRepositoryBuilder<Post>(
    fetch: (tags, page, {limit, options}) {
      calls.add(tags);
      final result = Completer<PostResult<Post>>();
      pending.add(result);
      _entered.remove(calls.length)?.complete();
      return result.future;
    },
    fetchSingle: (id, {options}) async => null,
    getSettings: () async => Settings.defaultSettings.listing,
    tagComposer: EmptyTagQueryComposer(),
  );
}

void main() {
  late _Lookups lookups;
  late ProviderContainer container;
  setUp(() {
    lookups = _Lookups();
    container = ProviderContainer(
      overrides: [
        danbooruPostRepoProvider.overrideWith((ref, config) => lookups.repo),
      ],
    );
  });
  tearDown(() => container.dispose());

  Future<void> nextLookup(int count) async {
    await lookups.waitForCalls(count).timeout(const Duration(seconds: 10));
    expect(lookups.calls, hasLength(count));
  }

  test(
    'shared last IDs cover every Pool and identical in-flight loads coalesce',
    () async {
      final notifier = container.read(
        danbooruPoolCoversProvider(_config.search).notifier,
      );
      final pools = [
        _pool(1, [7, 42]),
        _pool(2, [42]),
      ];
      final first = notifier.load(pools);
      final second = notifier.load(pools);
      await nextLookup(1);
      expect(lookups.calls.single, ['id:42']);
      lookups.pending.single.complete([TestPost(id: 42)].toResult());
      await Future.wait([first, second]);
      final covers = container.read(danbooruPoolCoversProvider(_config.search));
      expect(covers.keys, unorderedEquals([1, 2]));
      expect(covers[1], covers[2]);
      await notifier.load(pools);
      expect(lookups.calls, hasLength(1));
    },
  );

  test(
    'failed lookups retain good covers and allow a subsequent listing load',
    () async {
      final provider = danbooruPoolCoversProvider(_config.search);
      final notifier = container.read(provider.notifier);
      final first = notifier.load([
        _pool(1, [10]),
      ]);
      await nextLookup(1);
      lookups.pending[0].complete([TestPost(id: 10)].toResult());
      await first;
      final good = container.read(provider)[1];
      final failed = notifier.load([
        _pool(1, [10]),
        _pool(2, [20]),
      ]);
      await nextLookup(2);
      lookups.pending[1].completeError(StateError('offline'));
      await failed;
      expect(container.read(provider), {1: good});
      final retry = notifier.load([
        _pool(1, [10]),
        _pool(2, [20]),
      ]);
      await nextLookup(3);
      expect(lookups.calls.last, ['id:20']);
      lookups.pending[2].complete([TestPost(id: 20)].toResult());
      await retry;
      expect(container.read(provider)[1], same(good));
      expect(container.read(provider)[2]?.id, 20);
    },
  );

  test(
    'successful missing candidates and empty manifests remain stable',
    () async {
      final provider = danbooruPoolCoversProvider(_config.search);
      final notifier = container.read(provider.notifier);
      final pools = [
        _pool(1, [10]),
        _pool(2, []),
        _pool(3, null),
      ];
      final first = notifier.load(pools);
      await nextLookup(1);
      lookups.pending.single.complete(<Post>[].toResult());
      await first;
      expect(container.read(provider)[1]?.url, isNull);
      expect(container.read(provider).containsKey(1), isTrue);
      await notifier.load(pools);
      await notifier.load(null);
      expect(lookups.calls, hasLength(1));
    },
  );

  test(
    'new last member replaces a cached absence and revokes earlier lookups',
    () async {
      final provider = danbooruPoolCoversProvider(_config.search);
      final notifier = container.read(provider.notifier);
      final first = notifier.load([
        _pool(1, [10]),
        _pool(2, [11]),
      ]);
      await nextLookup(1);
      lookups.pending[0].complete([TestPost(id: 11)].toResult());
      await first;
      final unchanged = container.read(provider)[2];
      expect(container.read(provider)[1]?.url, isNull);

      final older = notifier.load([
        _pool(1, [12]),
      ]);
      await nextLookup(2);
      final newer = notifier.load([
        _pool(1, [13]),
      ]);
      await nextLookup(3);
      lookups.pending[2].complete([TestPost(id: 13)].toResult());
      await newer;
      lookups.pending[1].complete([TestPost(id: 12)].toResult());
      await older;
      expect(container.read(provider)[1]?.id, 13);
      expect(container.read(provider)[2], same(unchanged));
    },
  );

  test('obsolete completion cannot replace a rebuilt cache', () async {
    final provider = danbooruPoolCoversProvider(_config.search);
    final old = container.read(provider.notifier).load([
      _pool(1, [10]),
    ]);
    await nextLookup(1);
    container.invalidate(provider);
    final fresh = container.read(provider.notifier).load([
      _pool(1, [10]),
    ]);
    await nextLookup(2);
    lookups.pending[1].complete([TestPost(id: 10)].toResult());
    await fresh;
    lookups.pending[0].complete(<Post>[].toResult());
    await old;
    expect(container.read(provider)[1]?.id, 10);
  });

  testWidgets(
    'changing listing order retries a failed cover through the real grid',
    (tester) async {
      final poolRepo = _Pools([
        _pool(1, [10]),
      ]);
      final scope = ProviderContainer(
        overrides: [
          settingsProvider.overrideWithValue(Settings.defaultSettings),
          booruConfigProvider.overrideWith(
            () => BooruConfigNotifier(initialConfigs: [_config]),
          ),
          automaticMediaLoadingEnabledProvider.overrideWithValue(false),
          danbooruPostRepoProvider.overrideWith((ref, config) => lookups.repo),
          danbooruPoolRepoProvider.overrideWith((ref, config) => poolRepo),
        ],
      );
      addTearDown(scope.dispose);
      Future<void> pump(DanbooruPoolOrder order) => tester.pumpWidget(
        UncontrolledProviderScope(
          container: scope,
          child: BooruLocalization(
            child: MaterialApp(
              builder: (context, child) => KurumiTheme(
                data: KurumiThemeData.fromMaterial(Theme.of(context)),
                child: child!,
              ),
              home: CurrentBooruConfigScope(
                config: _config,
                child: Scaffold(
                  body: CustomScrollView(
                    slivers: [
                      PoolPagedSliverGrid(
                        constraints: const BoxConstraints(maxWidth: 800),
                        order: order,
                        category: DanbooruPoolCategory.collection,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await pump(DanbooruPoolOrder.latest);
      await tester.pumpAndSettle();
      expect(poolRepo.calls, 1);
      expect(lookups.calls, hasLength(1));
      lookups.pending[0].completeError(StateError('offline'));
      await tester.pumpAndSettle();
      await pump(DanbooruPoolOrder.newest);
      await tester.pumpAndSettle();
      expect(poolRepo.calls, 2);
      expect(lookups.calls, hasLength(2));
      lookups.pending[1].complete([TestPost(id: 10)].toResult());
      await tester.pumpAndSettle();
      expect(scope.read(danbooruPoolCoversProvider(_config.search))[1]?.id, 10);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Pools implements PoolRepository {
  _Pools(this.pools);
  final List<DanbooruPool> pools;
  var calls = 0;
  @override
  Future<List<DanbooruPool>> getPools(
    int page, {
    DanbooruPoolCategory? category,
    DanbooruPoolOrder? order,
    String? name,
    String? description,
  }) async {
    if (page == 1) calls++;
    return page == 1 ? pools : [];
  }

  @override
  Future<List<DanbooruPool>> getPoolsByPostId(int postId) async => pools;
}
