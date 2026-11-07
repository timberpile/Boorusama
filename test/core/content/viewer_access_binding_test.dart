import 'dart:async';
import 'dart:typed_data';

import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/blacklists/src/types/blacklisted_tag.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/anonymous_access_provider.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/content_media_access.dart';
import 'package:boorusama/core/posts/details/src/providers/viewer_source_access_provider.dart';
import 'package:boorusama/core/posts/details/src/types/viewer_entry.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

const site = 'https://safebooru.donmai.us';
const aId = '11111111-1111-4111-8111-111111111111';
const bId = '22222222-2222-4222-8222-222222222222';
final enabled = StateProvider((ref) => true);
final policy = StateProvider((ref) => 'first');
BooruConfig profile(String id, {String secret = 'same'}) =>
    BooruConfig.fromJson({
      ...BooruConfig.empty.toJson(),
      'id': id,
      'booruId': BooruType.danbooru.id,
      'booruIdHint': BooruType.danbooru.id,
      'url': site,
      'login': 'fixture',
      'apiKey': secret,
    });
final origin = PostOrigin.fromSource(
  booruType: BooruType.danbooru,
  booruId: BooruType.danbooru.id,
  source: site,
);

class _Configs extends BooruConfigNotifier {
  _Configs() : super(initialConfigs: []);
  void replace(List<BooruConfig> values) => state = values;
}

class _Blacklist extends GlobalBlacklistedTagsNotifier {
  @override
  IList<BlacklistedTag> build() => <BlacklistedTag>[].lock;
}

ProviderContainer makeContainer() => ProviderContainer(
  overrides: [
    booruConfigProvider.overrideWith(_Configs.new),
    globalBlacklistedTagsProvider.overrideWith(_Blacklist.new),
    contentEffectivePolicyProvider.overrideWith(
      (ref, id) => AsyncData(ref.watch(policy)),
    ),
    anonymousSourcePolicyProvider.overrideWith(
      (ref) => AnonymousSourcePolicy(enabled: ref.watch(enabled)),
    ),
  ],
);

class _Cache implements ImageCacheManager {
  final values = <String, Uint8List>{};
  Completer<Uint8List?>? readGate;
  @override
  String generateCacheKey(String url, {String? customKey}) => customKey ?? url;
  @override
  Future<Uint8List?> getCachedFileBytes(String key, {Duration? maxAge}) async =>
      readGate == null ? values[key] : readGate!.future;
  @override
  Future<String?> getCachedFilePath(String key, {Duration? maxAge}) async =>
      null;
  @override
  Future<void> saveFile(String key, Uint8List bytes) async {
    values[key] = bytes;
  }

  @override
  Future<bool> hasValidCache(String key, {Duration? maxAge}) async =>
      values.containsKey(key);
  @override
  Future<void> clearCache(String key) async {
    values.remove(key);
  }

  @override
  Future<void> clearAllCache() async {
    values.clear();
  }

  @override
  void invalidateCacheDirectory() {}
  @override
  Future<void> dispose() async {}
}

