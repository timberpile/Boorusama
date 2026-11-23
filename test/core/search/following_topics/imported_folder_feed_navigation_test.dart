import 'package:boorusama/core/backups/sources/following_topic_backup_data.dart';
import 'package:boorusama/core/backups/sources/following_topic_import_service.dart';
import 'package:boorusama/core/backups/sources/search_backup_profile.dart';
import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/cache/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/navigation/destination_activity.dart';
import 'package:boorusama/core/navigation/destination_id.dart';
import 'package:boorusama/core/navigation/destination_profile_scope.dart';
import 'package:boorusama/core/navigation/destination_router.dart';
import 'package:boorusama/core/navigation/navigation_controller.dart';
import 'package:boorusama/core/navigation/navigation_route_catalog.dart';
import 'package:boorusama/core/navigation/page_presentation_profile.dart';
import 'package:boorusama/core/navigation/page_source_context.dart';
import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/routes.dart';
import 'package:boorusama/core/search/following_topics/src/pages/following_topics_page.dart';
import 'package:boorusama/core/search/following_topics/src/pages/topic_feeds_page.dart';
import 'package:boorusama/core/search/following_topics/src/providers/following_topic_config_provider.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/following_topic_folder_card.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../support/fakes/memory_repositories.dart';
import 'following_topic_test_utils.dart';

const _following = DestinationId.app(AppDestination.following);
const _importedName = 'Imported';
const _folderId = '44444444-4444-4444-8444-444444444444';
const _publicId = '22222222-2222-4222-8222-222222222222';
const _privateId = '33333333-3333-4333-8333-333333333333';
const _publicSource = BackupProfileReference(
  id: '11111111-1111-4111-8111-111111111111',
  booruType: 'gelbooruV2',
  url: 'https://safebooru.org',
  name: 'Public source',
);
const _privateSource = BackupProfileReference(
  id: '55555555-5555-4555-8555-555555555555',
  booruType: 'gelbooruV2',
  url: 'https://private.example/installation',
  name: 'Private source',
);

