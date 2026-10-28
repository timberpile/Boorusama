import 'dart:async';
import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart' as legacy;
import 'package:flutter/rendering.dart' show RenderBox;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:oktoast/oktoast.dart';

import 'package:boorusama/core/bookmarks/src/data/bookmark_convert.dart';
import 'package:boorusama/core/bookmarks/server_favorites.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/providers/recent_bookmark_groups_provider.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_library_service.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_target.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_group_picker.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/groups/folder_tree.dart';
import 'package:boorusama/core/posts/details_parts/src/toolbars/bookmark_post_button.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/themes/colors/src/colors.dart';

const _groupId = '550e8400-e29b-41d4-a716-446655440000';
const _folderId = '550e8400-e29b-41d4-a716-446655440001';

void main() {
  for (final likeButton in [false, true]) {
    for (final memberships in [0, 1, 2]) {
      testWidgets(
        'viewer ${likeButton ? 'like' : 'icon'} button labels its semantic tap with $memberships memberships',
        (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            final notifier = await _pump(
              tester,
              likeButton: likeButton,
              memberships: memberships,
            );
            final button = find.byType(
              likeButton ? KurumiLikeButton : IconButton,
            );
            final node = tester.getSemantics(button);
            final data = node.getSemanticsData();
            expect(
              data.label,
              contains(tester.element(button).t.bookmark.groups.selector),
            );
            expect(data.value, memberships > 1 ? '$memberships' : '');
            expect(data.flagsCollection.isButton, isTrue);
            expect(data.flagsCollection.isEnabled, Tristate.isTrue);
            expect(data.hasAction(SemanticsAction.tap), isTrue);
            if (likeButton) {
              expect(
                data.flagsCollection.isToggled,
                memberships > 0 ? Tristate.isTrue : Tristate.isFalse,
              );
            }
            node.owner!.performAction(node.id, SemanticsAction.tap);
            await tester.pumpAndSettle();
            expect(find.byType(BookmarkGroupPicker), findsOneWidget);
            expect(notifier.toggles, isEmpty);
          } finally {
            await _unmount(tester);
            semantics.dispose();
          }
        },
      );
    }

    testWidgets(
      'viewer ${likeButton ? 'like' : 'icon'} button only changes membership after selecting a group',
      (tester) async {
        final notifier = await _pump(tester, likeButton: likeButton);
        final button = find.byType(likeButton ? KurumiLikeButton : IconButton);
        expect(tester.widget<Icon>(find.byIcon(Symbols.bookmark)).fill, 1);
        expect(
          find.text('Saved'),
          findsNothing,
          reason: 'There is no caption.',
        );
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(notifier.toggles, isEmpty);
        expect(find.byType(BookmarkGroupPicker), findsOneWidget);
        expect(find.byTooltip('Active'), findsNothing);
        expect(find.byIcon(legacy.Icons.check), findsNothing);
        expect(find.byType(legacy.AlertDialog), findsNothing);
        await tester.tap(find.text('Saved'));
        await tester.pumpAndSettle();
        expect(notifier.toggles, [_groupId]);
        expect(tester.widget<Icon>(find.byIcon(Symbols.bookmark)).fill, 0);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(notifier.toggles, [_groupId]);
        await tester.tap(find.text('Saved'));
        await tester.pumpAndSettle();
        expect(notifier.toggles, [_groupId, _groupId]);
        expect(tester.widget<Icon>(find.byIcon(Symbols.bookmark)).fill, 1);
        await _unmount(tester);
      },
    );

    testWidgets(
      'viewer ${likeButton ? 'like' : 'icon'} button has no long-press bookmark action',
      (tester) async {
        final notifier = await _pump(tester, likeButton: likeButton);
        await tester.longPress(
          find.byType(likeButton ? KurumiLikeButton : IconButton),
        );
        await tester.pumpAndSettle();
        expect(notifier.toggles, isEmpty);
        expect(find.byType(BookmarkGroupPicker), findsNothing);
        await _unmount(tester);
      },
    );
  }

  for (final likeButton in [false, true]) {
    for (final memberships in [1, 2]) {
      testWidgets(
        'ignored sync membership leaves other groups highlighted ($likeButton, $memberships)',
        (tester) async {
          await _pump(
            tester,
            likeButton: likeButton,
            memberships: memberships,
            ignoreSyncedGroup: true,
          );
          expect(
            tester.widget<Icon>(find.byIcon(Symbols.bookmark)).fill,
            memberships == 1 ? 0 : 1,
          );
          await tester.tap(
            find.byType(likeButton ? KurumiLikeButton : IconButton),
          );
          await tester.pumpAndSettle();
          // The setting affects the toolbar, never the actual picker membership.
          final saved = find.ancestor(
            of: find.text('Saved'),
            matching: find.byType(KurumiPopupMenuItem),
          );
          expect(
            tester
                .widget<legacy.Icon>(
                  find.descendant(
                    of: saved,
                    matching: find.byIcon(Symbols.bookmarks),
                  ),
                )
                .fill,
            1,
          );
          await _unmount(tester);
        },
      );
    }
  }

  testWidgets('only actual memberships fill group icons', (
    tester,
  ) async {
    await _pump(tester, includeEmptyGroup: true);
    expect(tester.widget<Icon>(find.byIcon(Symbols.bookmark)).fill, 1);
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    for (final (name, fill) in [('Saved', 1.0), ('Other', 0.0)]) {
      final row = find.ancestor(
        of: find.text(name),
        matching: find.byType(KurumiPopupMenuItem),
      );
      expect(
        tester
            .widget<legacy.Icon>(
              find.descendant(
                of: row,
                matching: find.byIcon(Symbols.bookmarks),
              ),
            )
            .fill,
        fill,
      );
    }
    expect(find.text('Active'), findsNothing);
    await _unmount(tester);
  });

  testWidgets('Recent stays below the hierarchy and toggles a nested group', (
    tester,
  ) async {
    final notifier = await _pump(tester, recent: true, manyGroups: true);
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    final hierarchy = find.byKey(const ValueKey('bookmark-picker-hierarchy'));
    final recent = find.byKey(const ValueKey('bookmark-picker-recent'));
    final create = find.text(
      tester
          .element(find.byType(BookmarkGroupPicker))
          .t
          .bookmark
          .groups
          .create_new,
    );
    expect(
      tester.getBottomLeft(create).dy,
      lessThanOrEqualTo(tester.getTopLeft(hierarchy).dy),
    );
    expect(find.text('Artists'), findsNWidgets(2));
    expect(find.text('Recent'), findsOneWidget);
    final dividers = find.byType(KurumiContextMenuDivider);
    Rect rule(Finder divider) => tester.getRect(
      find.descendant(
        of: divider,
        matching: find.byType(legacy.DecoratedBox),
      ),
    );
    expect(rule(dividers.last).right, rule(dividers.first).right);
    final recentBefore = tester.getRect(recent);
    await tester.drag(hierarchy, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.getRect(recent), recentBefore);
    await tester.tap(find.descendant(of: recent, matching: find.text('Saved')));
    await tester.pumpAndSettle();
    expect(notifier.toggles, [_groupId]);
    await _unmount(tester);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Recent folder paths use the row edge and group baseline at ${scale}x',
      (tester) async {
        const path = 'Artists / A considerably longer nested folder path';
        await _pump(
          tester,
          recent: true,
          includeEmptyGroup: true,
          recentFolderName: path,
          twoRecentGroups: true,
          textScale: scale,
        );
        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();
        final recent = find.byKey(const ValueKey('bookmark-picker-recent'));
        final name = find.descendant(of: recent, matching: find.text('Saved'));
        final detail = find.descendant(of: recent, matching: find.text(path));
        final row = find.ancestor(
          of: name,
          matching: find.byType(KurumiPopupMenuItem),
        );
        final rect = tester.getRect(detail);
        expect(rect.right, tester.getRect(row).right - 8);
        expect(rect.width, greaterThan(100));
        double baseline(Finder finder) {
          final box = tester.renderObject<RenderBox>(finder);
          return tester.getTopLeft(finder).dy +
              box.getDryBaseline(
                legacy.BoxConstraints.tight(box.size),
                legacy.TextBaseline.alphabetic,
              )!;
        }

        expect(baseline(detail), closeTo(baseline(name), .001));
        final theme = legacy.Theme.of(tester.element(detail));
        expect(
          tester.widget<legacy.Text>(detail).style!.color,
          theme.dividerTheme.color ?? theme.colorScheme.outlineVariant,
        );
        expect(tester.takeException(), isNull);
        await _unmount(tester);
      },
    );
  }
  for (final modal in [false, true]) {
    testWidgets(
      'picker remains usable at narrow width with enlarged text (modal: $modal)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 480);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _pump(
          tester,
          recent: true,
          manyGroups: true,
          textScale: 2,
          modal: modal,
        );
        if (!modal) await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Recent'), findsOneWidget);
        final hierarchy = find.byKey(
          const ValueKey('bookmark-picker-hierarchy'),
        );
        final recent = find.byKey(const ValueKey('bookmark-picker-recent'));
        expect(tester.getSize(hierarchy).height, greaterThan(0));
        expect(tester.getSize(recent).height, greaterThan(0));
        await _unmount(tester);
      },
    );
  }
}

