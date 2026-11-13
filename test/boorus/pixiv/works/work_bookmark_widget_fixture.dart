import 'dart:async';
import 'dart:io';

import 'package:boorusama/boorus/pixiv/posts/post_codec.dart';
import 'package:boorusama/boorus/pixiv/works/work_mapper.dart';
import 'package:boorusama/boorus/pixiv/works/work_presentation.dart';
import 'package:boorusama/core/bookmarks/providers.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_group_repository.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/data/providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/recent_bookmark_groups_provider.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_storage_migration.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/groups/group_capability.dart';
import 'package:boorusama/core/content/groups/group_source_provider.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/navigation/destination_activity.dart';
import 'package:boorusama/core/posts/details/src/providers/media_group_provider.dart';
import 'package:boorusama/core/posts/details/src/types/inherited_post.dart';
import 'package:boorusama/core/posts/details/src/types/post_presentation_context.dart';
import 'package:boorusama/core/posts/details/src/types/viewer_entry.dart';
import 'package:boorusama/core/posts/details/src/widgets/media_group_actions.dart';
import 'package:boorusama/core/posts/details_parts/src/toolbars/simple_post_action_toolbar.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/core/themes/colors/src/colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:oktoast/oktoast.dart';

import '../../../support/fakes/bookmark_test_storage.dart';
import 'work_test_fixtures.dart';

GroupBookmarkPresentationData bookmarkData(
  ContentAccessContext access, {
  int id = 120,
  int? pageCount = 3,
  int? page = 2,
}) {
  final dto = work(id: id, pageCount: pageCount);
  return GroupBookmarkPresentationData(
    access: access,
    summary: pixivWorkSummary(dto, access),
    details: pixivWorkDetails(dto, access),
    page: page == null ? null : pixivWorkPagePosts(dto, access)[page],
  );
}

Future<void> saveBookmark(
  WidgetTester tester,
  WorkBookmarkWidgetFixture fixture,
) => commitBookmarkInteraction(
  tester,
  fixture,
  () => tester.tap(
    find.byKey(ValueKey(('bookmark-picker-group', fixture.destinationId))),
  ),
);

