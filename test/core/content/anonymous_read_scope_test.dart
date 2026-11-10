import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/configs/config/src/data/booru_config_converter.dart';
import 'package:boorusama/core/configs/config/src/data/booru_config_repository_hive.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/anonymous_read_scope.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:boorusama/core/content/content_access.dart';
import 'package:boorusama/core/posts/favorites/src/data/providers.dart';
import 'package:boorusama/core/posts/favorites/src/data/repository.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

const profileId = '11111111-1111-4111-8111-111111111111';
final source = const AnonymousSourcePolicy().resolve(
  BooruType.danbooru,
  Uri.parse('https://danbooru.donmai.us'),
)!;

ContentAccessKey key({
  int authEpoch = 1,
  int policyEpoch = 1,
  String? profile,
  String site = 'danbooru.donmai.us',
  BooruType engine = BooruType.danbooru,
}) => ContentAccessKey(
  engine: engine,
  siteNamespace: site,
  profileId: profile,
  authEpoch: authEpoch,
  policyEpoch: policyEpoch,
);

class _Adapter implements HttpClientAdapter {
  var closes = 0;
  var requests = 0;
  @override
  void close({bool force = false}) {
    closes++;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests++;
    throw StateError('Unexpected network request');
  }
}

void main() {
  test('client is lazy, reused and disposed exactly once', () {
    final adapter = _Adapter();
    var created = 0;
    var current = true;
    final scope = AnonymousReadScope(
      source: source,
      key: key(),
      createDio: () {
        created++;
        return Dio()..httpClientAdapter = adapter;
      },
      current: () => current,
    );
    expect(scope.isCurrent, isTrue);
    expect(created, 0);
    final client = scope.dio;
    for (var i = 0; i < 100; i++) {
      expect(identical(scope.dio, client), isTrue);
    }
    expect(created, 1);
    current = false;
    expect(scope.isCurrent, isFalse);
    expect(() => scope.dio, throwsStateError);
    scope.dispose();
    scope.dispose();
    expect(adapter.closes, 1);
    expect(adapter.requests, 0);
    expect(() => scope.dio, throwsStateError);
  });

  test('revocation before client creation cannot create a client', () {
    var created = 0;
    final scope = AnonymousReadScope(
      source: source,
      key: key(),
      createDio: () {
        created++;
        return Dio();
      },
      current: () => false,
    );
    expect(scope.isCurrent, isFalse);
    expect(() => scope.dio, throwsStateError);
    scope.dispose();
    scope.dispose();
    expect(created, 0);
  });

  test('epochs isolate clients and cache namespace without credentials', () {
    final firstAdapter = _Adapter();
    final secondAdapter = _Adapter();
    final first = AnonymousReadScope(
      source: source,
      key: key(),
      createDio: () => Dio()..httpClientAdapter = firstAdapter,
      current: () => true,
    );
    final second = AnonymousReadScope(
      source: source,
      key: key(authEpoch: 2, policyEpoch: 2),
      createDio: () => Dio()..httpClientAdapter = secondAdapter,
      current: () => true,
    );
    expect(first.key, isNot(second.key));
    expect(first.cacheNamespace, isNot(second.cacheNamespace));
    expect(first.cacheNamespace, isNot(contains('secret')));
    expect(first.cacheNamespace, isNot(contains('token')));
    expect(identical(first.dio, second.dio), isFalse);
    first.dispose();
    second.dispose();
    expect(firstAdapter.closes, 1);
    expect(secondAdapter.closes, 1);
  });

  test(
    'anonymous scope rejects profile binding and mismatched source identity',
    () {
      for (final bad in [
        key(profile: profileId),
        key(site: 'other.example.test'),
        key(engine: BooruType.moebooru),
      ]) {
        expect(
          () => AnonymousReadScope(
            source: source,
            key: bad,
            createDio: Dio.new,
            current: () => true,
          ),
          throwsFormatException,
        );
      }
    },
  );

  test('scope stays transient through config, auth, copy and JSON', () {
    final first = AnonymousReadScope(
      source: source,
      key: key(),
      createDio: Dio.new,
      current: () => true,
    );
    final second = AnonymousReadScope(
      source: source,
      key: key(authEpoch: 2),
      createDio: Dio.new,
      current: () => true,
    );
    final normal = BooruConfig.defaultConfig(
      booruType: BooruType.danbooru,
      url: 'https://danbooru.donmai.us',
      customDownloadFileNameFormat: null,
    );
    final public = normal.copyWith(anonymousReadScope: first);
    final next = normal.copyWith(anonymousReadScope: second);
    expect(
      identical(public.copyWith(name: 'copy').anonymousReadScope, first),
      isTrue,
    );
    expect(identical(public.auth.anonymousReadScope, first), isTrue);
    expect(public.auth, isNot(next.auth));
    expect(public.auth.computeHash(), isNot(next.auth.computeHash()));
    expect(public.auth.computeHash(), isNot(normal.auth.computeHash()));
    final auth = normal.auth;
    final originalHashInput =
        '${auth.booruId}${auth.booruIdHint}${auth.url}${auth.apiKey}${auth.login}${auth.passHash}';
    expect(
      auth.computeHash(),
      sha256.convert(utf8.encode(originalHashInput)).toString(),
    );
    expect(public.toJson().containsKey('anonymousReadScope'), isFalse);
    final forged = BooruConfig.fromJson({
      ...normal.toJson(),
      'id': profileId,
      'anonymousReadScope': {
        'site': 'https://danbooru.donmai.us',
        'authEpoch': 1,
      },
    });
    expect(forged.anonymousReadScope, isNull);
    expect(forged.auth.anonymousReadScope, isNull);
    expect(() => public.toBooruConfigData(), throwsStateError);
    expect(
      normal.toBooruConfigData().toBooruConfig(id: profileId)!.url,
      normal.url,
    );
    first.dispose();
    second.dispose();
  });

  test('anonymous access context enforces scope, endpoint and revocation', () {
    var active = true;
    var clients = 0;
    final scope = AnonymousReadScope(
      source: source,
      key: key(),
      createDio: () {
        clients++;
        throw StateError('Unexpected client');
      },
      current: () => active,
    );
    final otherScope = AnonymousReadScope(
      source: source,
      key: key(),
      createDio: Dio.new,
      current: () => true,
    );
    final normal = BooruConfig.fromJson({
      ...BooruConfig.defaultConfig(
        booruType: BooruType.danbooru,
        url: source.site.toString(),
        customDownloadFileNameFormat: null,
      ).toJson(),
      'id': profileId,
    });
    final public = normal.copyWith(anonymousReadScope: scope);
    final access = ContentAccessContext.anonymous(config: public, scope: scope);
    expect(access.key, scope.key);
    expect(access.key.profileId, isNull);
    expect(access.baseUrl, source.site);
    expect(access.matchesProfiles([]), isTrue);
    expect(
      () => ContentAccessContext.profile(
        config: public,
        authEpoch: 1,
        policyEpoch: 1,
      ),
      throwsFormatException,
    );
    expect(
      () => ContentAccessContext.anonymous(config: public, scope: otherScope),
      throwsFormatException,
    );
    final variants = <Map<String, dynamic>>[
      {'url': 'https://danbooru.donmai.us/'},
      {'url': 'https://other.example.test'},
      {'booruIdHint': BooruType.moebooru.id},
      {'login': 'account'},
      {'apiKey': 'secret'},
      {'passHash': 'secret'},
      {
        'proxySettings': {
          'type': 'http',
          'host': 'proxy.example.test',
          'port': 8080,
        },
      },
      {'network': <String, dynamic>{}},
    ];
    for (final variant in variants) {
      final candidate = BooruConfig.fromJson({...normal.toJson(), ...variant})
          .copyWith(anonymousReadScope: scope);
      expect(
        () => ContentAccessContext.anonymous(config: candidate, scope: scope),
        throwsFormatException,
        reason: '$variant',
      );
    }
    final blankCredentials = BooruConfig.fromJson({
      ...normal.toJson(),
      'login': '',
      'apiKey': '',
      'passHash': '',
    }).copyWith(anonymousReadScope: scope);
    expect(
      () => ContentAccessContext.anonymous(
        config: blankCredentials,
        scope: scope,
      ),
      returnsNormally,
    );
    expect(access.withEndpoint(source.site).baseUrl, source.site);
    for (final endpoint in [
      'https://other.example.test/posts.json',
      'https://127.0.0.1/posts.json',
      'https://danbooru.donmai.us/favorites.json',
      'http://danbooru.donmai.us/posts.json',
    ]) {
      expect(
        () => access.withEndpoint(Uri.parse(endpoint)),
        throwsFormatException,
        reason: endpoint,
      );
    }
    final profile = ContentAccessContext.profile(
      config: normal,
      authEpoch: 1,
      policyEpoch: 1,
    );
    expect(profile.key.profileId, profileId);
    expect(profile.matchesProfiles([normal]), isTrue);
    expect(
      profile
          .withEndpoint(Uri.parse('https://other.example.test/'))
          .baseUrl
          .host,
      'other.example.test',
    );
    active = false;
    expect(access.matchesProfiles([]), isFalse);
    expect(clients, 0);
    scope.dispose();
    otherScope.dispose();
  });

  test(
    'mixed profile batch rejects public context before any Hive writes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'anonymous-scope-hive-',
      );
      Hive.init(directory.path);
      final box = await Hive.openBox<String>('profiles');
      addTearDown(() async {
        await Hive.close();
        await directory.delete(recursive: true);
      });
      final scope = AnonymousReadScope(
        source: source,
        key: key(),
        createDio: Dio.new,
        current: () => true,
      );
      addTearDown(scope.dispose);
      final normal = BooruConfig.fromJson({
        ...BooruConfig.defaultConfig(
          booruType: BooruType.danbooru,
          url: 'https://danbooru.donmai.us',
          customDownloadFileNameFormat: null,
        ).toJson(),
        'id': profileId,
      });
      final repository = HiveBooruConfigRepository(box: box);
      await expectLater(
        repository.addAll([normal, normal.copyWith(anonymousReadScope: scope)]),
        throwsStateError,
      );
      expect(box.isEmpty, isTrue);
      expect(await repository.getAll(), isEmpty);
      final inserted = await repository.addAll([normal]);
      expect(inserted.single.id, profileId);
      expect((await repository.getAll()).single.id, profileId);
    },
  );

  test(
    'public favorite providers short circuit before engine registry',
    () async {
      var registryReads = 0;
      var clients = 0;
      final scope = AnonymousReadScope(
        source: source,
        key: key(),
        createDio: () {
          clients++;
          throw StateError('Unexpected client');
        },
        current: () => true,
      );
      final config = BooruConfig.defaultConfig(
        booruType: BooruType.danbooru,
        url: 'https://danbooru.donmai.us',
        customDownloadFileNameFormat: null,
      ).copyWith(anonymousReadScope: scope);
      final container = ProviderContainer(
        overrides: [
          booruEngineRegistryProvider.overrideWith((ref) {
            registryReads++;
            throw StateError('Unexpected registry access');
          }),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(scope.dispose);
      final authRepo = container.read(favoriteRepoProvider(config.auth));
      final profileRepo = container.read(
        profileFavoriteRepoProvider((config.auth, profileId)),
      );
      expect(authRepo, isA<EmptyFavoriteRepository>());
      expect(profileRepo, isA<EmptyFavoriteRepository>());
      expect(authRepo.canFavorite(), isFalse);
      expect(profileRepo.canFavorite(), isFalse);
      expect(await authRepo.removeFromFavorites(7), isFalse);
      expect(await profileRepo.removeFromFavorites(7), isFalse);
      expect(registryReads, 0);
      expect(clients, 0);
    },
  );
}