Future<void> _unmount(WidgetTester tester) async {
  dismissAllToast();
  await tester.pump();
  // OKToast's delayed animation callbacks outlive explicit dismissal.
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpWidget(const SizedBox.shrink());
}

Future<_Library> _pump(
  WidgetTester tester, {
  bool likeButton = false,
  bool includeEmptyGroup = false,
  bool recent = false,
  String recentFolderName = 'Artists',
  bool twoRecentGroups = false,
  bool manyGroups = false,
  bool modal = false,
  bool ignoreSyncedGroup = false,
  int memberships = 1,
  double textScale = 1,
}) async {
  final bookmark = Bookmark.empty.copyWith(
    sourceUrl: 'https://example.com',
    originalUrl: 'https://example.com/1.jpg',
    postId: () => 1,
  );
  final saved = BookmarkGroup(
    id: _groupId,
    name: 'Saved',
    folderId: recent ? _folderId : null,
    bookmarkIds: memberships > 0 ? {bookmark.id} : const {},
  );
  final other = BookmarkGroup(
    id: '550e8400-e29b-41d4-a716-446655440002',
    name: twoRecentGroups ? 'A longer recent group name' : 'Other',
    bookmarkIds: memberships > 1 ? {bookmark.id} : const {},
  );
  final notifier = _Library(
    BookmarkLibraryState(
      bookmarks: memberships > 0 ? [bookmark] : [],
      groups: [
        saved,
        if (includeEmptyGroup || memberships > 1) other,
        if (manyGroups)
          for (var i = 10; i < 30; i++)
            BookmarkGroup(
              id: '550e8400-e29b-41d4-a716-4466554400$i',
              name: 'Group $i',
              bookmarkIds: const {},
            ),
      ],
      folders: [
        if (recent) CollectionFolder(id: _folderId, name: recentFolderName),
      ],
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bookmarkProvider.overrideWith(() => notifier),
        serverFavoriteSettingsProvider.overrideWith(
          () => _FavoriteSettings(ignoreSyncedGroup),
        ),
        recentBookmarkGroupsProvider.overrideWith(
          (ref) async => recent ? [saved, if (twoRecentGroups) other] : [],
        ),
        currentReadOnlyBooruConfigAuthProvider.overrideWithValue(
          BooruConfig.empty.auth,
        ),
      ],
      child: BooruLocalization(
        child: MaterialApp(
          theme: ThemeData(extensions: const [KurumiExtendedColorScheme()])
              .withBoorusamaColors(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: KurumiTheme(
              data: KurumiThemeData.fromMaterial(
                Theme.of(context).withBoorusamaColors(),
              ),
              child: MaterialUiCompatibilityBridge(
                child: OKToast(child: child!),
              ),
            ),
          ),
          home: Scaffold(
            body: Center(
              child: modal
                  ? BookmarkGroupPicker(
                      config: BooruConfig.empty.auth,
                      post: bookmark.toPost(),
                    )
                  : likeButton
                  ? BookmarkPostLikeButtonButton(post: bookmark.toPost())
                  : BookmarkPostButton(
                      config: BooruConfig.empty.auth,
                      post: bookmark.toPost(),
                    ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return notifier;
}

class _Library extends BookmarkLibraryNotifier {
  _Library(this.initial);
  final BookmarkLibraryState initial;
  final toggles = <String>[];

  @override
  FutureOr<BookmarkLibraryState> build() => initial;

  @override
  Future<BookmarkToggleOutcome> togglePostTarget(
    BooruConfigAuth config,
    Post post, {
    BookmarkTarget target = const BookmarkTarget.defaultGroup(),
    void Function(BookmarkGroupRemovalResult)? onRemoved,
  }) async {
    final current = state.requireValue;
    final id = target.groupId;
    toggles.add(id);
    final group = current.groups.firstWhere((g) => g.id == id);
    final added = group.bookmarkIds.isEmpty;
    final groups = [
      for (final g in current.groups)
        if (g.id == id)
          g.copyWith(bookmarkIds: added ? {initial.items.single.id} : {})
        else
          g,
    ];
    state = AsyncData(
      BookmarkLibraryState(
        bookmarks: [
          for (final bookmark in initial.items)
            if (groups.any((g) => g.bookmarkIds.contains(bookmark.id)))
              bookmark,
        ],
        groups: groups,
        folders: current.folders,
      ),
    );
    return added ? BookmarkToggleOutcome.added : BookmarkToggleOutcome.removed;
  }
}

class _FavoriteSettings extends ServerFavoriteSettingsNotifier {
  _FavoriteSettings(this.ignore);
  final bool ignore;
  @override
  FutureOr<ServerFavoriteSettings> build() => ServerFavoriteSettings(
    globalGroupId: _groupId,
    ignoreBookmarkStatus: ignore,
  );
}
