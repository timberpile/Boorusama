import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/blacklists/src/types/blacklisted_tag.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/anonymous_access_provider.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/search/following_topics/src/providers/following_topic_config_provider.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/src/pages/following_topics_page.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/following_topic_card.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/topic_follow_control.dart';
import 'package:boorusama/core/search/search/src/types/topic_search_origin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:kurumi/material.dart';

import 'following_topic_test_utils.dart';

const _foreign = '11111111-1111-4111-8111-111111111111';
const _namespace = '22222222-2222-4222-8222-222222222222';
const _first = '33333333-3333-4333-8333-333333333333';
const _second = '44444444-4444-4444-8444-444444444444';
final _enabled = StateProvider((ref) => true);

class _Profiles extends BooruConfigNotifier {
  _Profiles() : super(initialConfigs: []);
  void replace(List<BooruConfig> profiles) => state = profiles;
}

class _Blacklist extends GlobalBlacklistedTagsNotifier {
  @override
  IList<BlacklistedTag> build() => <BlacklistedTag>[].lock;
}

BooruConfig _profile(String id, String url) => BooruConfig.fromJson({
  ...BooruConfig.empty.toJson(),
  'id': id,
  'booruId': BooruType.gelbooruV2.id,
  'booruIdHint': BooruType.gelbooruV2.id,
  'url': url,
});

FollowingTopic _imported(String id, String url, String name) => FollowingTopic(
  id: id,
  profileId: _namespace,
  query: 'cat',
  name: name,
  position: 0,
  createdAt: checkedAt,
  previews: const [],
  recentPostIdentities: const [],
  unreadCount: 2,
  localSource: FollowingTopicSource(
    booruType: 'gelbooruV2',
    url: url,
    importedProfileId: _foreign,
  ),
);

