import 'package:boorusama/boorus/danbooru/client_provider.dart';
import 'package:boorusama/boorus/gelbooru_v2/client_provider.dart';
import 'package:boorusama/boorus/moebooru/client_provider.dart';
import 'package:boorusama/boorus/eshuushuu/client_provider.dart';
import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/blacklists/src/types/blacklisted_tag.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/anonymous_access_provider.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/ddos/handler/providers.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

const site = 'https://safebooru.donmai.us';
const aId = '11111111-1111-4111-8111-111111111111';
const bId = '22222222-2222-4222-8222-222222222222';
final enabled = StateProvider((ref) => true);

BooruConfig profile(String id, {String apiKey = 'fixture-secret'}) =>
    BooruConfig.fromJson({
      ...BooruConfig.empty.toJson(),
      'id': id,
      'booruId': BooruType.danbooru.id,
      'booruIdHint': BooruType.danbooru.id,
      'url': site,
      'login': 'account',
      'apiKey': apiKey,
    });
PostOrigin origin({
  String? hint,
  String host = site,
  BooruType engine = BooruType.danbooru,
}) => PostOrigin.fromSource(
  booruType: engine,
  booruId: engine.id,
  source: host,
  profileIdHint: hint,
);
ContentAccessRequest request({
  String? hint,
  String host = site,
  BooruType engine = BooruType.danbooru,
  int id = 42,
}) => ContentAccessRequest(
  reference: const ContentReferenceCodec().parse(
    engine: engine,
    site: Uri.parse(host),
    kind: engine == BooruType.danbooru ? ContentKind.group : ContentKind.post,
    sourceKey: engine == BooruType.danbooru ? 'pool:$id' : 'id:$id',
  ),
  profileIdHint: hint,
  allowProfileHintFallback: false,
);

class _Configs extends BooruConfigNotifier {
  _Configs() : super(initialConfigs: []);
  void replace(List<BooruConfig> values) => state = values;
}

class _Blacklist extends GlobalBlacklistedTagsNotifier {
  @override
  IList<BlacklistedTag> build() => <BlacklistedTag>[].lock;
  void loading() => state = const AsyncLoading();
  void fail() =>
      state = AsyncError(StateError('local failure'), StackTrace.current);
  void ready() => state = AsyncData(<BlacklistedTag>[].lock);
}

ProviderContainer makeContainer({bool allowDio = false}) => ProviderContainer(
  overrides: [
    booruConfigProvider.overrideWith(_Configs.new),
    globalBlacklistedTagsProvider.overrideWith(_Blacklist.new),
    contentEffectivePolicyProvider.overrideWith(
      (ref, id) => const AsyncData('safe'),
    ),
    anonymousSourcePolicyProvider.overrideWith(
      (ref) => AnonymousSourcePolicy(enabled: ref.watch(enabled)),
    ),
    currentReadOnlyBooruConfigProvider.overrideWith(
      (ref) => throw StateError('Unexpected global profile read'),
    ),
    booruEngineRegistryProvider.overrideWith(
      (ref) => throw StateError('Unexpected registry read'),
    ),
    httpDdosProtectionBypassProvider.overrideWith(
      (ref) => throw StateError('Unexpected bypass read'),
    ),
    defaultUserAgentProvider.overrideWith(
      (ref) => allowDio
          ? 'fixture-agent'
          : throw StateError('Unexpected user agent read'),
    ),
    if (!allowDio)
      apiRequestCoordinatorProvider.overrideWith(
        (ref) => throw StateError('Unexpected coordinator read'),
      ),
  ],
);

