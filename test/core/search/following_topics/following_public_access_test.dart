import 'package:boorusama/core/search/following_topics/types.dart';

import 'dart:async';

import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/blacklists/src/types/blacklisted_tag.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/anonymous_access_provider.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/following_topics/src/providers/following_topic_config_provider.dart';
import 'package:boorusama/core/search/following_topics/src/providers/untracked_topic_preview_provider.dart';
import 'package:boorusama/core/search/following_topics/src/types/following_mirror_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import 'topic_test_utils.dart';

const publisher = '11111111-1111-4111-8111-111111111111';
const topic = '22222222-2222-4222-8222-222222222222';
const first = '33333333-3333-4333-8333-333333333333';
const second = '44444444-4444-4444-8444-444444444444';
final enabled = StateProvider((ref) => true);

FollowingMirrorOwner owner({
  String url = 'https://safebooru.org',
  String engine = 'gelbooruV2',
}) => FollowingMirrorOwner(
  publisher: publisher,
  source: topic,
  kind: FollowingMirrorKind.topic,
  revision: 1,
  payloadDigest: 'a' * 64,
  descriptorDigest: 'b' * 64,
  definitionDigest: 'c' * 64,
  profile: {'id': first, 'booruType': engine, 'url': url, 'name': 'Sender'},
);
BooruConfig profile(String id) => BooruConfig.fromJson({
  ...BooruConfig.empty.toJson(),
  'id': id,
  'booruId': BooruType.gelbooruV2.id,
  'booruIdHint': BooruType.gelbooruV2.id,
  'url': 'https://safebooru.org',
  'login': 'fixture-account',
  'apiKey': 'fixture-key',
});

class _Profiles extends BooruConfigNotifier {
  _Profiles() : super(initialConfigs: []);
  void replace(List<BooruConfig> profiles) => state = profiles;
}

class _Blacklist extends GlobalBlacklistedTagsNotifier {
  @override
  IList<BlacklistedTag> build() => <BlacklistedTag>[].lock;
  void loading() => state = const AsyncLoading();
  void blockGeneral() => state = AsyncData(
    [
      BlacklistedTag(
        id: 1,
        name: 'rating:general',
        isActive: true,
        createdDate: DateTime.utc(2026),
        updatedDate: DateTime.utc(2026),
      ),
    ].lock,
  );
}