void main() {
  test(
    'public viewer stays public when a profile appears and policy changes',
    () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final profiles = c.read(booruConfigProvider.notifier) as _Configs;
      final binding = ViewerSourceBinding.publicRead(origin);
      expect(binding.resolve([]), isNull);
      final provider = viewerSourceAccessProvider(binding);
      final subscription = c.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final first = c.read(provider)!;
      final oldScope = first.config!.anonymousReadScope!;
      expect(first.key.profileId, isNull);
      profiles.replace([profile(aId)]);
      expect(oldScope.isCurrent, isFalse);
      final preferred = c.read(contentAccessForOriginProvider(origin))!;
      expect(preferred.key.profileId, aId);
      final next = c.read(provider)!;
      expect(next.key.profileId, isNull);
      expect(next.key, isNot(first.key));
      expect(c.read(contentAccessContextProvider(first.key)), isNull);
      final nextScope = next.config!.anonymousReadScope!;
      c.read(enabled.notifier).state = false;
      expect(nextScope.isCurrent, isFalse);
      expect(c.read(provider), isNull);
      expect(c.read(contentAccessContextProvider(next.key)), isNull);
      c.read(enabled.notifier).state = true;
      final renewed = c.read(provider)!;
      expect(renewed.key.profileId, isNull);
      expect(renewed.key, isNot(next.key));
      expect(c.read(booruConfigProvider), [profile(aId)]);
    },
  );

  test(
    'private viewer pins account and revokes on credential and policy change',
    () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final profiles = c.read(booruConfigProvider.notifier) as _Configs;
      final a = profile(aId);
      final b = profile(bId);
      profiles.replace([a, b]);
      final binding = ViewerSourceBinding(a);
      final provider = viewerSourceAccessProvider(binding);
      final subscription = c.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final first = c.read(provider)!;
      expect(first.key.profileId, aId);
      c.read(policy.notifier).state = 'second';
      final changedPolicy = c.read(provider)!;
      expect(changedPolicy.key.profileId, aId);
      expect(changedPolicy.key, isNot(first.key));
      expect(c.read(contentAccessContextProvider(first.key)), isNull);
      profiles.replace([profile(aId, secret: 'changed'), b]);
      expect(c.read(provider), isNull);
      expect(c.read(contentAccessContextProvider(changedPolicy.key)), isNull);
      profiles.replace([b]);
      expect(c.read(provider), isNull);
      expect(binding.resolve([b]), isNull);
    },
  );

  test('cache scopes separate same-auth profiles, public and unscoped and reject late reads', () async {
    final c = makeContainer();
    addTearDown(c.dispose);
    final profiles = c.read(booruConfigProvider.notifier) as _Configs;
    final a = profile(aId);
    final b = profile(bId);
    expect(a.auth, b.auth);
    profiles.replace([a, b]);
    final aProvider = viewerSourceAccessProvider(ViewerSourceBinding(a));
    final bProvider = viewerSourceAccessProvider(ViewerSourceBinding(b));
    final publicProvider = viewerSourceAccessProvider(
      ViewerSourceBinding.publicRead(origin),
    );
    final bindings = [
      c.listen(aProvider, (_, _) {}),
      c.listen(bProvider, (_, _) {}),
      c.listen(publicProvider, (_, _) {}),
    ];
    addTearDown(() {
      for (final subscription in bindings) {
        subscription.close();
      }
    });
    final aAccess = c.read(aProvider)!;
    final bAccess = c.read(bProvider)!;
    final publicAccess = c.read(publicProvider)!;
    final delegate = _Cache();
    final aManagerProvider = contentMediaCacheManagerProvider((
      manager: delegate,
      access: aAccess.key,
    ));
    final bManagerProvider = contentMediaCacheManagerProvider((
      manager: delegate,
      access: bAccess.key,
    ));
    final publicManagerProvider = contentMediaCacheManagerProvider((
      manager: delegate,
      access: publicAccess.key,
    ));
    final holds = [
      c.listen(aManagerProvider, (_, _) {}),
      c.listen(bManagerProvider, (_, _) {}),
      c.listen(publicManagerProvider, (_, _) {}),
    ];
    addTearDown(() {
      for (final subscription in holds) {
        subscription.close();
      }
    });
    final am = c.read(aManagerProvider);
    final bm = c.read(bManagerProvider);
    final pm = c.read(publicManagerProvider);
    const url = 'https://safebooru.donmai.us/data/image.jpg';
    final ak = am.generateCacheKey(url);
    final bk = bm.generateCacheKey(url);
    final pk = pm.generateCacheKey(url);
    final legacy = delegate.generateCacheKey(url);
    expect({ak, bk, pk, legacy}, hasLength(4));
    await am.saveFile(ak, Uint8List.fromList([1]));
    await bm.saveFile(bk, Uint8List.fromList([2]));
    await pm.saveFile(pk, Uint8List.fromList([3]));
    await delegate.saveFile(legacy, Uint8List.fromList([4]));
    expect(await am.getCachedFileBytes(bk), isNull);
    expect(await bm.getCachedFileBytes(pk), isNull);
    expect(await pm.getCachedFileBytes(legacy), isNull);
    expect(await am.getCachedFileBytes(ak), [1]);
    expect(await bm.getCachedFileBytes(bk), [2]);
    expect(await pm.getCachedFileBytes(pk), [3]);
    final gate = Completer<Uint8List?>();
    delegate.readGate = gate;
    final pending = am.getCachedFileBytes(ak);
    profiles.replace([b]);
    expect(c.read(contentAccessContextProvider(aAccess.key)), isNull);
    gate.complete(Uint8List.fromList([1]));
    expect(await pending, isNull);
    delegate.readGate = null;
    expect(await am.getCachedFileBytes(ak), isNull);
    expect(await bm.getCachedFileBytes(bk), [2]);
  });
}
