import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/errors/error.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:boorusama/core/local_media/local_media_enrichment.dart';
import 'package:boorusama/core/local_media/local_media_library.dart';
import 'package:boorusama/core/local_media/local_media_models.dart';
import 'package:boorusama/core/local_media/local_media_reference.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/iqdb_lookup.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/lookup_preferences.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/providers.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/tags/categories/types.dart';
import 'package:boorusama/core/tags/tag/providers.dart';
import 'package:boorusama/core/tags/tag/types.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:sqlite3/sqlite3.dart';

import '../../support/fakes/memory_repositories.dart' show MemoryMiscDataStore;

void main() {
  final bytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3]);
  final reference = LocalMediaReference.parse(sha256.convert(bytes).toString());
  final hash = md5.convert(bytes).toString();
  final first = BooruConfig.defaultConfig(
    booruType: BooruType.danbooru,
    url: 'https://danbooru.donmai.us',
    customDownloadFileNameFormat: null,
  );
  final second = BooruConfig.defaultConfig(
    booruType: BooruType.gelbooru,
    url: 'https://gelbooru.com',
    customDownloadFileNameFormat: null,
  );
  late Directory directory;
  late LocalMediaLibrary library;
  late MemoryMiscDataStore preferences;

  Future<LocalMediaImportResult> import({
    void Function(LocalMediaItem)? after,
  }) => library.import(
    Stream.value(bytes),
    inspect: (_, _) async => (width: 1, height: 1, durationMs: null),
    cancellation: LocalMediaCancellation(),
    budget: LocalMediaImportBudget(),
    onImported: after,
  );

  Post remote(
    BooruConfig profile,
    int id,
    Rating rating,
    List<LocalMediaTag> tags, {
    String? source = 'https://example.com/source',
  }) =>
      localMediaPost(
        reference,
        id: id,
        md5: hash,
        rating: rating,
        tags: tags,
        source: source,
      ).copyWith(
        origin: postOriginFromConfig(profile),
        booruData: const EmptyPostData(typeKey: 'exact-test'),
      );

  PostLookupPage matchPage(
    BooruConfig profile,
    int number,
    List<Post> posts, {
    bool more = false,
    bool filtered = false,
  }) => PostLookupPage(
    targetOrigin: postOriginFromConfig(profile),
    posts: posts,
    page: number,
    hasMore: more,
    hasFilteredMatches: filtered,
  );

  ProviderContainer setup(
    LocalFileHashLookup lookup, {
    List<BooruConfig>? profiles,
    Set<String> blacklist = const {},
    TagExtractor? Function(BooruConfigAuth)? extract,
    IqdbSearch? iqdb,
  }) {
    final container = ProviderContainer(
      overrides: [
        miscDataStoreProvider.overrideWithValue(preferences),
        booruConfigProvider.overrideWith(
          () => _Profiles(profiles ?? [first, second]),
        ),
        localFileHashLookupProvider.overrideWithValue(lookup),
        if (iqdb != null) iqdbSearchProvider.overrideWithValue(iqdb),
        blacklistTagsProvider.overrideWith((_, _) => blacklist),
        tagExtractorProvider.overrideWith((_, auth) => extract?.call(auth)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() async {
    preferences = MemoryMiscDataStore();
    directory = await Directory.systemTemp.createTemp('local-media-enrichment');
    library = await LocalMediaLibrary.open(directory);
  });

  tearDown(() async {
    await library.close();
    await directory.delete(recursive: true);
  });

  for (final (type, url) in [
    (BooruType.gelbooru, 'https://gelbooru.com'),
    (BooruType.gelbooruV2, 'https://rule34.xxx'),
    (BooruType.gelbooruV2, 'https://safebooru.org'),
  ]) {
    test('enrichment uses the matched taxonomy from $url', () async {
      final profile = BooruConfig.defaultConfig(
        booruType: type,
        url: url,
        customDownloadFileNameFormat: null,
      );
      await import();
      await library.edit(
        reference,
        tags: [(name: 'existing', category: 'general')],
        rating: Rating.unknown,
      );
      final container = setup(
        (target, _, {required page, required cancellation}) async =>
            matchPage(target, page, [
              remote(target, 1, Rating.general, [
                (name: 'new_character', category: 'general'),
                (name: 'existing', category: 'general'),
                (name: 'unresolved', category: 'general'),
              ]),
            ]),
        profiles: [profile],
        extract: (auth) {
          expect(auth, profile.auth);
          return TagExtractorBuilder(
            siteHost: url,
            tagCache: null,
            fetcher: (_, _) => [
              Tag.noCount(
                name: 'new_character',
                category: TagCategory.character(),
              ),
              Tag.noCount(name: 'existing', category: TagCategory.copyright()),
              Tag.noCount(name: 'remote_only', category: TagCategory.meta()),
            ],
          );
        },
      );
      final service = container.read(localMediaEnrichmentServiceProvider);
      await service.enrich(
        library,
        library.find(reference)!,
        profiles: [profile],
        cancelled: () => false,
      );
      expect(library.find(reference)!.tags, [
        (name: 'existing', category: 'general'),
        (name: 'new_character', category: 'character'),
        (name: 'unresolved', category: 'unknown'),
      ]);
    });
  }

  test(
    'manual lookup unions all pages and profiles and picks strictest rating',
    () async {
      await import();
      final requests = <(String, int)>[];
      final container = setup((
        profile,
        md5, {
        required page,
        required cancellation,
      }) async {
        expect(md5, hash);
        requests.add((profile.id, page));
        return switch ((profile == first, page)) {
          (true, 1) => matchPage(first, 1, [
            remote(first, 1, Rating.general, [
              (name: 'conflict', category: 'artist'),
              (name: 'one', category: 'artist'),
            ]),
          ], more: true),
          (true, 2) => matchPage(first, 2, [
            remote(first, 2, Rating.explicit, [
              (name: 'two', category: 'character'),
            ]),
          ]),
          _ => matchPage(second, 1, [
            remote(second, 1, Rating.questionable, [
              (name: 'conflict', category: 'character'),
              (name: 'three', category: 'general'),
            ]),
          ]),
        };
      });
      final service = container.read(localMediaEnrichmentServiceProvider);
      final item = library.find(reference)!;
      final result = await service.enrich(
        library,
        item,
        profiles: service.targets,
        cancelled: () => false,
      );
      expect(result.result, LocalMediaEnrichmentResult.updated);
      expect(result.issue, isNull);
      expect(result.review, isNull);
      expect(
        requests,
        unorderedEquals([(first.id, 1), (first.id, 2), (second.id, 1)]),
      );
      final actual = library.find(reference)!;
      expect(actual.id, item.id);
      expect(actual.rating, Rating.explicit);
      expect(actual.source, 'https://example.com/source');
      expect(actual.tags, [
        (name: 'conflict', category: 'general'),
        (name: 'one', category: 'artist'),
        (name: 'three', category: 'unknown'),
        (name: 'two', category: 'character'),
      ]);
      await library.close();
      library = await LocalMediaLibrary.open(directory);
      expect(library.exactMatches(item.id), hasLength(3));
      expect(await (await library.resolve(reference))!.readAsBytes(), bytes);
    },
  );

  test('a 40-file Rule34 batch uses the shared bulk pacing', () async {
    final rule34 = BooruConfig.defaultConfig(
      booruType: BooruType.gelbooruV2,
      url: 'https://rule34.xxx',
      customDownloadFileNameFormat: null,
    );
    final key = ApiQuotaKey.fromUri(Uri.parse('https://api.rule34.xxx'));
    var elapsed = Duration.zero;
    final coordinator = ApiRequestCoordinator(elapsed: () => elapsed);
    addTearDown(coordinator.dispose);
    final starts = <Duration>[];
    final container = setup(
      (profile, _, {required page, required cancellation}) async {
        final admission = coordinator.acquire(
          key,
          context: ApiRequestContext.current(),
        );
        if (coordinator.snapshot(key).waiting[ApiWaitReason.bulkPacing] !=
            null) {
          elapsed += const Duration(seconds: 2);
          coordinator.refreshAdmissions();
        }
        final permit = await admission;
        starts.add(elapsed);
        permit.release();
        // Simulate a server that rejects a burst after 25 starts in one window.
        if (starts.where((start) => start == elapsed).length > 25) {
          return PostLookupFailed(
            ServerError(httpStatusCode: 429, message: 'fixture'),
          );
        }
        return matchPage(profile, page, []);
      },
      profiles: [rule34],
    );
    for (var index = 0; index < 40; index++) {
      await library.import(
        Stream.value(Uint8List.fromList([...bytes, index])),
        inspect: (_, _) async => (width: 1, height: 1, durationMs: null),
        cancellation: LocalMediaCancellation(),
        budget: LocalMediaImportBudget(),
      );
    }
    final service = container.read(localMediaEnrichmentServiceProvider);
    final results = [
      for (final item in library.list())
        await service.enrich(
          library,
          item,
          profiles: [rule34],
          cancelled: () => false,
          batch: true,
        ),
    ];
    expect(results.where((result) => result.incomplete), isEmpty);
    expect(
      results.map((result) => result.issue),
      everyElement(LocalMediaEnrichmentIssue.noMatch),
    );
    expect(starts, [
      for (var index = 0; index < 40; index++) Duration(seconds: index * 2),
    ]);
  });

  test(
    'exact lookup keeps rate limits, HTTP errors and filtered matches distinct',
    () async {
      await import();
      final retryAt = DateTime.utc(2026, 11, 26, 12);
      PostLookupResult response = PostLookupFailed(RateLimitedError(retryAt));
      final container = setup(
        (_, _, {required page, required cancellation}) async => response,
        profiles: [first],
      );
      final service = container.read(localMediaEnrichmentServiceProvider);
      Future<LocalMediaEnrichmentOutcome> run() => service.enrich(
        library,
        library.find(reference)!,
        profiles: [first],
        cancelled: () => false,
      );
      final rateLimited = await run();
      expect(rateLimited.issue, LocalMediaEnrichmentIssue.incompleteLookup);
      expect(rateLimited.lookupDetails.single.failure, (
        kind: LocalMediaLookupFailureKind.rateLimited,
        httpStatus: null,
        retryAt: retryAt,
      ));
      response = PostLookupFailed(
        ServerError(httpStatusCode: 401, message: 'fixture'),
      );
      final denied = await run();
      expect(
        denied.lookupDetails.single.failure?.kind,
        LocalMediaLookupFailureKind.http,
      );
      expect(denied.lookupDetails.single.failure?.httpStatus, 401);
      response = matchPage(first, 1, [], filtered: true);
      final filtered = await run();
      expect(filtered.issue, LocalMediaEnrichmentIssue.filteredMatches);
      expect(
        filtered.lookupDetails.single.failure?.kind,
        LocalMediaLookupFailureKind.filtered,
      );
      expect(library.exactMatches(library.find(reference)!.id), isEmpty);
    },
  );

  test('automatic opt-in persists and schedules only a new import', () async {
    final results = Completer<void>();
    var hits = 0;
    final container = setup((
      profile,
      _, {
      required page,
      required cancellation,
    }) async {
      expect(
        ApiRequestContext.current().requestClass,
        ApiRequestClass.automaticBulk,
      );
      hits++;
      return matchPage(profile, page, [
        remote(
          profile,
          1,
          profile == first ? Rating.general : Rating.questionable,
          [
            (name: 'shared', category: 'general'),
          ],
        ),
      ]);
    });
    final service = container.read(localMediaEnrichmentServiceProvider);
    expect(
      service.automaticImporter(library, LocalMediaCancellation()),
      isNull,
    );
    expect(hits, 0);
    await container
        .read(localMediaOnlineConsentProvider.notifier)
        .setEnabled(true);
    final anotherContainer = ProviderContainer(
      overrides: [miscDataStoreProvider.overrideWithValue(preferences)],
    );
    addTearDown(anotherContainer.dispose);
    expect(anotherContainer.read(localMediaOnlineConsentProvider), isTrue);
    final subscription = library.changes.listen((_) {
      if (!results.isCompleted &&
          library.find(reference)?.rating == Rating.questionable) {
        results.complete();
      }
    });
    addTearDown(subscription.cancel);
    final after = service.automaticImporter(library, LocalMediaCancellation())!;
    expect(await import(after: after), LocalMediaImportResult.imported);
    await results.future.timeout(const Duration(seconds: 10));
    expect(await import(after: after), LocalMediaImportResult.duplicate);
    await (await library.resolve(reference))!.delete();
    expect(await import(after: after), LocalMediaImportResult.repaired);
    expect(hits, 2);
    expect(library.find(reference)!.tags.single.name, 'shared');
  });

  test(
    'manual partial results apply visible tags and preserve local fields',
    () async {
      await import();
      await library.edit(
        reference,
        tags: [(name: 'new', category: 'artist')],
        rating: Rating.general,
      );
      final container = setup((
        profile,
        _, {
        required page,
        required cancellation,
      }) async {
        if (profile == second) return const PostLookupInvalidResponse();
        return matchPage(profile, page, [
          remote(profile, 1, Rating.explicit, [
            (name: 'new', category: 'general'),
            (name: 'added', category: 'general'),
          ]),
          remote(profile, 2, Rating.explicit, [
            (name: 'blocked', category: 'general'),
          ]),
        ]);
      }, blacklist: {'blocked'});
      final service = container.read(localMediaEnrichmentServiceProvider);
      final result = await service.enrich(
        library,
        library.find(reference)!,
        profiles: service.targets,
        cancelled: () => false,
      );
      expect(result.incomplete, isTrue);
      final item = library.find(reference)!;
      expect(item.rating, Rating.general);
      expect(item.tags, [
        (name: 'added', category: 'unknown'),
        (name: 'new', category: 'artist'),
      ]);
      expect(library.exactMatches(item.id).map((match) => match.postId), ['1']);
    },
  );

  test(
    'cancelled and removed targets cannot write; concurrent local edit wins',
    () async {
      await import();
      for (final change in ['cancel', 'remove', 'edit']) {
        final started = Completer<void>();
        final response = Completer<PostLookupResult>();
        var cancelled = false;
        final container = setup((_, _, {required page, required cancellation}) {
          started.complete();
          return response.future;
        }, profiles: [first]);
        final service = container.read(localMediaEnrichmentServiceProvider);
        final run = service.enrich(
          library,
          library.find(reference)!,
          profiles: [first],
          cancelled: () => cancelled,
        );
        await started.future.timeout(const Duration(seconds: 10));
        switch (change) {
          case 'cancel':
            cancelled = true;
          case 'remove':
            final profiles =
                container.read(booruConfigProvider.notifier) as _Profiles;
            profiles.replace([]);
            profiles.replace([first]);
          case 'edit':
            await library.edit(reference, tags: [], rating: Rating.unknown);
        }
        response.complete(
          matchPage(first, 1, [
            remote(first, 1, Rating.explicit, [
              (name: 'remote', category: 'general'),
            ]),
          ]),
        );
        await run;
        expect(library.find(reference)!.tags, isEmpty);
        expect(library.find(reference)!.rating, Rating.unknown);
        expect(
          library.exactMatches(library.find(reference)!.id),
          hasLength(change == 'edit' ? 1 : 0),
        );
      }
    },
  );

  test(
    'IQDB follows completed empty MD5 and stores only similar provenance',
    () async {
      final authenticated = first.copyWith(
        login: 'fixture-user',
        apiKey: 'fixture-key',
      );
      final selection = [
        (
          profile: authenticated,
          methods: const {
            PostLookupMatchKind.exactFile,
            PostLookupMatchKind.similarImage,
          },
        ),
      ];
      var exact = 'incomplete';
      var calls = 0;
      final container = setup(
        (profile, _, {required page, required cancellation}) async =>
            switch (exact) {
              'incomplete' => const PostLookupInvalidResponse(),
              'filtered' => matchPage(profile, page, [], filtered: true),
              _ => matchPage(profile, page, []),
            },
        profiles: [authenticated],
        iqdb: (target, signature, permission, stopped) async {
          expect(signature, matches(RegExp(r'^iqdb_[0-9a-f]{528}$')));
          expect(permission, IqdbPermission.persistent);
          expect(stopped(), isFalse);
          calls++;
          return [
            (
              profile: authenticated,
              postId: '42',
              score: 89.99,
              post: remote(authenticated, 42, Rating.questionable, [
                (name: 'similar_tag', category: 'general'),
              ]),
            ),
          ];
        },
      );
      await container.read(lookupPreferencesProvider.notifier).setIqdb(true);
      final png = image.encodePng(image.Image(width: 4, height: 5));
      final ref = LocalMediaReference.parse(sha256.convert(png).toString());
      await library.import(
        Stream.value(png),
        inspect: (_, _) async => (width: 4, height: 5, durationMs: null),
        cancellation: LocalMediaCancellation(),
        budget: LocalMediaImportBudget(),
      );
      final service = container.read(localMediaEnrichmentServiceProvider);
      final item = library.find(ref)!;
      Future<LocalMediaEnrichmentOutcome> run() => service.enrich(
        library,
        item,
        profiles: [authenticated],
        selection: selection,
        cancelled: () => false,
        iqdbPermission: IqdbPermission.persistent,
      );
      final incomplete = await run();
      expect(incomplete.incomplete, isTrue);
      expect(incomplete.lookupDetails, {
        (
          profile: authenticated,
          method: PostLookupMatchKind.exactFile,
          failure: (
            kind: LocalMediaLookupFailureKind.invalidResponse,
            httpStatus: null,
            retryAt: null,
          ),
        ),
      });
      exact = 'filtered';
      expect((await run()).incomplete, isTrue);
      expect(calls, 0);
      exact = 'empty';
      final review = (await run()).review!;
      expect(library.similarMatches(item.id), isEmpty);
      final candidate = review.candidates.single;
      final settings = container.read(lookupPreferencesProvider.notifier);
      await settings.setIqdb(false);
      expect(
        await service
            .applyReview(
              library,
              review,
              candidate,
              current: () => true,
            )
            .then((outcome) => outcome.issue),
        LocalMediaEnrichmentIssue.matchUnavailable,
      );
      expect(library.similarMatches(item.id), isEmpty);
      await settings.setIqdb(true);
      expect(
        await service
            .applyReview(
              library,
              review,
              candidate,
              current: () => true,
            )
            .then((outcome) => outcome.result),
        LocalMediaEnrichmentResult.updated,
      );
      expect(library.exactMatches(item.id), isEmpty);
      expect(library.similarMatches(item.id).single.score, 89.99);
      expect(library.find(ref)!.rating, Rating.questionable);
      expect(library.find(ref)!.tags.single.name, 'similar_tag');
      await library.edit(
        ref,
        tags: [(name: 'manual', category: 'general')],
        rating: Rating.general,
      );
      expect(
        await service
            .applyReview(
              library,
              review,
              candidate,
              current: () => true,
            )
            .then((outcome) => outcome.issue),
        LocalMediaEnrichmentIssue.imageChanged,
      );
      expect(library.find(ref)!.tags.single.name, 'manual');
      expect(calls, 1);
    },
  );

  test('manual enrichment matches MP4 and WebM by the stored MD5', () async {
    final requests = <String>[];
    var iqdbCalls = 0;
    final authenticated = first.copyWith(
      login: 'fixture-user',
      apiKey: 'fixture-key',
    );
    final container = setup(
      (profile, md5, {required page, required cancellation}) async {
        requests.add(md5);
        final matched = library.list().singleWhere((item) => item.md5 == md5);
        return matchPage(profile, page, [
          localMediaPost(
            matched.reference,
            id: matched.id,
            md5: md5,
            format: '.${matched.format.extension}',
            tags: const [(name: 'video_tag', category: 'general')],
            rating: Rating.general,
          ).copyWith(
            origin: postOriginFromConfig(profile),
            booruData: const EmptyPostData(typeKey: 'exact-test'),
          ),
        ]);
      },
      profiles: [authenticated],
      iqdb: (_, _, _, _) async {
        iqdbCalls++;
        return const [];
      },
    );
    await container.read(lookupPreferencesProvider.notifier).setIqdb(true);
    final service = container.read(localMediaEnrichmentServiceProvider);
    for (final data in [
      [0, 0, 0, 20, ...'ftyp'.codeUnits, 0],
      [0x1a, 0x45, 0xdf, 0xa3, 0],
    ]) {
      final video = Uint8List.fromList(data);
      final ref = LocalMediaReference.parse(sha256.convert(video).toString());
      await library.import(
        Stream.value(video),
        inspect: (_, _) async => (width: 2, height: 2, durationMs: 100),
        cancellation: LocalMediaCancellation(),
        budget: LocalMediaImportBudget(),
      );
      final item = library.find(ref)!;
      expect(item.format.isVideo, isTrue);
      final outcome = await service.enrich(
        library,
        item,
        profiles: [authenticated],
        selection: [
          (
            profile: authenticated,
            methods: const {
              PostLookupMatchKind.exactFile,
              PostLookupMatchKind.similarImage,
            },
          ),
        ],
        cancelled: () => false,
        iqdbPermission: IqdbPermission.persistent,
      );
      expect(outcome.issue, isNull);
      expect(outcome.result, LocalMediaEnrichmentResult.updated);
      expect(library.find(ref)!.tags.single.name, 'video_tag');
      expect(library.exactMatches(item.id).single.postId, item.id.toString());
      expect(requests.last, md5.convert(video).toString());
      expect(
        (await service.enrich(
          library,
          library.find(ref)!,
          profiles: [authenticated],
          selection: [
            (
              profile: authenticated,
              methods: const {PostLookupMatchKind.similarImage},
            ),
          ],
          cancelled: () => false,
          iqdbPermission: IqdbPermission.persistent,
        )).issue,
        LocalMediaEnrichmentIssue.noApplicableMethod,
      );
    }
    expect(requests, hasLength(2));
    expect(iqdbCalls, 0);
  });

  test('empty exact lookup differs from a verified unchanged match', () async {
    await import();
    var found = false;
    final container = setup(
      (profile, _, {required page, required cancellation}) async =>
          matchPage(profile, page, [
            if (found) remote(profile, 1, Rating.unknown, [], source: null),
          ]),
    );
    final service = container.read(localMediaEnrichmentServiceProvider);
    Future<LocalMediaEnrichmentOutcome> run() => service.enrich(
      library,
      library.find(reference)!,
      profiles: service.targets,
      cancelled: () => false,
    );
    final miss = await run();
    expect(miss.issue, LocalMediaEnrichmentIssue.noMatch);
    expect(miss.lookupDetails, {
      (profile: first, method: PostLookupMatchKind.exactFile, failure: null),
      (profile: second, method: PostLookupMatchKind.exactFile, failure: null),
    });
    expect(miss.review, isNull);
    found = true;
    final unchanged = await run();
    expect(unchanged.result, LocalMediaEnrichmentResult.unchanged);
    expect(unchanged.issue, isNull);
    expect(unchanged.review, isNull);
  });

  for (final automatic in [false, true]) {
    test(
      'only a unique eligible IQDB winner is applied (automatic: $automatic)',
      () async {
        final profile = first.copyWith(
          login: 'fixture-user',
          apiKey: 'fixture-key',
        );
        final other = BooruConfig.fromJson({
          ...profile.toJson(),
          'id': '00000000-0000-4000-8000-000000000002',
          'url': 'https://safebooru.donmai.us',
        });
        final selection = [
          (
            profile: profile,
            methods: const {
              PostLookupMatchKind.exactFile,
              PostLookupMatchKind.similarImage,
            },
          ),
          (profile: other, methods: const {PostLookupMatchKind.similarImage}),
        ];
        final exact = remote(profile, 10, Rating.general, [
          (name: 'exact', category: 'general'),
        ]);
        var hasExact = false;
        var searches = 0;
        var incomplete = true;
        final retryAt = DateTime.utc(2026, 11, 26);
        var competitorScore = 94.0;
        var competitorVisible = true;
        final container = setup(
          (target, _, {required page, required cancellation}) async =>
              matchPage(target, page, [if (hasExact) exact]),
          profiles: [profile, other],
          iqdb: (target, _, _, _) async {
            expect(
              ApiRequestContext.current().requestClass,
              automatic
                  ? ApiRequestClass.automaticBulk
                  : ApiRequestClass.bulkTransfer,
            );
            if (target.profile == other) {
              if (incomplete) {
                throw ApiCooldownException(
                  ApiQuotaKey.fromUri(Uri.parse(other.url)),
                  retryAt,
                );
              }
              return const [];
            }
            searches++;
            return [
              for (final (id, score) in [(94, competitorScore), (96, 96.0)])
                (
                  profile: profile,
                  postId: '$id',
                  score: score,
                  post: id != 94 || competitorVisible
                      ? remote(profile, id, Rating.general, [
                          (name: 'candidate_$id', category: 'general'),
                        ])
                      : null,
                ),
            ];
          },
        );
        await container.read(lookupPreferencesProvider.notifier).setIqdb(true);
        final png = image.encodePng(image.Image(width: 2, height: 2));
        final ref = LocalMediaReference.parse(sha256.convert(png).toString());
        await library.import(
          Stream.value(png),
          inspect: (_, _) async => (width: 2, height: 2, durationMs: null),
          cancellation: LocalMediaCancellation(),
          budget: LocalMediaImportBudget(),
        );
        final service = container.read(localMediaEnrichmentServiceProvider);
        Future<LocalMediaEnrichmentOutcome> run() => service.enrich(
          library,
          library.find(ref)!,
          profiles: [profile, other],
          selection: selection,
          automatic: automatic,
          batch: !automatic,
          cancelled: () => false,
          iqdbPermission: IqdbPermission.persistent,
        );
        hasExact = true;
        expect((await run()).issue, isNull);
        expect(searches, 0);
        expect(library.exactMatches(library.find(ref)!.id).single.postId, '10');
        hasExact = false;
        final incompleteResult = await run();
        expect(
          incompleteResult.issue,
          LocalMediaEnrichmentIssue.incompleteLookup,
        );
        expect(incompleteResult.lookupDetails, {
          (
            profile: other,
            method: PostLookupMatchKind.similarImage,
            failure: (
              kind: LocalMediaLookupFailureKind.rateLimited,
              httpStatus: null,
              retryAt: retryAt,
            ),
          ),
        });
        expect(incompleteResult.review == null, automatic);
        final item = library.find(ref)!;
        expect(library.similarMatches(item.id), isEmpty);
        incomplete = false;
        competitorScore = 96.0;
        expect((await run()).review == null, automatic);
        expect(library.similarMatches(item.id), isEmpty);
        competitorScore = 97.0;
        competitorVisible = false;
        expect((await run()).review == null, automatic);
        expect(library.similarMatches(item.id), isEmpty);
        competitorScore = 94.0;
        competitorVisible = true;
        final accepted = await run();
        expect(accepted.issue, isNull);
        expect(accepted.review, isNull);
        expect(
          library.similarMatches(library.find(ref)!.id).single.score,
          96.0,
        );
        expect(searches, 4);
      },
    );
  }

  test(
    'conflicting sources remain empty and automatic tags require agreement',
    () {
      final results = [
        remote(first, 1, Rating.sensitive, [
          (name: 'one', category: 'general'),
        ]),
        remote(
          second,
          2,
          Rating.questionable,
          [(name: 'two', category: 'general')],
          source: 'https://example.org/other',
        ),
      ];
      final manual = metadataFromMatches(
        results,
        automatic: false,
        applyMetadata: true,
      );
      final automatic = metadataFromMatches(
        results,
        automatic: true,
        applyMetadata: true,
      );
      expect(manual.source, isNull);
      expect(
        manual.tags.map((tag) => tag.name),
        unorderedEquals(['one', 'two']),
      );
      expect(automatic.source, isNull);
      expect(automatic.tags, isEmpty);
      expect(automatic.rating, Rating.questionable);
    },
  );

  test(
    'opening the original v1 shape preserves managed media and metadata',
    () async {
      await import();
      await library.edit(
        reference,
        tags: [(name: 'local', category: 'general')],
        rating: Rating.sensitive,
      );
      final original = library.find(reference)!;
      await library.close();
      final db = sqlite3.open('${directory.path}/library.db');
      db.execute('DROP TABLE media_exact_match');
      db.execute('ALTER TABLE media DROP COLUMN metadata_revision');
      db.close();
      library = await LocalMediaLibrary.open(directory);
      final reopened = library.find(reference)!;
      expect(reopened.id, original.id);
      expect(reopened.reference, original.reference);
      expect(reopened.tags, original.tags);
      expect(reopened.rating, original.rating);
      expect(reopened.md5, original.md5);
      expect(await (await library.resolve(reference))!.readAsBytes(), bytes);
    },
  );
}

final class _Profiles extends BooruConfigNotifier {
  _Profiles(List<BooruConfig> profiles) : super(initialConfigs: profiles);

  void replace(List<BooruConfig> configs) => state = configs;
}