void main() {
  late ProviderContainer container;
  late Completer<List<Post>> response;
  late List<BooruConfig> requests;
  setUp(() {
    response = Completer<List<Post>>();
    requests = [];
    container = ProviderContainer(
      overrides: [
        automaticMediaLoadingEnabledProvider.overrideWithValue(true),
        originAwarePostRepoProvider.overrideWith((ref, config) {
          requests.add(config);
          return TestSearchPostRepository((query, page, limit) async {
            expect((query, page, limit), ('cat', 1, 4));
            return Either.of(
              PostResult(posts: await response.future, total: 2),
            );
          });
        }),
        booruConfigProvider.overrideWith(_Profiles.new),
        globalBlacklistedTagsProvider.overrideWith(_Blacklist.new),
        contentEffectivePolicyProvider.overrideWith(
          (ref, id) => const AsyncData('safe'),
        ),
        anonymousSourcePolicyProvider.overrideWith(
          (ref) => AnonymousSourcePolicy(enabled: ref.watch(enabled)),
        ),
      ],
    );
  });
  tearDown(() => container.dispose());
  UntrackedTopicPreviewKey previewKey(BooruConfig config) => (
    config: config,
    query: 'cat',
    structure: null,
    revision: 0,
    attemptedAt: null,
  );
  Post preview(String url) {
    final original = testSearchPost(1, null);
    return original.copyWith(
      origin: PostOrigin.fromSource(
        booruType: BooruType.gelbooruV2,
        booruId: BooruType.gelbooruV2.id,
        source: 'https://safebooru.org',
      ),
      core: PostCoreData.fromPost(original, thumbnailImageUrl: url),
    );
  }

  test('an independent copy retains its explicit account binding without switching to another account', () {
    final profiles = container.read(booruConfigProvider.notifier) as _Profiles;
    BooruConfig privateProfile(String id) => BooruConfig.fromJson({
      ...profile(id).toJson(),
      'url': 'https://private.example',
    });
    final source = FollowingTopicSource(
      booruType: 'gelbooruV2',
      url: 'https://private.example',
    );
    final provider = followingSourceConfigProvider((
      profileId: first,
      owner: null,
      localSource: source,
    ));
    final keep = container.listen(provider, (_, _) {});
    addTearDown(keep.close);
    profiles.replace([privateProfile(first), privateProfile(second)]);
    expect(container.read(provider)?.id, first);
    profiles.replace([privateProfile(second)]);
    expect(container.read(provider), isNull);
    profiles.replace([profile(first)]);
    expect(container.read(provider), isNull);
  });
  test(
    'an independent public source does not adopt a later account implicitly',
    () {
      final provider = followingSourceConfigProvider((
        profileId: topic,
        owner: null,
        localSource: FollowingTopicSource(
          booruType: 'gelbooruV2',
          url: 'https://safebooru.org',
        ),
      ));
      final keep = container.listen(provider, (_, _) {});
      addTearDown(keep.close);
      (container.read(booruConfigProvider.notifier) as _Profiles).replace([
        profile(first),
      ]);
      final config = container.read(provider)!;
      expect(config.anonymousReadScope?.isCurrent, isTrue);
      expect(config.auth.apiKey, isNull);
      expect(config.auth.login, isNull);
    },
  );
  for (final copied in [false, true]) {
    ({
      String profileId,
      FollowingMirrorOwner? owner,
      FollowingTopicSource? localSource,
    })
    request(FollowingMirrorOwner origin) => (
      profileId: topic,
      owner: copied ? null : origin,
      localSource: copied
          ? FollowingTopicSource.fromJson(origin.profile!)
          : null,
    );
    test(
      'public previews enforce media hosts and current global blacklist',
      () async {
        final access = followingSourceConfigProvider(request(owner()));
        final keep = container.listen(access, (_, _) {});
        addTearDown(keep.close);
        final config = container.read(access)!;
        final allowed = preview('https://wimg.safebooru.org/images/1.jpg');
        response.complete([allowed, preview('https://unlisted.example/2.jpg')]);
        expect(
          await container.read(
            untrackedTopicPreviewProvider(previewKey(config)).future,
          ),
          [allowed.thumbnailImageUrl],
        );
        expect(requests.single.auth.login, isNull);
        expect(requests.single.auth.apiKey, isNull);
        (container.read(globalBlacklistedTagsProvider.notifier) as _Blacklist)
            .blockGeneral();
        expect(config.anonymousReadScope!.isCurrent, isFalse);
        final renewed = container.read(access)!;
        expect(
          await container.read(
            untrackedTopicPreviewProvider(previewKey(renewed)).future,
          ),
          isEmpty,
        );
        expect(container.read(booruConfigProvider), isEmpty);
      },
    );

    test(
      'in-flight public preview cannot expose results after revocation',
      () async {
        final access = followingSourceConfigProvider(request(owner()));
        final keep = container.listen(access, (_, _) {});
        addTearDown(keep.close);
        final config = container.read(access)!;
        final result = container.read(
          untrackedTopicPreviewProvider(previewKey(config)).future,
        );
        expect(requests, hasLength(1));
        container.read(enabled.notifier).state = false;
        expect(config.anonymousReadScope!.isCurrent, isFalse);
        response.complete([preview('https://wimg.safebooru.org/images/1.jpg')]);
        expect(await result, isEmpty);
        expect(container.read(access), isNull);
      },
    );
    test('zero profiles opens allowed source without creating an account or credentials', () {
      final config = container.read(
        followingSourceConfigProvider(request(owner())),
      )!;
      expect(config.anonymousReadScope!.isCurrent, isTrue);
      expect(config.auth.apiKey, isNull);
      expect(config.auth.login, isNull);
      expect(config.proxySettings, isNull);
      expect(config.networkSettings, isNull);
      expect(container.read(booruConfigProvider), isEmpty);
    });
    if (!copied) {
      test(
        'a unique compatible profile wins; duplicate accounts use public authority',
        () {
          final profiles =
              container.read(booruConfigProvider.notifier) as _Profiles;
          profiles.replace([profile(first)]);
          final accessRequest = request(owner());
          final provider = followingSourceConfigProvider(accessRequest);
          final keep = container.listen(provider, (_, _) {});
          addTearDown(keep.close);
          expect(container.read(provider)!.id, first);
          expect(container.read(provider)!.anonymousReadScope, isNull);
          profiles.replace([profile(first), profile(second)]);
          final config = container.read(provider)!;
          expect(config.anonymousReadScope, isNotNull);
          expect(config.auth.apiKey, isNull);
          expect(container.read(booruConfigProvider), hasLength(2));
        },
      );
    }
    test(
      'source change and public policy revocation never reuse a previous grant',
      () {
        final provider = followingSourceConfigProvider(request(owner()));
        final keep = container.listen(provider, (_, _) {});
        addTearDown(keep.close);
        final config = container.read(provider)!;
        expect(
          container.read(
            followingSourceConfigProvider(
              request(owner(url: 'https://unlisted.example')),
            ),
          ),
          isNull,
        );
        expect(
          container.read(
            followingSourceConfigProvider(
              request(owner(url: 'https://pixiv.net', engine: 'pixiv')),
            ),
          ),
          isNull,
        );
        container.read(enabled.notifier).state = false;
        expect(config.anonymousReadScope!.isCurrent, isFalse);
        expect(container.read(provider), isNull);
        container.read(enabled.notifier).state = true;
        final renewed = container.read(provider)!;
        expect(
          renewed.anonymousReadScope!.key,
          isNot(config.anonymousReadScope!.key),
        );
        (container.read(globalBlacklistedTagsProvider.notifier) as _Blacklist)
            .loading();
        expect(renewed.anonymousReadScope!.isCurrent, isFalse);
        expect(container.read(provider), isNull);
      },
    );
  }
}