Future<void> commitBookmarkInteraction(
  WidgetTester tester,
  WorkBookmarkWidgetFixture fixture,
  Future<void> Function() action,
) async {
  final revision = fixture.container.read(bookmarkProvider).requireValue.revision;
  final completed = Completer<void>();
  final listener = fixture.container.listen(bookmarkProvider, (_, next) {
    if (!completed.isCompleted &&
        next.valueOrNull != null &&
        next.requireValue.revision != revision) {
      completed.complete();
    }
  });
  try {
    // Hive uses real I/O. Wait for the production notifier's commit signal,
    // not a host-speed sleep; the timeout is only a bounded hang guard.
    await tester.runAsync(() async {
      await action();
      await completed.future.timeout(const Duration(seconds: 30));
    });
  } finally {
    listener.close();
  }
  dismissAllToast(showAnim: false);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

class WorkBookmarkWidgetFixture {
  WorkBookmarkWidgetFixture({
    required this.container,
    required this.repository,
    required this.groups,
    required this.destinationId,
    required this.access,
    required this.current,
    required this.data,
    required this.active,
  });
  final ProviderContainer container;
  final BookmarkHiveRepository repository;
  final UnifiedBookmarkGroupRepository groups;
  final String destinationId;
  final ContentAccessContext access;
  final StateProvider<ContentAccessContext?> current;
  final ValueNotifier<GroupBookmarkPresentationData?> data;
  final ValueNotifier<bool> active;
}

Future<WorkBookmarkWidgetFixture> mountWorkBookmarks(
  WidgetTester tester, {
  bool narrow = false,
}) async {
  final directory = (await tester.runAsync(
    () => Directory.systemTemp.createTemp('pixiv-bookmark-ui-'),
  ))!;
  Hive.init(directory.path);
  if (!Hive.isAdapterRegistered(4)) {
    Hive.registerAdapter(BookmarkHiveObjectAdapter());
  }
  if (!Hive.isAdapterRegistered(5)) {
    Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
  }
  final access = workAccess();
  final current = StateProvider<ContentAccessContext?>((ref) => access);
  final data = ValueNotifier<GroupBookmarkPresentationData?>(bookmarkData(access));
  final active = ValueNotifier(true);
  final observer = RouteObserver<ModalRoute<dynamic>>();
  final fixture = (await tester.runAsync(() async {
    final posts = await Hive.openBox<BookmarkHiveObject>('posts');
    final legacyGroups = await Hive.openBox<BookmarkGroupHiveObject>('groups');
    final organization = await Hive.openBox<dynamic>('organization');
    final storage = await BookmarkTestStorage.open(posts);
    final repository = storage.repository(
      posts,
      postDataCodec: (_) => const PixivPostCodec(),
    );
    final reader = await BookmarkStorageMigration(
      bookmarks: repository,
      legacyGroups: legacyGroups,
      legacyOrganization: organization,
      metadata: storage.metadataBox,
    ).open();
    final groups = UnifiedBookmarkGroupRepository(
      bookmarks: repository,
      reader: reader,
    );
    final destination = await groups.createGroup('Destination');
    final container = ProviderContainer(overrides: [
      ...storage.overrides,
      booruEngineRegistryProvider.overrideWithValue(_CodecRegistry()),
      postLinkGeneratorProvider.overrideWith(
        (ref, config) => const NoLinkPostLinkGenerator(),
      ),
      bookmarkRepoProvider.overrideWith((ref) async => repository),
      bookmarkGroupRepoProvider.overrideWith((ref) async => groups),
      bookmarkUrlResolverProvider.overrideWith(
        (ref, id) => const DefaultImageUrlResolver(),
      ),
      booruConfigProvider.overrideWith(
        () => BooruConfigNotifier(initialConfigs: [access.config!]),
      ),
      settingsNotifierProvider.overrideWith(
        () => SettingsNotifier(Settings.defaultSettings),
      ),
      contentAccessContextProvider.overrideWith((ref, key) {
        final config = ref.watch(booruConfigProvider)
            .where((c) => c.id == key.profileId).firstOrNull;
        final value = ref.watch(current);
        return config != null && value?.key == key ? value : null;
      }),
      recentBookmarkGroupsProvider.overrideWith((ref) async => []),
      currentDestinationRouteObserverProvider.overrideWithValue(observer),
      booruGroupCapabilityProvider.overrideWith(
        (ref, engine) => createPixivGroupCapability(ref),
      ),
      mediaGroupProvider.overrideWith((ref, entry) => MediaGroupState(
        access: ref.watch(contentAccessContextProvider(access.key)),
        details: entry.storedDetails,
      )),
    ]);
    await container.read(bookmarkProvider.future);
    return WorkBookmarkWidgetFixture(
      container: container,
      repository: repository,
      groups: groups,
      destinationId: destination.id,
      access: access,
      current: current,
      data: data,
      active: active,
    );
  }))!;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(narrow ? 320 : 400, 800);
  addTearDown(() async {
    dismissAllToast(showAnim: false);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    fixture.container.dispose();
    data.dispose();
    active.dispose();
    await tester.runAsync(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewInsets();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: fixture.container,
      child: BooruLocalization(
        child: MaterialApp(
          navigatorObservers: [observer],
          theme: ThemeData(
            extensions: const [KurumiExtendedColorScheme()],
          ).withBoorusamaColors(),
          builder: (context, child) => KurumiTheme(
            data: KurumiThemeData.fromMaterial(Theme.of(context)),
            child: OKToast(
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(narrow ? 2 : 1),
                ),
                child: child!,
              ),
            ),
          ),
          home: Scaffold(
            body: DestinationPageActivity(
              child: ListenableBuilder(
                listenable: Listenable.merge([data, active]),
                builder: (context, _) {
                  final value = data.value;
                  if (value == null) return const SizedBox.shrink();
                  final entry = GroupViewerEntry(
                    summary: value.summary,
                    storedDetails: value.details,
                    occurrenceId: value.summary.reference.identity,
                    source: ViewerSourceBinding(access.config!),
                  );
                  return NavigationActivity(
                    active: active.value && NavigationActivity.of(context),
                    child: InheritedPost(
                      presentationContext: value.page == null
                          ? null
                          : PostPresentationContext.generic(value.page!),
                      child: MediaGroupActions(
                        entry: entry,
                        child: Center(
                          child: Builder(builder: (context) =>
                            PostActionToolbarScope.maybeOf(context)
                                ?.bookmarkButton ??
                            const Text('Page fallback')),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fixture;
}

class _CodecRegistry extends BooruEngineRegistry {
  @override
  BooruPostCapability<BooruPostData>? getPostCapability(BooruType type) =>
      type == BooruType.pixiv
      ? const BooruPostCapability(
          booruType: BooruType.pixiv,
          codec: PixivPostCodec(),
          presentation: GenericPostPresentation(),
        )
      : null;
}
