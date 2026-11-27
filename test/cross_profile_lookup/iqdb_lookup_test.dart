import 'dart:convert';
import 'dart:typed_data';

import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/iqdb_lookup.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/iqdb_signature.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/lookup_preferences.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import '../support/fakes/memory_repositories.dart' show MemoryMiscDataStore;
import '../support/fakes/test_post.dart';
import 'providers_test.dart' show Profiles;

void main() {
  final profile = BooruConfig.defaultConfig(
    booruType: BooruType.danbooru,
    url: 'https://danbooru.donmai.us',
    customDownloadFileNameFormat: null,
  ).copyWith(apiKey: 'fixture-key', login: 'fixture-login');
  final official = BooruConfig.fromJson({
    ...profile.toJson(),
    'id': '00000000-0000-4000-8000-000000000001',
  });
  final second = BooruConfig.fromJson({
    ...profile.toJson(),
    'id': '00000000-0000-4000-8000-000000000002',
    'url': 'https://safebooru.donmai.us/',
  });

  final target = (
    profile: official,
    methods: const {PostLookupMatchKind.similarImage},
  );
  final key = ApiQuotaKey.fromUri(Uri.parse(official.url));
  final signature = 'iqdb_${'0' * 528}';
  ProviderContainer createContainer(
    ApiRequestCoordinator coordinator,
    HttpClientAdapter Function(BooruConfig) createAdapter,
  ) => ProviderContainer(
    overrides: [
      miscDataStoreProvider.overrideWithValue(MemoryMiscDataStore()),
      booruConfigProvider.overrideWith(() => Profiles([official])),
      blacklistTagsProvider.overrideWith((_, _) => <String>{}),
      apiRequestCoordinatorProvider.overrideWithValue(coordinator),
      iqdbAdapterFactoryProvider.overrideWithValue(createAdapter),
    ],
  );

  test('IQDB shares API cooldowns and releases its 429 body', () async {
    final now = DateTime.utc(2026, 11, 26);
    var elapsed = Duration.zero;
    final coordinator = ApiRequestCoordinator(
      now: () => now.add(elapsed),
      elapsed: () => elapsed,
    );
    addTearDown(coordinator.dispose);
    var rejectedBodyClosed = false;
    final requests = <RequestOptions>[];
    final container = createContainer(
      coordinator,
      (_) => _IqdbAdapter((options) {
        requests.add(options);
        return requests.length == 1
            ? ResponseBody.fromString(
                '{}',
                429,
                headers: {
                  'retry-after': ['37'],
                },
                onClose: () => rejectedBodyClosed = true,
              )
            : ResponseBody.fromString('[]', 200);
      }),
    );
    addTearDown(container.dispose);
    await container.read(lookupPreferencesProvider.notifier).setIqdb(true);
    final search = container.read(iqdbSearchProvider);
    Future<List<IqdbHit>?> run() =>
        search(target, signature, IqdbPermission.persistent, () => false);

    final safeKey = ApiQuotaKey.fromUri(Uri.parse(second.url));
    final apiRetryAt = coordinator.recordRateLimit(safeKey, retryAfter: '12');
    Matcher limitedUntil(DateTime deadline) =>
        isA<ApiCooldownException>().having(
          (error) => error.retryAt,
          'deadline',
          deadline,
        );
    await expectLater(run(), throwsA(limitedUntil(apiRetryAt)));
    expect(requests, isEmpty);
    elapsed = const Duration(seconds: 12);

    final iqdbRetryAt = now.add(const Duration(seconds: 49));
    await expectLater(run(), throwsA(limitedUntil(iqdbRetryAt)));
    expect(rejectedBodyClosed, isTrue);
    expect(coordinator.snapshot(key).inFlight, 0);
    expect(coordinator.snapshot(key).retryAt, iqdbRetryAt);
    await expectLater(
      coordinator.acquire(safeKey),
      throwsA(isA<ApiCooldownException>()),
    );
    await expectLater(run(), throwsA(limitedUntil(iqdbRetryAt)));
    expect(requests, hasLength(1));

    elapsed = const Duration(seconds: 49);
    expect(await run(), isEmpty);
    expect(requests, hasLength(2));
    expect(requests.last.uri.path, '/iqdb_queries.json');
    expect(requests.last.uri.queryParameters['hash'], signature);
    expect(requests.last.followRedirects, isFalse);
    expect(
      requests.last.headers['Authorization'],
      'Basic ${base64Encode(utf8.encode('fixture-login:fixture-key'))}',
    );
    expect(coordinator.snapshot(key).inFlight, 0);
  });

  test(
    'queued IQDB uses a shared permit and checks consent before dispatch',
    () async {
      final coordinator = ApiRequestCoordinator();
      addTearDown(coordinator.dispose);
      var requests = 0;
      final container = createContainer(
        coordinator,
        (_) => _IqdbAdapter((_) {
          requests++;
          return ResponseBody.fromString('[]', 200);
        }),
      );
      addTearDown(container.dispose);
      final preferences = container.read(lookupPreferencesProvider.notifier);
      await preferences.setIqdb(true);
      final search = container.read(iqdbSearchProvider);
      final permits = [
        for (var i = 0; i < 4; i++) await coordinator.acquire(key),
      ];
      addTearDown(() {
        for (final permit in permits) {
          permit.release();
        }
      });

      Future<List<IqdbHit>?> run() =>
          search(target, signature, IqdbPermission.persistent, () => false);
      Future<ApiQuotaSnapshot> nextQueued() => coordinator
          .watch(key)
          .firstWhere((state) => state.queued == 1)
          .timeout(const Duration(seconds: 10));

      var queued = nextQueued();
      final allowed = run();
      await queued;
      expect(requests, 0);
      permits.removeLast().release();
      expect(await allowed, isEmpty);
      expect(requests, 1);

      permits.add(await coordinator.acquire(key));
      queued = nextQueued();
      final revoked = run();
      await queued;
      await preferences.setIqdb(false);
      permits.removeLast().release();
      expect(await revoked, isNull);
      expect(requests, 1);
      expect(coordinator.snapshot(key).queued, 0);
    },
  );

  IqdbHit hit(
    int id,
    double score, {
    BooruConfig? profile,
    bool visible = true,
  }) => (
    profile: profile ?? official,
    postId: id.toString(),
    score: score,
    post: visible ? TestPost(id: id) : null,
  );

  test(
    'acceptance takes the unique highest raw score among distinct posts',
    () {
      final primary = hit(1, 96);
      expect(
        rankIqdbHits([
          primary,
          hit(1, 96, profile: second),
          hit(2, 94),
        ], 90).automatic,
        primary,
      );
      expect(rankIqdbHits([primary, hit(2, 96)], 90).automatic, isNull);
      expect(rankIqdbHits([primary, hit(2, 95.999)], 90).automatic, primary);
      expect(rankIqdbHits([hit(1, 89.999)], 90).automatic, isNull);
      expect(rankIqdbHits([primary], 97).automatic, isNull);
    },
  );

  test(
    'display cutoff uses the raw score without removing ranked competitors',
    () {
      final hidden = hit(1, 69.999);
      final boundary = hit(2, 70);
      final strong = hit(3, 81);
      expect(rankIqdbHits([hidden, boundary], 90).visible, [boundary]);
      expect(rankIqdbHits([hidden, boundary, strong], 80).automatic, strong);
      expect(rankIqdbHits([hidden, hit(4, 75), strong], 80).automatic, strong);
    },
  );

  test('an equally strong or stronger hidden competitor blocks acceptance', () {
    final visible = hit(1, 91);
    final hidden = hit(2, 95, visible: false);
    final duplicate = hit(1, 96, profile: second, visible: false);
    expect(rankIqdbHits([visible, hidden], 90).automatic, isNull);
    final ranked = rankIqdbHits([visible, hidden, duplicate], 90);
    expect(ranked.automatic, isNull);
    expect(ranked.visible, [visible]);
    expect(
      rankIqdbHits([visible, hit(2, 91, visible: false)], 90).automatic,
      isNull,
    );
    expect(
      rankIqdbHits([visible, hit(2, 85, visible: false)], 90).automatic,
      visible,
    );
  });

  test('preference round-trip retains consent, score and selected methods', () {
    final original = LookupPreferences(
      allowIqdb: true,
      threshold: 93,
      profiles: {
        official.id: (
          endpoint: lookupEndpoint(official),
          methods: {PostLookupMatchKind.similarImage},
        ),
      },
    );
    final restored = LookupPreferences.decode(original.encode());
    expect(restored.methodsFor(official), {PostLookupMatchKind.similarImage});
    expect(
      restored.methodsFor(official.copyWith(url: 'https://example.test')),
      isEmpty,
    );
    expect(restored.methodsFor(second), isEmpty);
    expect(restored.permits(IqdbPermission.persistent), isTrue);
    expect(restored.threshold, 93);
    expect(
      const LookupPreferences().permits(IqdbPermission.persistent),
      isFalse,
    );
    expect(supportsIqdbLookup(official), isTrue);
    for (final url in [
      'http://danbooru.donmai.us',
      'https://danbooru.donmai.us:444',
      'https://user@danbooru.donmai.us',
      'https://danbooru.donmai.us/elsewhere',
      'https://danbooru.donmai.us.example.test',
    ]) {
      expect(supportsIqdbLookup(official.copyWith(url: url)), isFalse);
    }
    expect(supportsIqdbImageFormat('.JPG'), isTrue);
    expect(supportsIqdbImageFormat('gif'), isFalse);
  });

  test(
    'generates 533-character signatures off-thread for PNG and JPEG',
    () async {
      final pixels = image.Image(width: 12, height: 16);
      for (final pixel in pixels) {
        pixel.setRgb(pixel.x * 16, pixel.y * 14, 220);
      }
      for (final bytes in [image.encodePng(pixels), image.encodeJpg(pixels)]) {
        final signature = await iqdbSignatureFromBytes(bytes);
        expect(signature, matches(RegExp(r'^iqdb_[0-9a-f]{528}$')));
        expect(signature, iqdbSignature(bytes));
      }
      expect(iqdbSignature(image.encodeGif(pixels)), isNull);
      expect(
        iqdbSignature(image.encodePng(image.Image(width: 32769, height: 1))),
        isNull,
      );
    },
  );
}

final class _IqdbAdapter implements HttpClientAdapter {
  _IqdbAdapter(this.response);
  final ResponseBody Function(RequestOptions) response;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => response(options);

  @override
  void close({bool force = false}) {}
}