void main() {
  for (final (scenario, profiles) in [
    ('no saved profiles', <BooruConfig>[]),
    ('an unrelated saved profile', [testProfile]),
  ]) {
    testWidgets(
      'imported public folder opens with $scenario before and after toggling Feed',
      (tester) async {
        final harness = _harness(profiles);
        final folder = await _importFolder(harness);
        final imported = (await harness.repository.getAll()).single;
        expect(imported.localSource?.url, _publicSource.url);
        expect(
          profiles.map((profile) => profile.id),
          isNot(contains(imported.profileId)),
        );

        await _mountFollowing(
          tester,
          harness,
          browseProfile: profiles.firstOrNull,
        );
        await _openImportWrapper(tester);
        final topics = harness.container.read(followingTopicsProvider.notifier);
        Future<void> openPublicFeed() async {
          final scope = await _openFeed(tester, folder);
          final reader = scope.read(followingTopicConfigProvider(imported.id));
          expect(reader?.anonymousReadScope?.isCurrent, isTrue);
          expect(reader?.auth.login, isNull);
          expect(reader?.auth.apiKey, isNull);
          expect(
            find.text('No posts yet. Topics update gradually.'),
            findsOneWidget,
          );
          await _backToFollowing(tester);
        }

        await openPublicFeed();
        await topics.setSharedFolderFeedOptions(folder.id, enabled: false);
        await tester.pumpAndSettle();
        expect(_openFeedButton(folder.name), findsNothing);
        await topics.setSharedFolderFeedOptions(folder.id, enabled: true);
        await tester.pumpAndSettle();
        await openPublicFeed();

        expect(harness.container.read(booruConfigProvider), profiles);
        expect(
          (await harness.repository.getById(imported.id))?.profileId,
          imported.profileId,
        );
        expect(harness.requests, isEmpty);
      },
    );
  }

  testWidgets(
    'a mixed folder opens independently of member order and reader changes',
    (
      tester,
    ) async {
      final profileStore = MemoryBooruConfigRepository();
      final harness = _harness([], profileStore: profileStore);
      final folder = await _importFolder(harness, mixed: true);
      final imported = {
        for (final topic in await harness.repository.getAll()) topic.id: topic,
      };
      final privateOwner = imported[_privateId]!.profileId;
      final publicOwner = imported[_publicId]!.profileId;
      expect(privateOwner, isNot(publicOwner));
      await _mountFollowing(tester, harness);
      await _openImportWrapper(tester);

      final first = await _openFeed(tester, folder);
      expect(first.read(followingTopicConfigProvider(_privateId)), isNull);
      final anonymous = first.read(followingTopicConfigProvider(_publicId))!;
      expect(anonymous.anonymousReadScope?.isCurrent, isTrue);
      expect(
        first.read(followingTopicsProvider).requireValue.feeds.single.profileId,
        privateOwner,
      );
      await _backToFollowing(tester);

      await harness.container
          .read(followingTopicsProvider.notifier)
          .reorderSharedTopics(folder.id, 0, 1);
      await tester.pumpAndSettle();
      final reordered = await _openFeed(tester, folder);
      final feed = reordered
          .read(followingTopicsProvider)
          .requireValue
          .feeds
          .single;
      expect(feed.sourceIds, [_publicId, _privateId]);
      expect(feed.profileId, publicOwner);
      expect(reordered.read(followingTopicConfigProvider(_privateId)), isNull);
      await _backToFollowing(tester);

      final matchingReader = BooruConfig.fromJson({
        ...BooruConfig.empty.toJson(),
        'id': _publicSource.id,
        'booruId': BooruType.gelbooruV2.id,
        'booruIdHint': BooruType.gelbooruV2.id,
        'url': _publicSource.url,
      });
      await profileStore.addAll([matchingReader]);
      await harness.container.read(booruConfigProvider.notifier).fetch();
      await tester.pumpAndSettle();
      final matched = await _openFeed(tester, folder);
      expect(
        matched.read(followingTopicConfigProvider(_publicId))?.id,
        matchingReader.id,
      );
      expect(matched.read(followingTopicConfigProvider(_privateId)), isNull);
      expect(anonymous.anonymousReadScope?.isCurrent, isFalse);
      expect(
        (await harness.repository.getById(_publicId))?.profileId,
        publicOwner,
      );
      expect(harness.requests, isEmpty);
      await _backToFollowing(tester);
    },
  );

  testWidgets(
    'ordinary local folders open with or without members and return to Following',
    (
      tester,
    ) async {
      final harness = _harness([testProfile]);
      await harness.seed([topicFixture()]);
      final topics = harness.container.read(followingTopicsProvider.notifier);
      final populated = await topics.createSharedFolder(
        'Local folder',
        feedEnabled: true,
      );
      await topics.moveTopicToSharedFolder('cats', populated.id);
      final empty = await topics.createSharedFolder(
        'Empty folder',
        feedEnabled: true,
      );
      await _mountFollowing(tester, harness);
      for (final folder in [populated, empty]) {
        await _openFeed(tester, folder);
        expect(
          find.text('No posts yet. Topics update gradually.'),
          findsOneWidget,
        );
        await _backToFollowing(tester);
      }
    },
  );
}

FollowingTopicHarness _harness(
  List<BooruConfig> profiles, {
  MemoryBooruConfigRepository? profileStore,
}) {
  final harness = FollowingTopicHarness(
    profiles: profiles,
    profileRepository: profileStore,
    overrides: [
      miscDataStoreProvider.overrideWithValue(MemoryMiscDataStore()),
      globalBlacklistedTagRepoProvider.overrideWith(
        (_) => Future.value(MemoryGlobalBlacklistedTagRepository()),
      ),
    ],
  );
  addTearDown(harness.dispose);
  return harness;
}

Future<TopicFolder> _importFolder(
  FollowingTopicHarness harness, {
  bool mixed = false,
}) async {
  await FollowingTopicImportService(repository: harness.repository).apply(
    FollowingTopicBackupData(
      records: [
        if (mixed)
          const FollowingTopicBackupRecord(
            id: _privateId,
            name: 'Private birds',
            query: 'bird',
            position: 0,
            profile: _privateSource,
            autoUpdateEnabled: false,
          ),
        FollowingTopicBackupRecord(
          id: _publicId,
          name: 'Public cats',
          query: 'cat',
          position: mixed ? 1 : 0,
          profile: _publicSource,
          autoUpdateEnabled: false,
        ),
      ],
      folders: [
        FollowingTopicFolderBackupRecord(
          id: _folderId,
          name: _importedName,
          position: 0,
          searchIds: [if (mixed) _privateId, _publicId],
          feedEnabled: true,
        ),
      ],
    ),
    profiles: harness.container.read(booruConfigProvider),
  );
  final organization = await harness.repository.getOrganization();
  return organization.folders.singleWhere(
    (folder) => folder.name == _importedName,
  );
}

