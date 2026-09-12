// Dart imports:
import 'dart:typed_data';

// Package imports:
import 'package:booru_clients/pixiv.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/boorus/pixiv/auth/auth_interceptor.dart';
import 'package:boorusama/boorus/pixiv/auth/login_page.dart';
import 'package:boorusama/boorus/pixiv/auth/pkce.dart';
import 'package:boorusama/boorus/pixiv/client_provider.dart';
import 'package:boorusama/boorus/pixiv/configs/extra_data.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/data.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/http/client/src/interceptors/dio_logger_interceptor.dart';

void main() {
  group('deriving a code challenge from a verifier', () {
    test('reproduces the S256 vector published in RFC 7636 appendix B', () {
      expect(
        pixivCodeChallengeOf('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
        'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
      );
    });

    test('never emits padding or characters outside the unreserved set', () {
      final challenges = [
        for (var i = 0; i < 100; i++)
          pixivCodeChallengeOf(PixivPkcePair.generate().codeVerifier),
      ];

      for (final challenge in challenges) {
        expect(challenge, matches(_unreserved));
        expect(challenge.length, 43);
      }
    });
  });

  group('generating a code verifier', () {
    test('always produces 43 unreserved characters and never repeats', () {
      final verifiers = {
        for (var i = 0; i < 1000; i++) PixivPkcePair.generate().codeVerifier,
      };

      // A predictable generator (or a constant) collapses this set.
      expect(verifiers.length, 1000);

      for (final verifier in verifiers) {
        expect(verifier.length, 43);
        expect(verifier, matches(_unreserved));
      }
    });

    test('is not exposed by the string representation of the pair', () {
      final pair = PixivPkcePair.generate();

      expect(pair.toString(), isNot(contains(pair.codeVerifier)));
      expect(pair.toString(), contains(pair.codeChallenge));
    });

    test('is never carried in the login url, only the challenge is', () {
      final pair = PixivPkcePair.generate();
      final uri = pixivLoginUri(pair.codeChallenge);

      expect(uri.toString(), isNot(contains(pair.codeVerifier)));
      expect(uri.queryParameters['code_challenge'], pair.codeChallenge);
      expect(uri.queryParameters['code_challenge_method'], 'S256');
    });
  });

  group('reading the authorization code out of a navigation target', () {
    final cases = [
      (
        url: 'pixiv://account/login?code=granted&via=login',
        code: 'granted',
        reason: 'the exact redirect the app registered for',
      ),
      (
        url: 'https://evil/?x=pixiv://account/login?code=1',
        code: null,
        reason: 'a foreign page that merely mentions the redirect',
      ),
      (
        url: 'pixiv://account/login@evil/?code=1',
        code: null,
        reason: 'the redirect shape pushed into the path',
      ),
      (
        url: 'pixiv://accounts/login?code=1',
        code: null,
        reason: 'a look-alike host',
      ),
      (
        url: 'pixiv://account/logon?code=1',
        code: null,
        reason: 'a look-alike path',
      ),
      (
        url: 'http://account/login?code=1',
        code: null,
        reason: 'a look-alike scheme',
      ),
      (
        url: 'pixiv://account/login',
        code: null,
        reason: 'the redirect without a code',
      ),
      (
        url: 'pixiv://account/login?code=',
        code: null,
        reason: 'the redirect with an empty code',
      ),
      (
        url: 'pixiv://someone@account/login?code=1',
        code: null,
        reason: 'credentials smuggled into the authority',
      ),
    ];

    for (final c in cases) {
      test('yields ${c.code ?? 'nothing'} for ${c.reason}', () {
        expect(pixivAuthCodeFromRedirect(c.url), c.code);
      });
    }
  });

  group('talking to the token endpoint', () {
    test('happens over a client with no logging interceptor attached', () {
      final interceptors = createPixivAuthClient().debugDio.interceptors;

      expect(interceptors.whereType<LoggingInterceptor>(), isEmpty);
      // Dio installs exactly one interceptor of its own; anything beyond
      // that would mean app-level middleware sees token traffic.
      expect(interceptors.length, 1);
    });
  });

  group('storing account metadata alongside the credential', () {
    test('survives a round trip through the passHash field', () {
      final expiry = DateTime.fromMillisecondsSinceEpoch(1757300000000);
      final restored = PixivExtraData.fromPassHash(
        const PixivExtraData(
          userId: '12345',
          userName: 'Someone',
          isPremium: true,
        ).copyWith(tokenExpiry: expiry).toPassHash(),
      );

      expect(restored.userId, '12345');
      expect(restored.userName, 'Someone');
      expect(restored.isPremium, true);
      expect(restored.tokenExpiry, expiry);
    });

    final malformed = [
      (passHash: null, reason: 'a missing value'),
      (passHash: '', reason: 'an empty value'),
      (passHash: 'not json at all', reason: 'a value that is not json'),
      (passHash: '54321', reason: "another engine's bare numeric id"),
      (passHash: '{"userId": {"nested": 1}}', reason: 'a wrongly typed field'),
    ];

    for (final c in malformed) {
      test('falls back to defaults for ${c.reason}', () {
        final data = PixivExtraData.fromPassHash(c.passHash);

        expect(data.userId, isNull);
        expect(data.userName, isNull);
        expect(data.isPremium, isNull);
        expect(data.tokenExpiry, isNull);
      });
    }
  });

  group('persisting a rotated refresh token with two profiles configured', () {
    late _FakeConfigRepository repo;

    setUp(() {
      repo = _FakeConfigRepository([
        _pixivConfig(
          id: 1,
          apiKey: 'refresh-a',
          extraData: const PixivExtraData(userId: '1', userName: 'A'),
        ),
        _pixivConfig(
          id: 2,
          apiKey: 'refresh-b',
          extraData: const PixivExtraData(userId: '2', userName: 'B'),
        ),
      ]);
    });

    test('resolves each profile to its own record despite a shared url', () {
      final configs = repo.snapshot;

      expect(
        resolvePixivConfigId(configs, configs[0].auth),
        1,
      );
      expect(
        resolvePixivConfigId(configs, configs[1].auth),
        2,
      );
    });

    final rotations = [
      (
        label: 'the first one',
        id: 1,
        token: 'refresh-a',
        otherId: 2,
        otherToken: 'refresh-b',
      ),
      (
        label: 'the second one',
        id: 2,
        token: 'refresh-b',
        otherId: 1,
        otherToken: 'refresh-a',
      ),
    ];

    for (final c in rotations) {
      test('writes it to ${c.label} and leaves the other alone', () async {
        await persistPixivRotatedToken(
          repo: repo,
          configId: _idOf(repo, c.token),
          tokens: const PixivTokens(
            accessToken: 'access',
            refreshToken: 'rotated',
            expiresIn: 3600,
          ),
        );

        expect(repo.byId(c.id).apiKey, 'rotated');
        expect(repo.byId(c.otherId).apiKey, c.otherToken);
      });
    }

    test(
      'keeps the newest token when the other profile is saved after',
      () async {
        await persistPixivRotatedToken(
          repo: repo,
          configId: _idOf(repo, 'refresh-b'),
          tokens: const PixivTokens(
            accessToken: 'access',
            refreshToken: 'rotated',
            expiresIn: 3600,
          ),
        );

        // An unrelated save on the other profile, as the config UI would do.
        await repo.update(
          1,
          repo.byId(1).toBooruConfigData().copyWith(name: 'renamed'),
        );

        expect(repo.byId(2).apiKey, 'rotated');
        expect(repo.byId(1).apiKey, 'refresh-a');
        expect(repo.byId(1).name, 'renamed');
      },
    );

    test('preserves the stored account name when a refresh omits it', () async {
      await persistPixivRotatedToken(
        repo: repo,
        configId: _idOf(repo, 'refresh-a'),
        tokens: const PixivTokens(
          accessToken: 'access',
          refreshToken: 'refresh-a2',
        ),
      );

      expect(
        PixivExtraData.fromPassHash(repo.byId(1).passHash).userName,
        'A',
      );
    });

    test('writes nothing when the record has been deleted meanwhile', () async {
      await persistPixivRotatedToken(
        repo: repo,
        configId: 99,
        tokens: const PixivTokens(refreshToken: 'refresh-x'),
      );

      expect(repo.byId(1).apiKey, 'refresh-a');
      expect(repo.byId(2).apiKey, 'refresh-b');
    });
  });

  group('attaching the live bearer token to a request', () {
    test('replaces the placeholder one instead of sending a second', () async {
      final adapter = _StaticTokenAdapter(() => 'live');
      final interceptor = PixivAuthInterceptor(
        refreshToken: 'refresh-0',
        refresher: (_) async => const PixivTokens(
          accessToken: 'live',
          refreshToken: 'refresh-1',
          expiresIn: 3600,
        ),
      );

      final dio = Dio(BaseOptions(baseUrl: 'https://app-api.pixiv.net'))
        ..httpClientAdapter = adapter
        ..interceptors.add(interceptor);
      interceptor.attach(dio);

      // The client attaches its own placeholder per request, in a different
      // casing than the interceptor writes.
      final response = await dio.get<dynamic>(
        '/illust',
        options: Options(headers: {'authorization': 'Bearer placeholder'}),
      );

      expect(response.statusCode, 200);
      expect(
        adapter.headerLog.single.keys.where(
          (key) => key.toLowerCase() == 'authorization',
        ),
        hasLength(1),
      );
    });
  });

  group('recovering from an expired access token', () {
    test(
      'refreshes once for two simultaneous rejections and retries both',
      () async {
        var acceptedToken = 'access-1';
        var refreshCount = 0;

        final interceptor = PixivAuthInterceptor(
          refreshToken: 'refresh-0',
          refresher: (token) async {
            refreshCount++;
            // Wide enough for both in-flight requests to land on the same
            // refresh rather than starting one each.
            await Future<void>.delayed(const Duration(milliseconds: 20));

            return PixivTokens(
              accessToken: 'access-$refreshCount',
              refreshToken: 'refresh-$refreshCount',
              expiresIn: 3600,
            );
          },
        );

        final dio = Dio(BaseOptions(baseUrl: 'https://app-api.pixiv.net'))
          ..httpClientAdapter = _StaticTokenAdapter(() => acceptedToken)
          ..interceptors.add(interceptor);
        interceptor.attach(dio);

        // The first refresh is the proactive one: there is no access token yet.
        final warmup = await dio.get<dynamic>('/warmup');
        expect(warmup.statusCode, 200);

        final refreshesBefore = refreshCount;

        // The server stops honouring the token the interceptor is holding.
        acceptedToken = 'access-2';

        final responses = await Future.wait([
          dio.get<dynamic>('/first'),
          dio.get<dynamic>('/second'),
        ]);

        expect(refreshCount - refreshesBefore, 1);
        expect(responses.map((e) => e.statusCode), everyElement(200));
      },
    );

    test(
      'gives up after one retry instead of looping on a rejection',
      () async {
        var refreshCount = 0;

        final interceptor = PixivAuthInterceptor(
          refreshToken: 'refresh-0',
          refresher: (token) async {
            refreshCount++;

            return const PixivTokens(
              accessToken: 'stale',
              refreshToken: 'refresh-1',
              expiresIn: 3600,
            );
          },
        );

        final dio = Dio(BaseOptions(baseUrl: 'https://app-api.pixiv.net'))
          ..httpClientAdapter = _StaticTokenAdapter(() => 'never-issued')
          ..interceptors.add(interceptor);
        interceptor.attach(dio);

        await expectLater(
          dio.get<dynamic>('/first'),
          throwsA(
            isA<DioException>().having(
              (e) => e.response?.statusCode,
              'status',
              401,
            ),
          ),
        );

        // One proactive refresh plus one after the 401, and no more.
        expect(refreshCount, 2);
      },
    );

    test(
      'reports an expired session only when the grant itself is rejected',
      () async {
        final failures = <String>[];

        final rejected = PixivAuthInterceptor(
          refreshToken: 'refresh-0',
          refresher: (_) async =>
              throw const PixivAuthException('nope', code: 'invalid_grant'),
          onAuthFailed: () => failures.add('rejected'),
        );

        final offline = PixivAuthInterceptor(
          refreshToken: 'refresh-0',
          refresher: (_) async => throw const _Offline(),
          onAuthFailed: () => failures.add('offline'),
        );

        for (final interceptor in [rejected, offline]) {
          final dio = Dio(BaseOptions(baseUrl: 'https://app-api.pixiv.net'))
            ..httpClientAdapter = _StaticTokenAdapter(() => 'never-issued')
            ..interceptors.add(interceptor);
          interceptor.attach(dio);

          try {
            await dio.get<dynamic>('/first');
          } on DioException catch (_) {
            // The point of the test is which failures raise the dialog, not
            // that the request fails.
          }
        }

        expect(failures, ['rejected']);
      },
    );
  });
}

final _unreserved = RegExp(r'^[A-Za-z0-9\-._~]+$');

/// Resolves the profile holding [refreshToken] the way the Dio builder does,
/// so a rotation test exercises the real record lookup rather than assuming
/// an id.
int _idOf(_FakeConfigRepository repo, String refreshToken) {
  final configs = repo.snapshot;
  final auth = configs.firstWhere((c) => c.apiKey == refreshToken).auth;

  return resolvePixivConfigId(configs, auth)!;
}

class _Offline implements Exception {
  const _Offline();
}

BooruConfig _pixivConfig({
  required int id,
  required String apiKey,
  required PixivExtraData extraData,
}) =>
    BooruConfigData.anonymous(
          booru: BooruType.pixiv,
          booruHint: BooruType.pixiv,
          name: 'pixiv-$id',
          filter: BooruConfigRatingFilter.none,
          url: 'https://www.pixiv.net/',
          customDownloadFileNameFormat: null,
          customBulkDownloadFileNameFormat: null,
          imageDetaisQuality: null,
          videoQuality: null,
        )
        .copyWith(apiKey: apiKey, passHash: () => extraData.toPassHash())
        .toBooruConfig(id: id)!;

class _FakeConfigRepository implements BooruConfigRepository {
  _FakeConfigRepository(this._configs);

  final List<BooruConfig> _configs;

  List<BooruConfig> get snapshot => _configs.toList();

  BooruConfig byId(int id) => _configs.firstWhere((e) => e.id == id);

  @override
  Future<List<BooruConfig>> getAll() async => _configs.toList();

  @override
  Future<BooruConfig?> update(int id, BooruConfigData booruConfigData) async {
    final index = _configs.indexWhere((e) => e.id == id);
    if (index == -1) return null;

    final updated = booruConfigData.toBooruConfig(id: id);
    if (updated == null) return null;

    _configs[index] = updated;

    return updated;
  }

  @override
  Future<BooruConfig?> add(BooruConfigData booruConfigData) =>
      throw UnimplementedError();

  @override
  Future<List<BooruConfig>> addAll(List<BooruConfig> booruConfigs) =>
      throw UnimplementedError();

  @override
  Future<void> clear() => throw UnimplementedError();

  @override
  Future<void> remove(BooruConfig booruConfig) => throw UnimplementedError();
}

/// Accepts exactly one bearer token and rejects everything else with a 401,
/// so a test can revoke the token the interceptor is holding mid-flight.
class _StaticTokenAdapter implements HttpClientAdapter {
  _StaticTokenAdapter(this.acceptedToken);

  final String Function() acceptedToken;

  /// The headers of every request that reached the wire.
  final headerLog = <Map<String, dynamic>>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    headerLog.add(Map.of(options.headers));

    final authorized =
        options.headers['Authorization'] == 'Bearer ${acceptedToken()}';

    return ResponseBody.fromString(
      authorized ? '{"ok": true}' : '{"error": "invalid_token"}',
      authorized ? 200 : 401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
