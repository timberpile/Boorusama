import 'dart:async';

import 'package:boorusama/core/bookmarks/server_favorites.dart';
import 'package:boorusama/boorus/danbooru/posts/favorites/src/favorites_page.dart';
import 'package:boorusama/boorus/e621/favorites/widgets.dart';
import 'package:boorusama/boorus/pixiv/favorites/page.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/bookmarks/src/server_favorites/dialog.dart';
import 'package:boorusama/core/bookmarks/src/server_favorites/feedback_banner.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/data/providers.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group_repository.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group_tree.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_folder_picker_contents.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/configs/manage/widgets.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/groups/folder_tree.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/core/posts/favorites/widgets.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:uuid/uuid.dart';

import '../../../support/fakes/memory_repositories.dart';
import '../../../application/support/fake_image_dio.dart';
import '../../posts/details/progressive_image_test_utils.dart';
import 'test_support.dart';
import '../../../support/legacy_material_test_scope.dart';

void main() {
  late FavoriteHarness h;
  late ProviderContainer container;
  late BookmarkLibraryNotifier library;
  late FavoriteTestStore store;
  late Map<String, String> folderGroupIds;
  setUp(() async {
    h = FavoriteHarness();
    await h.open();
  });
  Future<void> prepare({
    List<BooruConfig>? profiles,
    List<CollectionFolder> folders = const [],
    List<String>? order,
  }) async {
    final groups = MemoryBookmarkGroupRepository();
    folderGroupIds = {
      for (final folder in folders)
        folder.id: const Uuid().v5(
          Namespace.url.value,
          'boorusama/server-favorites-dialog/${folder.id}',
        ),
    };
    await groups.writeOrganization(const [], [
      for (final folder in folders)
        BookmarkGroup(
          id: folderGroupIds[folder.id]!,
          name: folder.name,
          bookmarkIds: const {},
          parentGroupId: folder.parentId == null
              ? null
              : folderGroupIds[folder.parentId],
          position: folder.position,
        ),
    ]);
    store = FavoriteTestStore();
    h.profiles.profiles = profiles ?? h.profiles.profiles;
    container = ProviderContainer(
      overrides: [
        bookmarkLibraryProvider.overrideWith(_FavoritesDialogLibrary.new),
        deterministicFaviconDioOverride(),
        automaticMediaLoadingEnabledProvider.overrideWithValue(false),
        defaultImageCacheManagerProvider.overrideWithValue(TestImageCache({})),
        currentReadOnlyBooruConfigProvider.overrideWithValue(h.profile),
        booruEngineRegistryProvider.overrideWith(
          (ref) => BooruEngineRegistry(),
        ),
        miscDataStoreProvider.overrideWithValue(store),
        booruConfigProvider.overrideWith(
          () => BooruConfigNotifier(initialConfigs: h.profiles.profiles),
        ),
        booruConfigRepoProvider.overrideWithValue(h.profiles),
        bookmarkRepoProvider.overrideWith((ref) => MemoryBookmarkRepository()),
        bookmarkGroupRepoProvider.overrideWith((ref) => groups),
        bookmarkUrlResolverProvider.overrideWith(
          (ref, id) => const DefaultImageUrlResolver(),
        ),
        postLinkGeneratorProvider.overrideWith((ref, auth) => _Links()),
        settingsProvider.overrideWithValue(
          Settings.defaultSettings.copyWith(
            booruConfigIdOrders: order?.join(' ') ?? '',
          ),
        ),
        settingsNotifierProvider.overrideWith(
          () => SettingsNotifier(Settings.defaultSettings),
        ),
        serverFavoriteSourceProvider.overrideWith(
          (ref, profile) => h.sources[profile.id] ?? h.source,
        ),
        serverFavoritePostLoaderProvider.overrideWith(
          (ref, profile) => (h.sources[profile.id] ?? h.source).getPost,
        ),
      ],
    );
    await container.read(bookmarkLibraryProvider.future);
    library = container.read(bookmarkLibraryProvider.notifier);
    await container.read(serverFavoriteSettingsProvider.future);
  }

  tearDown(() async {
    dismissAllToast();
    container.dispose();
    await h.close();
  });
  Future<void> mount(
    WidgetTester tester, {
    BooruConfig? profile,
    Widget? child,
    Size size = const Size(320, 740),
    double textScale = 2,
    bool legacyBridge = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: BooruLocalization(
          child: OKToast(
            // Tests dismiss notifications explicitly, without exit timers.
            duration: Duration.zero,
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: legacyBridge
                    ? LegacyMaterialTestScope(child: child!)
                    : child!,
              ),
              home:
                  child ??
                  CurrentBooruConfigScope(
                    config: profile ?? h.profile,
                    child: const Scaffold(
                      appBar: KurumiAppBar(actions: [FavoritesPageMenu()]),
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(
    WidgetTester tester,
    Finder finder, {
    bool running = false,
  }) async {
    // Do not scroll a visible anchored menu item: ensureVisible would also
    // scroll its opener's dialog and move the menu before the tap.
    if (finder.hitTestable().evaluate().isEmpty) {
      await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
      await tester.pump();
    }
    await tester.tap(finder);
    if (running) {
      await tester.pump();
    } else {
      await tester.pumpAndSettle();
    }
  }

  Future<void> open(WidgetTester tester, {bool running = false}) async {
    await tap(tester, find.byKey(const ValueKey('favorites-page-menu')));
    final action = find.text('Favorites Sync');
    if (running) {
      await tester.tap(action);
      await tester.pump();
      final route = ModalRoute.of(
        tester.element(find.byType(ServerFavoritesDialog)),
      )!;
      await tester.pump(route.transitionDuration);
      await tester.pump();
    } else {
      await tap(tester, action);
    }
    expect(find.byType(ServerFavoritesDialog), findsOneWidget);
  }

  Finder getGlobal() => find.byKey(const ValueKey('server-favorites-global'));
  Finder getSave() => find.byKey(const ValueKey('server-favorites-save'));
  Finder getFetch([String? id]) => find.byKey(
    ValueKey(
      id == null ? 'server-favorites-fetch-all' : 'server-favorites-fetch-$id',
    ),
  );
  Finder target([String? id]) =>
      find.byKey(ValueKey('server-favorites-target-${id ?? h.profile.id}'));
  Future<void> setMode(WidgetTester tester, String mode, {String? id}) async {
    final profileId = id ?? h.profile.id;
    final options = find.byKey(
      ValueKey('server-favorites-mode-options-$profileId'),
    );
    if (options.evaluate().isEmpty) await tap(tester, target(profileId));
    await tap(
      tester,
      find.byKey(ValueKey('server-favorites-mode-$profileId-$mode')),
    );
  }

  Finder unavailable() =>
      find.byKey(const ValueKey('server-favorites-unavailable'));
  Finder close() => find.byKey(const ValueKey('server-favorites-close'));

  bool fetchEnabled(WidgetTester tester, [String? id]) => id == null
      ? tester.widget<OutlinedButton>(getFetch()).onPressed != null
      : tester.widget<IconButton>(getFetch(id)).onPressed != null;

  BooruConfig other({
    String name = 'Second account',
    BooruType type = BooruType.danbooru,
    String id = '00000000-0000-4000-8000-000000000002',
    bool signedOut = false,
  }) => BooruConfig.fromJson({
    ...h.profile.toJson(),
    'id': id,
    'name': name,
    'booruId': type.id,
    'booruIdHint': type.id,
    if (signedOut) 'apiKey': null,
  });
  Future<void> pick(WidgetTester tester, String label) async {
    final contents = find.byType(BookmarkFolderPickerContents);
    final row = find.descendant(
      of: contents,
      matching: find.text(label),
    );
    if (row.hitTestable().evaluate().isEmpty) {
      final scrollable = find.descendant(
        of: find.byKey(const ValueKey('bookmark-picker-hierarchy')),
        matching: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        ),
      );
      await tester.scrollUntilVisible(
        row,
        tester.getSize(scrollable).height / 2,
        scrollable: scrollable,
      );
    }
    await tester.pump();
    await tap(tester, row);
  }

  Future<void> enterGroup(WidgetTester tester, String label) async {
    final row = find
        .ancestor(
          of: find.descendant(
            of: find.byType(BookmarkFolderPickerContents),
            matching: find.text(label),
          ),
          matching: find.byType(BookmarkPickerSplitRow),
        )
        .first;
    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('bookmark-picker-hierarchy')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    await tester.scrollUntilVisible(
      row,
      tester.getSize(scrollable).height / 2,
      scrollable: scrollable,
    );
    final rect = tester.getRect(row);
    await tester.tapAt(Offset(rect.right - rect.width * .1, rect.center.dy));
    await tester.pumpAndSettle();
  }

  Future<void> createGroupAtCurrent(WidgetTester tester, String name) async {
    await tap(
      tester,
      find.byTooltip(_strings(tester).bookmark.groups.create_new),
    );
    await tester.enterText(find.byType(TextField), name);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  Future<ServerFavoriteSettings> saved() =>
      container.read(serverFavoriteSettingsProvider.future);

  testWidgets(
    'Pixiv Favorites opens the shared editor',
    (tester) async {
      final pixiv = pixivFavoriteTestProfile();
      final signedOut = BooruConfig.fromJson({
        ...pixivFavoriteTestProfile(token: null).toJson(),
        'id': '00000000-0000-4000-8000-000000000043',
        'name': 'Signed-out Pixiv profile',
      });
      await prepare(profiles: [pixiv, signedOut]);
      final group = await library.createGroup('Pixiv target');
      await container
          .read(serverFavoriteSettingsProvider.notifier)
          .setGlobal(group.id);
      await mount(
        tester,
        child: CurrentBooruConfigScope(
          config: signedOut,
          child: const PixivFavoritesPage(),
        ),
      );
      await open(tester);
      await tap(tester, unavailable());

      expect(
        find.textContaining(
          'Sign in to fetch favorites.',
        ),
        findsOneWidget,
      );
      expect(getFetch(signedOut.id), findsNothing);
      expect(h.source.calls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact rows keep saved order and unavailable profiles disclose reasons and assignments',
    (tester) async {
      final second = other();
      final unsupported = other(
        name: 'Unsupported account',
        type: BooruType.sankaku,
        id: '00000000-0000-4000-8000-000000000003',
      );
      final signedOut = other(
        name: 'Signed-out account',
        signedOut: true,
        id: '00000000-0000-4000-8000-000000000004',
      );
      await prepare(
        profiles: [h.profile, second, unsupported, signedOut],
        order: [signedOut.id, unsupported.id, second.id, h.profile.id],
      );
      final group = await library.createGroup('Retained target');
      await container
          .read(serverFavoriteSettingsProvider.notifier)
          .setProfile(
            signedOut.id,
            ServerFavoriteTarget.group(group.id),
          );
      await mount(tester, profile: second);
      await open(tester);
      expect(find.text('Second account'), findsOneWidget);
      expect(find.text('Account one'), findsOneWidget);
      expect(find.text('Unsupported account'), findsNothing);
      expect(find.text('Signed-out account'), findsNothing);
      expect(find.text('Default Group'), findsOneWidget);
      expect(find.text('Default'), findsNWidgets(2));
      expect(find.text('Fetch All Favorites'), findsOneWidget);
      expect(find.text('Unavailable (2)'), findsOneWidget);
      expect(
        find.text('Save server favorites to local bookmark groups.'),
        findsNothing,
      );
      expect(find.text('Count Synced Groups as Bookmarks'), findsNothing);
      expect(
        tester.getTopLeft(target(second.id)).dy,
        lessThan(tester.getTopLeft(target()).dy),
      );
      expect(
        tester.getTopLeft(target()).dy,
        lessThan(tester.getTopLeft(unavailable()).dy),
      );
      for (final id in [h.profile.id, second.id]) {
        expect(
          tester.getRect(target(id)).contains(tester.getCenter(getFetch(id))),
          isTrue,
        );
      }
      await tap(tester, unavailable());
      expect(
        tester.getTopLeft(find.text('Signed-out account')).dy,
        lessThan(tester.getTopLeft(find.text('Unsupported account')).dy),
      );
      for (final profile in [unsupported, signedOut]) {
        expect(target(profile.id), findsNothing);
        expect(getFetch(profile.id), findsNothing);
      }
      expect(
        find.textContaining('Not supported for this engine.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Retained target\nSign in to fetch favorites.'),
        findsOneWidget,
      );
      expect(find.text('Current profile'), findsNothing);
      expect(find.text('Fetch server favorites'), findsNothing);
      expect(find.textContaining('Effective target:'), findsNothing);
      expect(find.textContaining('Used by all profiles'), findsNothing);
      await tap(tester, find.byKey(const ValueKey('server-favorites-info')));
      expect(find.text('About Favorites Sync'), findsOneWidget);
      expect(
        find.textContaining('organize, search, and export'),
        findsOneWidget,
      );
      expect(
        find.textContaining('no automatic background fetch'),
        findsOneWidget,
      );
      await tap(tester, find.text('Close').last);
      await tap(tester, find.byKey(const ValueKey('server-favorites-close')));
      await open(tester);
      expect(find.text('Second account'), findsOneWidget);
      expect(find.text('Account one'), findsOneWidget);
      expect(h.source.calls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the default row shows the draft folder path and inheriting profiles show Default',
    (tester) async {
      final second = other();
      await prepare(
        profiles: [h.profile, second],
        folders: [const CollectionFolder(id: 'folder', name: 'Collections')],
      );
      final global = await library.createGroup(
        'Favorites',
        parentGroupId: folderGroupIds['folder'],
      );
      final custom = await library.createGroup('Personal');
      await mount(tester);
      await open(tester);
      await tap(tester, getGlobal());
      await enterGroup(tester, 'Collections');
      await pick(tester, 'Favorites');
      expect(find.text('Collections / Favorites'), findsOneWidget);
      expect(
        find.descendant(
          of: getGlobal(),
          matching: find.text('Collections / Favorites'),
        ),
        findsOneWidget,
      );
      for (final id in [h.profile.id, second.id]) {
        expect(
          find.descendant(of: target(id), matching: find.text('Default')),
          findsOneWidget,
        );
      }
      expect((await saved()).globalGroupId, isNull);
      await setMode(tester, 'group', id: second.id);
      await pick(tester, 'Personal');
      expect(
        find.descendant(of: target(second.id), matching: find.text('Personal')),
        findsOneWidget,
      );
      await tap(tester, getGlobal());
      await pick(tester, 'None');
      expect(
        find.descendant(
          of: target(),
          matching: find.text('Default'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: target(second.id), matching: find.text('Personal')),
        findsOneWidget,
      );
      expect(target(), findsOneWidget);
      expect(getFetch(h.profile.id), findsOneWidget);
      expect(
        tester.widget<IconButton>(getFetch(h.profile.id)).onPressed,
        isNull,
      );
      expect(find.textContaining('Unavailable ('), findsNothing);
      expect(h.source.calls, 0);
      await tap(tester, getSave());
      expect((await saved()).globalGroupId, isNull);
      expect((await saved()).resolve(second.id), custom.id);
      expect(
        (await library.snapshotForExport()).groupsById.containsKey(global.id),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 740), const Size(640, 320)]) {
    testWidgets('long target fields and both pickers fit at $size', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await prepare(
          profiles: [
            other(
              id: h.profile.id,
              name:
                  'A profile with a long account name and website description',
            ),
          ],
        );
        const groupName = 'Favorites collected from several different profiles';
        await library.createGroup(groupName);
        await mount(tester, size: size, profile: h.profiles.profiles.single);
        await open(tester);
        final footer = tester.getRect(getSave());
        await tap(tester, getGlobal());
        await pick(tester, groupName);
        expect(
          find.descendant(of: getGlobal(), matching: find.text(groupName)),
          findsOneWidget,
        );
        for (final global in [true, false]) {
          if (global) {
            await tap(tester, getGlobal());
          } else {
            await setMode(tester, 'group');
          }
          final surface = tester.getRect(
            find.byKey(const Key('bookmark-batch-surface')),
          );
          expect(surface.width, lessThanOrEqualTo(size.width));
          expect(surface.height, lessThanOrEqualTo(size.height));
          expect(
            find.descendant(
              of: find.byKey(const Key('bookmark-batch-surface')),
              matching: find.byType(AlertDialog),
            ),
            findsNothing,
          );
          await tap(tester, find.text('Cancel'));
          expect(tester.getRect(getSave()), footer);
          expect(tester.takeException(), isNull);
        }
      } finally {
        semantics.dispose();
      }
    });
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'title and footer actions stay on one row at text scale $scale',
      (tester) async {
        await prepare();
        await mount(tester, textScale: scale);
        await open(tester);
        final title = find.descendant(
          of: find.byType(KurumiFittedText),
          matching: find.text('Favorites Sync'),
        );
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: title, matching: find.byType(RichText)),
        );
        final lines = paragraph
            .getBoxesForSelection(
              TextSelection(
                baseOffset: 0,
                extentOffset: paragraph.text.toPlainText().length,
              ),
            )
            .map((box) => box.top)
            .toSet();
        expect(lines.length, 1);
        expect(
          tester
              .getRect(title)
              .overlaps(
                tester.getRect(
                  find.byKey(const ValueKey('server-favorites-info')),
                ),
              ),
          isFalse,
        );
        final close = find.byKey(const ValueKey('server-favorites-close'));
        final rects = [close, getSave()].map(tester.getRect).toList();
        for (final rect in rects) {
          expect(rect.center.dy, closeTo(rects.first.center.dy, .1));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(320));
          expect(rect.height, greaterThanOrEqualTo(48));
        }
        expect(tester.widget<OutlinedButton>(close).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'long lists scroll and nested selections stay as drafts in both pickers',
    (tester) async {
      await prepare(
        folders: [
          for (var i = 0; i < 16; i++)
            CollectionFolder(
              id: 'folder-$i',
              name: 'Folder ${i.toString().padLeft(2, '0')}',
            ),
          const CollectionFolder(
            id: 'nested',
            name: 'Nested',
            parentId: 'folder-0',
          ),
        ],
      );
      for (var i = 0; i < 32; i++) {
        await library.createGroup('Group ${i.toString().padLeft(2, '0')}');
      }
      await library.createGroup(
        'Nested target',
        parentGroupId: folderGroupIds['nested'],
      );
      await mount(tester);
      await open(tester);
      for (final global in [true, false]) {
        if (global) {
          await tap(tester, getGlobal());
        } else {
          await setMode(tester, 'group');
        }
        await pick(tester, 'Group 31');
        if (global) {
          await tap(tester, getGlobal());
        } else {
          await setMode(tester, 'group');
        }
        await enterGroup(tester, 'Folder 00');
        await enterGroup(tester, 'Nested');
        await pick(tester, 'Nested target');
        expect(find.byType(BookmarkFolderPickerContents), findsNothing);
      }
      expect(
        find.textContaining('Folder 00 / Nested / Nested target'),
        findsWidgets,
      );
      await tap(
        tester,
        find.byKey(const ValueKey('server-favorites-header-close')),
      );
      await tap(tester, find.text("Don't Save"));
      expect((await saved()).globalGroupId, isNull);
      expect(
        (await saved()).targetFor(h.profile.id),
        const ServerFavoriteTarget.inherit(),
      );
      expect(h.source.calls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'nested selection and creation use Kurumi without a legacy bridge',
    (tester) async {
      await prepare();
      await mount(tester, legacyBridge: false);
      await open(tester);
      await tap(tester, getGlobal());
      await createGroupAtCurrent(tester, 'New target');
      expect(
        find.descendant(of: getGlobal(), matching: find.text('New target')),
        findsOneWidget,
      );
      final before = await library.snapshotForExport();
      await setMode(tester, 'group');
      await pick(tester, 'Default');
      expect(
        find.descendant(of: target(), matching: find.text('Default')),
        findsOneWidget,
      );
      await tap(tester, getGlobal());
      await pick(tester, 'None');
      expect(await library.snapshotForExport(), before);
      expect((await saved()).globalGroupId, isNull);
      expect(h.source.calls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all profile edits save together and Save stays open without fetching',
    (tester) async {
      final second = other();
      await prepare(profiles: [h.profile, second]);
      final global = await library.createGroup('Global group');
      final custom = await library.createGroup('Custom group');
      await mount(tester);
      await open(tester);
      await tap(tester, getGlobal());
      await pick(tester, 'Global group');
      expect(fetchEnabled(tester), isFalse);
      await setMode(tester, 'none', id: second.id);
      await setMode(tester, 'group');
      await pick(tester, 'Custom group');
      expect(
        find.byKey(ValueKey('server-favorites-mode-options-${second.id}')),
        findsNothing,
      );
      expect(fetchEnabled(tester, h.profile.id), isFalse);
      expect(fetchEnabled(tester), isFalse);
      expect((await saved()).globalGroupId, isNull);
      expect(store.writes, 0);
      await tap(tester, getSave());
      expect(find.byType(ServerFavoritesDialog), findsOneWidget);
      final state = await saved();
      expect(state.globalGroupId, global.id);
      expect(state.resolve(h.profile.id), custom.id);
      expect(state.targetFor(second.id), const ServerFavoriteTarget.none());
      expect(store.writes, 1);
      expect(fetchEnabled(tester, h.profile.id), isTrue);
      expect(fetchEnabled(tester), isTrue);
      expect(
        find.descendant(of: target(), matching: find.text('Custom group')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: target(second.id), matching: find.text('Disabled')),
        findsOneWidget,
      );
      await setMode(tester, 'inherit');
      await tap(tester, getSave());
      expect((await saved()).resolve(h.profile.id), global.id);
      expect(h.source.calls, 0);
    },
  );

  testWidgets(
    'group creation fits narrow width enlarged text and the open keyboard',
    (tester) async {
      await prepare(
        folders: [
          const CollectionFolder(id: 'folder', name: 'Saved'),
          const CollectionFolder(
            id: 'child',
            name: 'Existing child',
            parentId: 'folder',
          ),
        ],
      );
      await mount(tester);
      await open(tester);
      await tap(tester, getGlobal());
      await enterGroup(tester, 'Saved');
      await tap(
        tester,
        find.byTooltip(_strings(tester).bookmark.groups.create_new),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'New favorites');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      await tap(tester, getSave());
      expect(find.byType(ServerFavoritesDialog), findsOneWidget);
      final group = (await library.snapshotForExport()).groups.singleWhere(
        (g) => g.name == 'New favorites',
      );
      expect(group.parentGroupId, folderGroupIds['folder']);
      expect((await saved()).globalGroupId, group.id);
      expect(h.source.calls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'closing an unsaved populated target choice preserves contents and settings',
    (tester) async {
      await prepare();
      final group = await library.createGroup('Existing favorites');
      await library.addPostsToGroup(h.profile.auth, [h.post(3)], group.id);
      final before = await library.snapshotForExport();
      await mount(tester);
      await open(tester);
      await tap(tester, getGlobal());
      await pick(tester, 'Existing favorites');
      await tap(tester, close());
      expect(find.text('Close without saving your changes?'), findsOneWidget);
      await tap(tester, find.text('Cancel'));
      expect(find.byType(ServerFavoritesDialog), findsOneWidget);
      expect(
        find.descendant(
          of: getGlobal(),
          matching: find.text('Existing favorites'),
        ),
        findsOneWidget,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Close without saving your changes?'), findsOneWidget);
      await tap(tester, find.text("Don't Save"));
      expect(find.byType(ServerFavoritesDialog), findsNothing);
      expect(await library.snapshotForExport(), before);
      expect((await saved()).globalGroupId, isNull);
      expect(h.source.calls, 0);
    },
  );

  testWidgets(
    'saving a populated first or shared target never prompts or clears',
    (tester) async {
      await prepare();
      final group = await library.createGroup('Existing favorites');
      await library.addPostsToGroup(h.profile.auth, [h.post(3)], group.id);
      final initial = await library.snapshotForExport();
      await mount(tester);
      await open(tester);
      await tap(tester, getGlobal());
      await pick(tester, 'Existing favorites');
      await tap(tester, getSave());
      expect(find.text('Clear existing bookmarks?'), findsNothing);
      expect(find.text('Clear & Save'), findsNothing);
      expect(find.byType(ServerFavoritesDialog), findsOneWidget);
      expect(await library.snapshotForExport(), initial);
      expect((await saved()).globalGroupId, group.id);
      await library.addPostsToGroup(h.profile.auth, [h.post(4)], group.id);
      final before = await library.snapshotForExport();
      await setMode(tester, 'group');
      await pick(tester, 'Existing favorites');
      await tap(tester, getSave());
      expect(find.text('Clear existing bookmarks?'), findsNothing);
      expect(await library.snapshotForExport(), before);
      expect(h.source.calls, 0);
    },
  );

  testWidgets(
    'an account change before saving a populated target preserves all contents',
    (tester) async {
      await prepare();
      final group = await library.createGroup('Existing favorites');
      await library.addPostsToGroup(h.profile.auth, [h.post(3)], group.id);
      final before = await library.snapshotForExport();
      await mount(tester);
      await open(tester);
      await tap(tester, getGlobal());
      await pick(tester, 'Existing favorites');
      // The durable account changes before the UI provider has refreshed.
      // saveAll must still reject the captured account rather than save it.
      h.profiles.profiles = [
        BooruConfig.fromJson({...h.profile.toJson(), 'login': 'changed'}),
      ];
      await tap(tester, getSave());
      expect(find.byType(ServerFavoritesDialog), findsOneWidget);
      expect(find.textContaining('The account changed.'), findsWidgets);
      expect(await library.snapshotForExport(), before);
      expect((await saved()).globalGroupId, isNull);
      expect(h.source.calls, 0);
    },
  );

  testWidgets(
    'per-profile fetch stays open with cancellation retry and subsequent editing',
    (tester) async {
      final second = other();
      await prepare(profiles: [h.profile, second]);
      final group = await library.createGroup('Favorites');
      h.source.pending = Completer();
      final secondSource = FavoriteTestSource([h.post(2)]);
      h.sources[second.id] = secondSource;
      await mount(tester);
      await open(tester);
      await tap(tester, getGlobal());
      await pick(tester, 'Favorites');
      expect(fetchEnabled(tester, h.profile.id), isFalse);
      await tap(tester, getSave());
      expect(h.source.calls, 0);
      await tap(tester, getFetch(h.profile.id), running: true);
      expect(
        h.source.requested.isCompleted,
        isTrue,
        reason: '${container.read(serverFavoriteFetchProvider)}',
      );
      expect(find.byType(ServerFavoritesDialog), findsOneWidget);
      expect((await saved()).globalGroupId, group.id);
      expect(secondSource.calls, 0);
      final firstPage = h.source.pending!;
      h.source.pending = Completer();
      firstPage.complete(ServerFavoritePage([h.post(1)], hasMore: true));
      await tester.pump();
      expect(find.text('Downloading · 1 pages fetched'), findsOneWidget);
      expect(
        (await library.snapshotForExport()).groupsById[group.id]!.bookmarkIds,
        isEmpty,
      );
      expect(h.source.calls, 2);
      expect(
        tester.widget<FilledButton>(getSave()).onPressed,
        isNull,
      );
      expect(
        find.byKey(ValueKey('server-favorites-cancel-${h.profile.id}')),
        findsOneWidget,
      );
      await tap(
        tester,
        find.byKey(ValueKey('server-favorites-cancel-${h.profile.id}')),
      );
      expect(
        find.text('Fetch cancelled. Saved posts are kept.'),
        findsOneWidget,
      );
      h.source.pending = null;
      await tap(tester, getFetch(h.profile.id));
      expect(find.byType(ServerFavoritesDialog), findsOneWidget);
      expect(find.text('Fetch completed'), findsOneWidget);
      expect(h.source.calls, 3);
      expect(secondSource.calls, 0);
      await setMode(tester, 'none');
      await tap(tester, getSave());
      expect(find.byType(ServerFavoritesDialog), findsOneWidget);
      expect(
        (await saved()).targetFor(h.profile.id),
        const ServerFavoriteTarget.none(),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Close leaves a fetch running and reopening shows its progress', (
    tester,
  ) async {
    await prepare();
    final group = await library.createGroup('Favorites');
    await container
        .read(serverFavoriteSettingsProvider.notifier)
        .setGlobal(group.id);
    h.source.pending = Completer();
    await mount(tester);
    await open(tester);
    await tap(tester, getFetch(), running: true);
    expect(find.byType(ServerFavoritesDialog), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('server-favorites-close')));
    expect(find.byType(ServerFavoritesDialog), findsNothing);
    expect(
      container.read(serverFavoriteFetchProvider)[h.profile.id]!.running,
      isTrue,
    );
    await open(tester, running: true);
    expect(find.text('0 of 1 profiles finished'), findsOneWidget);
    expect(
      find.byKey(ValueKey('server-favorites-cancel-${h.profile.id}')),
      findsOneWidget,
    );
    h.source.pending!.complete(ServerFavoritePage([h.post(1)], hasMore: false));
    await tester.pumpAndSettle();
    expect(find.text('Fetch completed'), findsOneWidget);
    expect(h.source.calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'global fetch includes overrides and skips None unsupported signed-out and missing targets',
    (tester) async {
      final second = other();
      final optedOut = other(
        name: 'Opted out',
        id: '00000000-0000-4000-8000-000000000003',
      );
      final signedOut = other(
        name: 'Signed out',
        signedOut: true,
        id: '00000000-0000-4000-8000-000000000004',
      );
      final unsupported = other(
        name: 'Unsupported',
        type: BooruType.sankaku,
        id: '00000000-0000-4000-8000-000000000005',
      );
      final missing = other(
        name: 'Missing target',
        id: '00000000-0000-4000-8000-000000000006',
      );
      await prepare(
        profiles: [
          h.profile,
          second,
          optedOut,
          signedOut,
          unsupported,
          missing,
        ],
      );
      final global = await library.createGroup('Global');
      final override = await library.createGroup('Override');
      final deleted = await library.createGroup('Deleted');
      final prefs = container.read(serverFavoriteSettingsProvider.notifier);
      await prefs.setProfile(optedOut.id, const ServerFavoriteTarget.none());
      await prefs.setProfile(
        missing.id,
        ServerFavoriteTarget.group(deleted.id),
      );
      await library.deleteGroup(deleted.id);
      final sources = {
        for (final p in h.profiles.profiles)
          p.id: FavoriteTestSource([h.post(1)]),
      };
      h.sources.addAll(sources);
      await mount(tester);
      await open(tester);
      expect(target(optedOut.id), findsOneWidget);
      expect(target(missing.id), findsOneWidget);
      expect(target(signedOut.id), findsNothing);
      expect(target(unsupported.id), findsNothing);
      await tap(tester, getGlobal());
      await pick(tester, 'Global');
      await setMode(tester, 'group', id: second.id);
      await pick(tester, 'Override');
      expect(fetchEnabled(tester), isFalse);
      await tap(tester, getSave());
      expect(sources.values.map((source) => source.calls), everyElement(0));
      await tap(tester, getFetch());
      expect(find.byType(ServerFavoritesDialog), findsOneWidget);
      expect(find.text('Fetch completed'), findsNWidgets(2));
      expect(sources[h.profile.id]!.calls, 1);
      expect(sources[second.id]!.calls, 1);
      for (final p in [optedOut, signedOut, unsupported, missing]) {
        expect(sources[p.id]!.calls, 0);
      }
      final after = await library.snapshotForExport();
      expect(after.groupsById[global.id]!.bookmarkIds, hasLength(1));
      expect(after.groupsById[override.id]!.bookmarkIds, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'global fetch stays open with cancellation errors and retry',
    (tester) async {
      final second = other();
      await prepare(profiles: [h.profile, second]);
      final group = await library.createGroup('Global');
      await container
          .read(serverFavoriteSettingsProvider.notifier)
          .setGlobal(group.id);
      h.source.pending = Completer();
      final secondSource = FavoriteTestSource([h.post(2)])
        ..pending = Completer();
      h.sources[second.id] = secondSource;
      await mount(tester);
      await open(tester);
      await tap(tester, getFetch(), running: true);
      expect(h.source.requested.isCompleted, isTrue);
      expect(secondSource.requested.isCompleted, isTrue);
      expect(find.byType(ServerFavoritesDialog), findsOneWidget);
      expect(find.text('0 of 2 profiles finished'), findsOneWidget);
      await tap(
        tester,
        find.byKey(const ValueKey('server-favorites-cancel-all')),
      );
      expect(
        container.read(serverFavoriteFetchProvider).values.map((p) => p.status),
        everyElement(ServerFavoriteFetchStatus.cancelled),
      );
      h.source.pending = null;
      h.source.error = const ServerFavoriteException(
        ServerFavoriteProblem.remoteFailure,
      );
      await tap(tester, getFetch(h.profile.id));
      expect(find.byType(ServerFavoritesDialog), findsOneWidget);
      expect(find.textContaining('The server request failed'), findsOneWidget);
      expect(
        tester.widget<IconButton>(getFetch(h.profile.id)).tooltip,
        'Retry fetching favorites for Account one',
      );
      h.source.error = null;
      await tap(tester, getFetch(h.profile.id));
      expect(find.byType(ServerFavoritesDialog), findsOneWidget);
      expect(find.text('Fetch completed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a failed profile can retry while another profile keeps fetching',
    (
      tester,
    ) async {
      final second = other();
      await prepare(profiles: [h.profile, second]);
      final group = await library.createGroup('Global');
      await container
          .read(serverFavoriteSettingsProvider.notifier)
          .setGlobal(group.id);
      h.source.error = const ServerFavoriteException(
        ServerFavoriteProblem.remoteFailure,
      );
      final secondSource = FavoriteTestSource([h.post(3)])
        ..pending = Completer();
      h.sources[second.id] = secondSource;
      await mount(tester);
      await open(tester);
      await tap(tester, getFetch(), running: true);
      expect(
        container.read(serverFavoriteFetchProvider)[h.profile.id]!.status,
        ServerFavoriteFetchStatus.failed,
      );
      expect(
        container.read(serverFavoriteFetchProvider)[second.id]!.running,
        isTrue,
      );
      expect(find.text('1 of 2 profiles finished'), findsOneWidget);
      expect(
        tester.widget<IconButton>(getFetch(h.profile.id)).onPressed,
        isNotNull,
      );
      expect(tester.widget<IconButton>(getFetch(second.id)).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(getFetch()).onPressed, isNull);
      expect(tester.widget<FilledButton>(getSave()).onPressed, isNull);
      expect(tester.widget<ListTile>(getGlobal()).onTap, isNull);
      h.source.error = null;
      await tap(tester, getFetch(h.profile.id), running: true);
      expect(
        container.read(serverFavoriteFetchProvider)[h.profile.id]!.status,
        ServerFavoriteFetchStatus.completed,
      );
      expect(
        container.read(serverFavoriteFetchProvider)[second.id]!.running,
        isTrue,
      );
      expect(h.source.calls, 2);
      expect(secondSource.calls, 1);
      await tap(
        tester,
        find.byKey(ValueKey('server-favorites-cancel-${second.id}')),
      );
      expect(
        container.read(serverFavoriteFetchProvider)[second.id]!.status,
        ServerFavoriteFetchStatus.cancelled,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fetch cannot save a changed draft while another job is running',
    (
      tester,
    ) async {
      final second = other();
      await prepare(profiles: [h.profile, second]);
      final original = await library.createGroup('Original');
      await library.createGroup('Draft');
      await container
          .read(serverFavoriteSettingsProvider.notifier)
          .setGlobal(original.id);
      final secondSource = FavoriteTestSource([h.post(3)])
        ..pending = Completer();
      h.sources[second.id] = secondSource;
      await mount(tester);
      await open(tester);
      await tap(tester, getGlobal());
      await pick(tester, 'Draft');
      final running = container
          .read(serverFavoriteFetchProvider.notifier)
          .start(second.id);
      await tester.pump();
      expect(secondSource.requested.isCompleted, isTrue);
      expect(
        tester.widget<IconButton>(getFetch(h.profile.id)).onPressed,
        isNull,
      );
      expect((await saved()).globalGroupId, original.id);
      container.read(serverFavoriteFetchProvider.notifier).cancel(second.id);
      await tester.pumpAndSettle();
      expect((await running).status, ServerFavoriteFetchStatus.cancelled);
      expect(fetchEnabled(tester, h.profile.id), isFalse);
      expect(fetchEnabled(tester), isFalse);
      await tap(tester, getSave());
      expect(fetchEnabled(tester, h.profile.id), isTrue);
      expect(
        find.descendant(of: getGlobal(), matching: find.text('Draft')),
        findsOneWidget,
      );
      expect(h.source.calls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed saving keeps the editor open and starts no fetch', (
    tester,
  ) async {
    await prepare();
    await library.createGroup('Favorites');
    await mount(tester);
    await open(tester);
    await tap(tester, getGlobal());
    await pick(tester, 'Favorites');
    store.fail = true;
    await tap(tester, getSave());
    expect(find.byType(ServerFavoritesDialog), findsOneWidget);
    expect(
      find.text('The bookmark settings or group could not be saved or loaded.'),
      findsOneWidget,
    );
    expect(h.source.calls, 0);
    expect((await saved()).globalGroupId, isNull);
    expect(fetchEnabled(tester), isFalse);
    store.fail = false;
    await tap(tester, getSave());
    expect(find.byType(ServerFavoritesDialog), findsOneWidget);
    expect(fetchEnabled(tester), isTrue);
    expect(h.source.calls, 0);
  });

  testWidgets(
    'stale settings and changed accounts require reloading before save',
    (tester) async {
      await prepare();
      final group = await library.createGroup('Changed elsewhere');
      await mount(tester);
      await open(tester);
      await setMode(tester, 'none');
      await container
          .read(serverFavoriteSettingsProvider.notifier)
          .setGlobal(group.id);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(getSave()).onPressed, isNull);
      expect(fetchEnabled(tester), isFalse);
      expect(find.textContaining('The target changed.'), findsOneWidget);
      await tap(tester, find.text('Reload Settings'));
      expect(
        find.descendant(
          of: getGlobal(),
          matching: find.text('Changed elsewhere'),
        ),
        findsOneWidget,
      );
      h.profiles.profiles = [
        BooruConfig.fromJson({...h.profile.toJson(), 'login': 'changed'}),
      ];
      await container.read(booruConfigProvider.notifier).fetch();
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(getSave()).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(getFetch()).onPressed, isNull);
      await tap(tester, find.text('Reload Settings'));
      expect(tester.widget<FilledButton>(getSave()).onPressed, isNull);
      await tap(tester, close());
      expect(find.byType(ServerFavoritesDialog), findsNothing);
      expect(h.source.calls, 0);
    },
  );

  for (final danbooru in [true, false]) {
    testWidgets(
      '${danbooru ? 'Danbooru' : 'e621'} signed-out Favorites retains the shared editor',
      (tester) async {
        final profile = BooruConfig.fromJson({
          ...h.profile.toJson(),
          'apiKey': null,
          'booruIdHint': danbooru ? BooruType.danbooru.id : BooruType.e621.id,
        });
        await prepare(profiles: [profile]);
        await container
            .read(serverFavoriteSettingsProvider.notifier)
            .setProfile(profile.id, const ServerFavoriteTarget.none());
        final group = await library.createGroup('Global');
        await mount(
          tester,
          child: CurrentBooruConfigScope(
            config: profile,
            child: danbooru
                ? const DanbooruFavoritesPage()
                : const E621FavoritesPage(),
          ),
        );
        expect(find.byType(FavoritesUnavailablePage), findsOneWidget);
        await open(tester);
        expect(find.text('Account one'), findsNothing);
        await tap(tester, unavailable());
        expect(find.text('Account one'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(ServerFavoritesDialog),
            matching: find.textContaining(
              'Sign in to fetch favorites.',
            ),
          ),
          findsOneWidget,
        );
        expect(getFetch(profile.id), findsNothing);
        expect(target(profile.id), findsNothing);
        expect(find.textContaining('Unavailable ('), findsOneWidget);
        await tap(tester, getGlobal());
        await pick(tester, 'Global');
        await tap(tester, getSave());
        expect((await saved()).globalGroupId, group.id);
        expect(
          (await saved()).targetFor(profile.id),
          const ServerFavoriteTarget.none(),
        );
        expect(find.byType(ServerFavoritesDialog), findsOneWidget);
        expect(h.source.calls, 0);
      },
    );
  }

  testWidgets('a deleted target can be disabled without fetching', (
    tester,
  ) async {
    await prepare();
    final group = await library.createGroup('Deleted');
    await container
        .read(serverFavoriteSettingsProvider.notifier)
        .setGlobal(group.id);
    await library.deleteGroup(group.id);
    await mount(tester);
    await open(tester);
    expect(
      find.textContaining('Group unavailable'),
      findsWidgets,
    );
    expect(tester.widget<OutlinedButton>(getFetch()).onPressed, isNull);
    await tap(tester, getGlobal());
    await pick(tester, 'None');
    await tap(tester, getSave());
    expect((await saved()).globalGroupId, isNull);
    expect(h.source.calls, 0);
  });

  testWidgets(
    'capability notices stay in configuration and real failures remain dismissible',
    (
      tester,
    ) async {
      await prepare();
      container
          .read(serverFavoriteFeedbackProvider.notifier)
          .report(ServerFavoriteProblem.unsupported);
      await mount(
        tester,
        child: const Scaffold(body: ServerFavoriteFeedbackBanner()),
      );
      expect(find.textContaining('The server action succeeded'), findsNothing);
      container
          .read(serverFavoriteFeedbackProvider.notifier)
          .report(ServerFavoriteProblem.targetMissing);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('The server action succeeded'),
        findsOneWidget,
      );
      await tap(tester, find.text('Close'));
      expect(find.textContaining('The server action succeeded'), findsNothing);
    },
  );
}

Translations _strings(WidgetTester tester) =>
    tester.element(find.byType(Navigator).first).t;

/// The in-memory legacy service has no unified organization journal. Keep
/// nested creation local to this UI test while exercising the real picker and
/// refreshing the same provider snapshot that production observes.
final class _FavoritesDialogLibrary extends BookmarkLibraryNotifier {
  @override
  Future<BookmarkGroup> createGroup(
    String name, {
    String? folderId,
    String? parentGroupId,
  }) async {
    if (parentGroupId == null) {
      return super.createGroup(name, folderId: folderId);
    }

    final repository = await ref.read(bookmarkGroupRepoProvider.future);
    final groups = await repository.getGroups();
    if (!groups.any((group) => group.id == parentGroupId)) {
      throw StateError('Parent Bookmark Group no longer exists');
    }
    final created = await repository.createGroup(name);
    final position = groups
        .where((group) => group.parentGroupId == parentGroupId)
        .fold(
          0,
          (next, group) => group.position >= next ? group.position + 1 : next,
        );
    final nested = created.copyWith(
      parentGroupId: parentGroupId,
      position: position,
    );
    BookmarkGroupTree([...groups, nested]);
    await repository.replaceFolderOrganization(const [], [...groups, nested]);
    await refresh();
    return nested;
  }
}

class _Links extends PostLinkGenerator<Post> {
  @override
  String getLink(Post post) =>
      'https://${post.origin.sourceHost}/posts/${post.id}';
}