Future<void> _mountFollowing(
  WidgetTester tester,
  FollowingTopicHarness harness, {
  BooruConfig? browseProfile,
}) async {
  tester.view.physicalSize = const Size(320, 800);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await ensureI18nInitialized('en-US');
  await harness.container.read(globalBlacklistedTagsProvider.future);
  await harness.container.read(followingTopicsProvider.future);
  final browse = browseProfile == null
      ? null
      : DestinationId.browse(browseProfile.id);
  final templates = [followingTopicRoutes];
  late final DestinationRouterBinding binding;
  binding = DestinationRouterBinding(
    definitions: [
      if (browse != null)
        DestinationRouteDefinition(
          id: browse,
          builder: (_, _) => const Scaffold(body: Text('Browse')),
        ),
      DestinationRouteDefinition(
        id: _following,
        builder: (_, _) => const FollowingTopicsPage(),
        children: destinationChildRoutes(_following, templates),
      ),
    ],
    ingressRoutes: [
      for (final (path, template) in flattenNavigationRoutes(templates))
        GoRoute(
          path: '/$path',
          name: template.name,
          redirect: (_, state) => '${_following.location}${state.uri}',
        ),
    ],
    shellBuilder: (_, _, shell) => shell,
    navigatorWrapper: (_, id, selected, child) => DestinationScope(
      id: id,
      active: selected,
      child: ProviderScope(
        overrides: [
          currentDestinationRouteObserverProvider.overrideWithValue(
            binding.observerFor(id)!,
          ),
          pagePresentationProfileProvider.overrideWithValue(null),
        ],
        child: id == browse
            ? DestinationProfileScope(profileId: id.profileId!, child: child)
            : child,
      ),
    ),
  );
  final router = harness.router = GoRouter.routingConfig(
    routingConfig: binding.routingConfig,
    initialLocation: (browse ?? _following).location,
  );
  binding.attach(router);
  final controller = harness.container.read(
    navigationControllerProvider.notifier,
  );
  controller.binding = binding;
  addTearDown(() {
    controller.binding = null;
    router.dispose();
    binding.dispose();
  });
  await tester.pumpWidget(
    harness.wrap(
      MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(extensions: const [KurumiExtendedColorScheme()]),
        builder: themeBuilder,
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (browse != null) {
    expect(
      _scope(
        tester,
        find.text('Browse'),
      ).read(explicitPageSourceProvider)?.profileId,
      browse.profileId,
    );
    expect(await controller.selectDestination(_following), isTrue);
    await tester.pumpAndSettle();
  }
  expect(binding.currentDestination, _following);
  expect(
    _scope(
      tester,
      find.byType(FollowingTopicsPage),
    ).read(explicitPageSourceProvider),
    isNull,
  );
}

Finder _openFeedButton(String name) => find.descendant(
  of: find.ancestor(
    of: find.text(name),
    matching: find.byType(FollowingTopicFolderCard),
  ),
  matching: find.byTooltip('Open Feed'),
);

ProviderContainer _scope(WidgetTester tester, Finder finder) =>
    ProviderScope.containerOf(tester.element(finder), listen: false);

Future<ProviderContainer> _openFeed(
  WidgetTester tester,
  TopicFolder folder,
) async {
  await tester.tap(_openFeedButton(folder.name));
  await tester.pumpAndSettle();
  final page = find.byType(TopicFeedPage);
  expect(page, findsOneWidget);
  final uri = GoRouterState.of(tester.element(page)).uri;
  expect(
    uri.path,
    '${_following.location}/following-topics/feeds/${folder.id}',
  );
  expect(uri.queryParameters, isEmpty);
  expect(find.text(folder.name), findsOneWidget);
  final scope = _scope(tester, page);
  expect(scope.read(explicitPageSourceProvider), isNull);
  return scope;
}

Future<void> _openImportWrapper(WidgetTester tester) async {
  await tester.tap(find.text('Imported Searches'));
  await tester.pumpAndSettle();
}

Future<void> _backToFollowing(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pumpAndSettle();
  expect(find.byType(TopicFeedPage), findsNothing);
  expect(find.byType(FollowingTopicsPage), findsOneWidget);
}