void main() {
  for (final (engine, host) in [
    (BooruType.eshuushuu, 'https://e-shuushuu.net'),
    (BooruType.gelbooruV2, 'https://hypnohub.net'),
  ]) {
    test('saved $host origin opens without creating a profile', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final provider = contentAccessForOriginProvider(
        origin(host: host, engine: engine),
      );
      final hold = c.listen(provider, (_, _) {});
      addTearDown(hold.close);
      final access = c.read(provider)!;
      expect(access.key.profileId, isNull);
      expect(access.key.engine, engine);
      expect(access.config!.auth.login, isNull);
      expect(access.config!.auth.apiKey, isNull);
      expect(c.read(booruConfigProvider), isEmpty);
    });
  }
  test('Gelbooru fresh access reattaches a compatible profile despite an obsolete local hint', () {
    final c = makeContainer();
    addTearDown(c.dispose);
    final profiles = c.read(booruConfigProvider.notifier) as _Configs;
    final savedOrigin = origin(
      hint: aId,
      host: 'https://gelbooru.com',
      engine: BooruType.gelbooruV2,
    );
    final provider = contentAccessForOriginProvider(savedOrigin);
    final held = c.listen(provider, (_, _) {});
    addTearDown(held.close);
    expect(c.read(provider), isNull);
    final gelbooru = BooruConfig.fromJson({
      ...profile(bId).toJson(),
      'booruId': BooruType.gelbooruV2.id,
      'booruIdHint': BooruType.gelbooruV2.id,
      'url': 'https://gelbooru.com',
    });
    profiles.replace([gelbooru]);
    final bound = c.read(provider)!;
    expect(bound.key.profileId, bId);
    expect(bound.key.siteNamespace, 'gelbooru.com');
    profiles.replace([]);
    expect(c.read(contentAccessContextProvider(bound.key)), isNull);
    expect(c.read(provider), isNull);
  });

  test('fresh origins reattach compatible profiles while pinned references stay strict', () {
    final c = makeContainer();
    addTearDown(c.dispose);
    final profiles = c.read(booruConfigProvider.notifier) as _Configs;
    final byOrigin = contentAccessForOriginProvider(origin());
    final hintOrigin = contentAccessForOriginProvider(origin(hint: aId));
    final byReference = contentAccessForReferenceProvider(request());
    final hintReference = contentAccessForReferenceProvider(request(hint: aId));
    final held = [
      c.listen(byOrigin, (_, _) {}),
      c.listen(hintOrigin, (_, _) {}),
      c.listen(byReference, (_, _) {}),
      c.listen(hintReference, (_, _) {}),
    ];
    addTearDown(() {
      for (final sub in held) {
        sub.close();
      }
    });
    final a = profile(aId);
    final b = profile(bId, apiKey: 'other-secret');
    profiles.replace([a]);
    expect(c.read(byOrigin)!.key.profileId, aId);
    expect(c.read(byReference)!.key.profileId, aId);
    profiles.replace([a, b]);
    expect(c.read(byOrigin), isNull);
    expect(c.read(byReference), isNull);
    expect(c.read(hintOrigin)!.key.profileId, aId);
    expect(c.read(hintReference)!.key.profileId, aId);
    final capturedA = c.read(hintOrigin)!.key;
    profiles.replace([b]);
    expect(c.read(contentAccessContextProvider(capturedA)), isNull);
    final originPublic = c.read(hintOrigin)!;
    final referencePublic = c.read(hintReference)!;
    expect(originPublic.key.profileId, bId);
    expect(referencePublic.key.profileId, isNull);
    expect(originPublic.config!.auth.apiKey, 'other-secret');
    expect(referencePublic.config!.auth.login, isNull);
    expect(c.read(booruConfigProvider), [b]);
    expect(b.auth.apiKey, 'other-secret');
    final unknown = origin(hint: aId, host: 'https://private.example.test');
    final subscription = c.listen(
      contentAccessForOriginProvider(unknown),
      (_, _) {},
    );
    addTearDown(subscription.close);
    expect(c.read(contentAccessForOriginProvider(unknown)), isNull);
  });

  test(
    'unconfigured untrusted origin and reference are not public sources',
    () {
      final c = makeContainer();
      addTearDown(c.dispose);
      for (final (host, engine) in [
        ('https://private.example.test', BooruType.danbooru),
        ('https://safebooru.donmai.us/install', BooruType.danbooru),
        ('https://safebooru.donmai.us:444', BooruType.danbooru),
        (site, BooruType.moebooru),
      ]) {
        final o = contentAccessForOriginProvider(
          origin(host: host, engine: engine),
        );
        final r = contentAccessForReferenceProvider(
          request(host: host, engine: engine),
        );
        final os = c.listen(o, (_, _) {});
        final rs = c.listen(r, (_, _) {});
        expect(c.read(o), isNull, reason: '$host $engine');
        expect(c.read(r), isNull, reason: '$host $engine');
        os.close();
        rs.close();
      }
      expect(c.read(booruConfigProvider), isEmpty);
    },
  );

  test('many references share one lazy public scope and every consumer shares its Dio', () {
    final c = makeContainer(allowDio: true);
    addTearDown(c.dispose);
    final subscriptions = [
      for (var i = 1; i <= 100; i++)
        c.listen(contentAccessForReferenceProvider(request(id: i)), (_, _) {}),
    ];
    addTearDown(() {
      for (final sub in subscriptions) {
        sub.close();
      }
    });
    final contexts = [
      for (var i = 1; i <= 100; i++)
        c.read(contentAccessForReferenceProvider(request(id: i)))!,
    ];
    final first = contexts.first;
    expect(contexts.every((context) => identical(context, first)), isTrue);
    expect(first.key.profileId, isNull);
    final scope = first.config!.anonymousReadScope!;
    expect(scope.isCurrent, isTrue);
    final auth = first.config!.auth;
    final dio = scope.dio;
    expect(identical(c.read(defaultDioProvider(auth)), dio), isTrue);
    expect(identical(c.read(dioForWidgetProvider(auth)), dio), isTrue);
    expect(identical(c.read(danbooruDioProvider(auth)), dio), isTrue);
    expect(identical(c.read(gelbooruV2DioProvider(auth)), dio), isTrue);
    expect(identical(c.read(eshuushuuDioProvider(auth)), dio), isTrue);
    expect(
      identical(c.read(moebooruPostRequestDioProvider(auth)), dio),
      isTrue,
    );
    final headers = c.read(httpHeadersProvider(auth));
    expect(headers.map((key, value) => MapEntry(key.toLowerCase(), value)), {
      'user-agent': 'fixture-agent',
      'referer': site,
    });
    expect(c.read(booruConfigProvider), isEmpty);
  });

  test(
    'profile, credentials, policy and local blacklist revoke old scopes',
    () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final provider = contentAccessForReferenceProvider(request(hint: aId));
      final subscription = c.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final profiles = c.read(booruConfigProvider.notifier) as _Configs;
      final blacklist =
          c.read(globalBlacklistedTagsProvider.notifier) as _Blacklist;
      var previous = c.read(provider)!;
      var scope = previous.config!.anonymousReadScope!;
      expect(scope.isCurrent, isTrue);
      void revoked() {
        expect(scope.isCurrent, isFalse);
        expect(c.read(contentAccessContextProvider(previous.key)), isNull);
      }

      profiles.replace([profile(bId)]);
      revoked();
      var next = c.read(provider)!;
      expect(next.key, isNot(previous.key));
      previous = next;
      scope = next.config!.anonymousReadScope!;
      profiles.replace([profile(bId, apiKey: 'changed-secret')]);
      revoked();
      next = c.read(provider)!;
      expect(next.key, isNot(previous.key));
      previous = next;
      scope = next.config!.anonymousReadScope!;
      profiles.replace([]);
      revoked();
      next = c.read(provider)!;
      expect(next.key, isNot(previous.key));
      previous = next;
      scope = next.config!.anonymousReadScope!;
      c.read(enabled.notifier).state = false;
      revoked();
      expect(c.read(provider), isNull);
      c.read(enabled.notifier).state = true;
      next = c.read(provider)!;
      expect(next.key, isNot(previous.key));
      previous = next;
      scope = next.config!.anonymousReadScope!;
      blacklist.loading();
      revoked();
      expect(c.read(provider), isNull);
      blacklist.fail();
      expect(c.read(provider), isNull);
      blacklist.ready();
      next = c.read(provider)!;
      expect(next.key, isNot(previous.key));
      expect(next.config!.anonymousReadScope!.isCurrent, isTrue);
      expect(c.read(booruConfigProvider), isEmpty);
    },
  );
}