void main() {
  late ProviderContainer container;
  setUp(() {
    container = ProviderContainer(
      overrides: [
        booruConfigProvider.overrideWith(_Profiles.new),
        globalBlacklistedTagsProvider.overrideWith(_Blacklist.new),
        contentEffectivePolicyProvider.overrideWith(
          (ref, id) => const AsyncData('safe'),
        ),
        anonymousSourcePolicyProvider.overrideWith(
          (ref) => AnonymousSourcePolicy(enabled: ref.watch(_enabled)),
        ),
      ],
    );
  });
  tearDown(() => container.dispose());

  test(
    'public import resolves without creating profiles and revokes old access',
    () {
      const url = 'https://safebooru.org';
      final provider = followingSourceConfigProvider((
        profileId: _namespace,
        owner: null,
        localSource: FollowingTopicSource(
          booruType: 'gelbooruV2',
          url: url,
          importedProfileId: _foreign,
          importedProfileName: 'Source',
        ),
      ));
      final lease = container.listen(provider, (_, _) {});
      addTearDown(lease.close);
      final initial = container.read(provider)!;
      expect(initial.anonymousReadScope?.isCurrent, isTrue);
      expect(initial.auth.apiKey, isNull);
      expect(initial.auth.login, isNull);
      expect(container.read(booruConfigProvider), isEmpty);

      final profiles =
          container.read(booruConfigProvider.notifier) as _Profiles;
      profiles.replace([_profile(_first, url)]);
      expect(container.read(provider)?.id, _first);
      expect(initial.anonymousReadScope?.isCurrent, isFalse);

      profiles.replace([_profile(_first, url), _profile(_second, url)]);
      expect(container.read(provider)?.anonymousReadScope, isNotNull);
      profiles.replace([]);
      final renewed = container.read(provider)!;
      expect(renewed.anonymousReadScope?.isCurrent, isTrue);
      container.read(_enabled.notifier).state = false;
      expect(container.read(provider), isNull);
      expect(renewed.anonymousReadScope?.isCurrent, isFalse);
      expect(container.read(booruConfigProvider), isEmpty);
    },
  );

  test(
    'private imports need a unique exact-site actor, not a matching UUID',
    () {
      const url = 'https://private.example/first';
      final provider = followingSourceConfigProvider((
        profileId: _namespace,
        owner: null,
        localSource: FollowingTopicSource(
          booruType: 'gelbooruV2',
          url: url,
          importedProfileId: _foreign,
        ),
      ));
      final lease = container.listen(provider, (_, _) {});
      addTearDown(lease.close);
      final profiles =
          container.read(booruConfigProvider.notifier) as _Profiles;
      expect(container.read(provider), isNull);
      profiles.replace([_profile(_foreign, 'https://private.example/second')]);
      expect(container.read(provider), isNull);
      profiles.replace([_profile(_first, url)]);
      expect(container.read(provider)?.id, _first);
      profiles.replace([_profile(_foreign, url), _profile(_second, url)]);
      expect(container.read(provider), isNull);
      profiles.replace([]);
      expect(container.read(provider), isNull);
    },
  );

  testWidgets(
    'An unavailable imported Topic stays visible with NEW and zero profiles',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final harness = FollowingTopicHarness(profiles: const []);
      addTearDown(harness.dispose);
      final topic = _imported(
        _first,
        'https://private.example/installation',
        'Private cats',
      );
      await tester.runAsync(() async {
        await harness.seed([topic]);
        await harness.container.read(followingTopicsProvider.future);
      });
      await harness.pump(tester, const FollowingTopicsPage());
      expect(
        find.textContaining(
          'No reader for https://private.example/installation',
        ),
        findsOneWidget,
      );
      expect(find.text('Profiles'), findsOneWidget);
      final card = find.byType(FollowingTopicCard);
      expect(tester.widget<FollowingTopicCard>(card).onOpen, isNull);
      expect(
        tester.widget<FollowingTopicCard>(card).topic.hasNewPosts,
        isTrue,
      );
      expect(
        harness.container.read(followingTopicHasNewPostsProvider),
        isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'editing a retained definition leaves its source and storage owner intact',
    () async {
      final harness = FollowingTopicHarness(profiles: const []);
      addTearDown(harness.dispose);
      final topic = _imported(
        _first,
        'https://private.example/installation',
        'Private cats',
      );
      await harness.seed([topic]);
      await harness.container.read(followingTopicsProvider.future);
      final result = await harness.container
          .read(followingTopicsProvider.notifier)
          .edit(
            topic.id,
            profileId: topic.profileId,
            query: 'bird rating:safe',
            name: 'Private birds',
          );
      expect(result.refresh, isNull);
      expect(result.topic.name, 'Private birds');
      expect(result.topic.query, 'bird rating:safe');
      expect(result.topic.profileId, topic.profileId);
      expect(result.topic.localSource, topic.localSource);
      expect(harness.requests, isEmpty);
    },
  );

  test(
    'global NEW badges include a public imported member alongside an unavailable Topic',
    () async {
      final harness = FollowingTopicHarness(
        profiles: const [],
        overrides: [
          globalBlacklistedTagsProvider.overrideWith(_Blacklist.new),
          contentEffectivePolicyProvider.overrideWith(
            (ref, id) => const AsyncData('safe'),
          ),
          anonymousSourcePolicyProvider.overrideWith(
            (ref) => AnonymousSourcePolicy(enabled: ref.watch(_enabled)),
          ),
        ],
      );
      addTearDown(harness.dispose);
      final public = _imported(_first, 'https://safebooru.org', 'Public cats');
      final private = _imported(
        _second,
        'https://private.example',
        'Private cats',
      );
      final folder = TopicFolder(
        id: _foreign,
        name: 'Mixed folder',
        feedEnabled: true,
        searchIds: [public.id, private.id],
      );
      await harness.seed([public, private]);
      await harness.repository.replaceOrganization(
        TopicOrganization(folders: [folder]),
      );
      await harness.repository.ensureFolderFeed(folder.id);
      await harness.container.read(followingTopicsProvider.future);
      final members = harness.container
          .read(organizedFollowingTopicsProvider(folder.id))
          .requireValue;
      expect(members.map((topic) => topic.id), [public.id, private.id]);
      expect(harness.container.read(followingTopicHasNewPostsProvider), isTrue);
      expect(harness.container.read(topicFeedHasNewPostsProvider), isTrue);
      harness.container.read(_enabled.notifier).state = false;
      expect(
        harness.container.read(followingTopicHasNewPostsProvider),
        isFalse,
      );
      expect(harness.container.read(topicFeedHasNewPostsProvider), isFalse);
      expect(
        (await harness.repository.getById(public.id))!.hasNewPosts,
        isTrue,
      );
    },
  );

  testWidgets('the profile filter uses the current saved reader', (
    tester,
  ) async {
    final profile = _profile(_foreign, 'https://private.example/installation');
    final harness = FollowingTopicHarness(profiles: [profile]);
    addTearDown(harness.dispose);
    final matched = _imported(_first, profile.url, 'Compatible site');
    final unmatched = _imported(
      _second,
      'https://private.example/other',
      'Other installation',
    );
    await tester.runAsync(() async {
      await harness.seed([matched, unmatched]);
      await harness.container.read(followingTopicsProvider.future);
    });
    await harness.pump(tester, const FollowingTopicsPage());
    expect(find.text('Compatible site'), findsOneWidget);
    expect(find.text('Other installation'), findsOneWidget);
    await tester.tap(find.byTooltip('Search'));
    await settle(tester);
    await tester.tap(find.byType(DropdownButton<String?>));
    await settle(tester);
    await tester.tap(
      find
          .byWidgetPredicate(
            (widget) =>
                widget is DropdownMenuItem<String?> &&
                widget.value == profile.id,
          )
          .last,
    );
    await settle(tester);
    expect(find.text('Compatible site'), findsOneWidget);
    expect(find.text('Other installation'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'originating Following manages only the imported Topic via its current reader',
    (tester) async {
      final profile = _profile(
        _foreign,
        'https://private.example/installation',
      );
      final harness = FollowingTopicHarness(profiles: [profile]);
      addTearDown(harness.dispose);
      final imported = _imported(_first, profile.url, 'Imported');
      final folder = TopicFolder(
        id: _second,
        name: 'New destination',
      );
      await tester.runAsync(() async {
        await harness.seed([
          imported,
          topicFixture(id: 'saved', profileId: profile.id, query: 'cat'),
        ]);
        await harness.repository.replaceOrganization(
          TopicOrganization(
            folders: [folder],
            homeSearchIds: [imported.id, 'saved'],
          ),
        );
        await harness.container.read(followingTopicsProvider.future);
      });
      harness.container
          .read(selectedTestProfileProvider.notifier)
          .select(profile);
      await harness.pump(
        tester,
        Scaffold(
          body: FollowTopicButton(
            query: imported.query,
            originatingTopicId: imported.id,
            original: TopicSearchOrigin(topic: imported, profile: profile),
            showCount: false,
          ),
        ),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Following'));
      await settle(tester);
      await tester.tap(find.text('New destination'));
      await tester.tap(find.text('Done'));
      await drain(tester);
      final organization = await harness.repository.getOrganization();
      expect(organization.folders.single.searchIds, [imported.id]);
      expect(organization.homeSearchIds, ['saved']);
      expect(
        (await harness.repository.getById(imported.id))?.localSource,
        imported.localSource,
      );
    },
  );

  test('legacy local copies keep their chosen account binding', () {
    const url = 'https://private.example/first';
    final provider = followingSourceConfigProvider((
      profileId: _first,
      owner: null,
      localSource: FollowingTopicSource(booruType: 'gelbooruV2', url: url),
    ));
    final lease = container.listen(provider, (_, _) {});
    addTearDown(lease.close);
    final profiles = container.read(booruConfigProvider.notifier) as _Profiles;
    profiles.replace([_profile(_first, url), _profile(_second, url)]);
    expect(container.read(provider)?.id, _first);
    profiles.replace([_profile(_second, url)]);
    expect(container.read(provider), isNull);
  });
}
