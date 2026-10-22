import 'package:flutter/foundation.dart' show debugPrint;
import 'package:boorusama/core/widgets/multi_select_button.dart';
import 'package:boorusama/core/configs/config/providers.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:foundation/performance.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:selection_mode/selection_mode.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_library_service.dart';

import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:uuid/uuid.dart';
import 'package:oktoast/oktoast.dart';

import 'package:boorusama/core/bookmarks/src/data/bookmark_convert.dart';
import 'package:boorusama/core/bookmarks/src/pages/bookmark_group_browser_page.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_collection_order.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_collection_deletion_summary.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_context_menu_section.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_folder_picker_contents.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_group_picker.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_multi_selection.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/groups/folder_tree.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/material.dart' as legacy;
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../application/support/fake_image_dio.dart';
import '../posts/details/progressive_image_test_utils.dart';

void main() {
  testWidgets(
    'covered browsers defer preview filtering and show current groups when revealed',
    (tester) async {
      final visible = ValueNotifier(true);
      addTearDown(visible.dispose);
      addTearDown(performanceRecorder.clear);
      final library = _Library(_state(groups: [_group('g', 'Before')]));
      await _pump(
        tester,
        library,
        home: ValueListenableBuilder<bool>(
          valueListenable: visible,
          builder: (_, enabled, child) =>
              TickerMode(enabled: enabled, child: child!),
          child: const BookmarkGroupBrowserPage(),
        ),
      );
      visible.value = false;
      await tester.pumpAndSettle();
      performanceRecorder.start();
      library.publish(groups: [_group('g', 'After')]);
      await tester.pumpAndSettle();
      final summary = performanceRecorder.snapshot()['summary'] as Map;
      expect(
        (summary['operations'] as List).where(
          (dynamic op) => op['op'] == 'bookmarkSelect',
        ),
        isEmpty,
      );
      expect(find.text('Before'), findsOneWidget);
      expect(find.text('After'), findsNothing);
      visible.value = true;
      await tester.pumpAndSettle();
      expect(find.text('After'), findsOneWidget);
      expect(find.text('Before'), findsNothing);
      final revealed = performanceRecorder.snapshot()['summary'] as Map;
      expect(
        (revealed['operations'] as List).where(
          (dynamic op) => op['op'] == 'bookmarkSelect',
        ),
        isNotEmpty,
      );
    },
  );

  for (final count in [1, 2]) {
    testWidgets(
      'duplicates $count selected groups immediately and closes selection',
      (tester) async {
        final originals = [
          for (var i = 0; i < count; i++)
            _group('g$i', 'Saved $i', bookmarks: {1}),
        ];
        final library = _Library(
          _state(groups: originals, bookmarks: [_bookmark]),
        );
        await _pump(tester, library, size: const Size(320, 700), textScale: 2);
        await tester.longPress(find.text('Saved 0'));
        for (var i = 1; i < count; i++) {
          await tester.tap(find.text('Saved $i'));
        }
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(MultiSelectButton, 'Duplicate'));
        await tester.pumpAndSettle();
        expect(_alertDialogs(), findsNothing);
        expect(find.byTooltip('Close'), findsNothing);
        expect(library.library.groups.take(count), originals);
        expect(library.library.groups.skip(count).map((g) => g.name), [
          for (var i = 0; i < count; i++) 'Saved $i Copy',
        ]);
        expect(
          library.library.groups
              .skip(count)
              .every((g) => g.bookmarkIds.contains(1)),
          isTrue,
        );
      },
    );
  }

  testWidgets('the ordinary group menu duplicates without a naming dialog', (
    tester,
  ) async {
    final library = _Library(_state(groups: [_group('g', 'Saved')]));
    await _pump(tester, library);
    await _menu(tester, 'Saved');
    await tester.tap(find.text('Duplicate'));
    await tester.pumpAndSettle();
    expect(_alertDialogs(), findsNothing);
    expect(library.library.groups.map((g) => g.name), ['Saved', 'Saved Copy']);
  });

  testWidgets('failed duplication retains selection without naming dialogs', (
    tester,
  ) async {
    final library = _Library(_state(groups: [_group('g', 'Saved')]))
      ..failDuplicates = true;
    await _pump(tester, library);
    await tester.longPress(find.text('Saved'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MultiSelectButton, 'Duplicate'));
    await tester.pumpAndSettle();
    expect(find.text('1 item selected'), findsOneWidget);
    expect(_alertDialogs(), findsNothing);
    expect(library.library.groups, hasLength(1));
    await tester.pump(const Duration(seconds: 5));
  });

  for (final folder in [false, true]) {
    testWidgets(
      'successful ${folder ? 'folder' : 'group'} rename closes selection, cancellation retains it',
      (tester) async {
        final library = _Library(
          _state(
            groups: folder ? [] : [_group('g', 'Saved')],
            folders: folder
                ? [const CollectionFolder(id: 'f', name: 'Saved')]
                : [],
          ),
        );
        await _pump(tester, library);
        await tester.longPress(find.text('Saved'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(
            MultiSelectButton,
            folder ? 'Rename folder' : 'Rename',
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('1 item selected'), findsOneWidget);
        await tester.tap(
          find.widgetWithText(
            MultiSelectButton,
            folder ? 'Rename folder' : 'Rename',
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(legacy.TextField), 'Renamed');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(find.text('Renamed'), findsOneWidget);
        expect(find.text('1 item selected'), findsNothing);
      },
    );
  }

  for (final sample in [
    (folders: 0, groups: 2, unique: 0, expected: '• 2 bookmark groups'),
    (
      folders: 1,
      groups: 2,
      unique: 3,
      expected: '• 1 folder\n• 2 bookmark groups\n• 3 unique bookmarks',
    ),
    (folders: 0, groups: 0, unique: 1, expected: '• 1 unique bookmark'),
  ]) {
    testWidgets('deletion summary omits zeros for $sample', (tester) async {
      await _pump(
        tester,
        _Library(_state()),
        size: const Size(320, 700),
        textScale: 2,
        home: legacy.Scaffold(
          body: legacy.AlertDialog(
            scrollable: true,
            content: BookmarkCollectionDeletionSummary(
              folders: sample.folders,
              groups: sample.groups,
              uniqueBookmarks: sample.unique,
            ),
          ),
        ),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(
        find.text('This will permanently delete:\n${sample.expected}'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a failed collection move retains its selected targets', (
    tester,
  ) async {
    final library = _Library(
      _state(
        groups: [_group('selected', 'Saved')],
        folders: [
          const CollectionFolder(id: 'destination', name: 'Destination'),
        ],
      ),
    )..failMoves = true;
    await _pump(tester, library);
    await tester.longPress(find.text('Saved'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MultiSelectButton, 'Move'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: _alertDialogs(), matching: find.text('Destination')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move here'));
    await tester.pumpAndSettle();
    expect(find.text('1 item selected'), findsOneWidget);
    expect(library.library.groups.single.folderId, isNull);
    dismissAllToast();
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets(
    'selection reuses bookmark previews instead of re-sorting the library',
    (tester) async {
      final bookmarks = [
        for (var i = 1; i <= 3000; i++)
          _bookmark.copyWith(id: i, postId: () => i),
      ];
      await _pump(
        tester,
        _Library(
          _state(
            bookmarks: bookmarks,
            groups: [
              for (var i = 0; i < 20; i++)
                _group(
                  '$i',
                  'Group $i',
                  bookmarks: {for (var id = 1; id <= 3000; id++) id},
                ),
            ],
          ),
        ),
      );
      performanceRecorder.start();
      addTearDown(performanceRecorder.clear);
      final elapsed = Stopwatch()..start();
      await tester.longPress(find.text('Group 0'));
      await tester.pump();
      await tester.tap(find.text('Group 0'));
      await tester.pump();
      elapsed.stop();
      performanceRecorder.stop();
      final summary = performanceRecorder.snapshot()['summary']! as Map;
      final operations = (summary['operations'] as List)
          .where((op) => (op as Map)['op'] == 'bookmarkSelect')
          .toList();
      debugPrint(
        'Bookmark selection sample: ${elapsed.elapsedMilliseconds}ms, operations=$operations',
      );
      expect(operations, isEmpty);
    },
  );

  for (final (width, scale) in [
    (320.0, 1.0),
    (320.0, 2.0),
    (600.0, 2.0),
    (900.0, 2.0),
  ]) {
    testWidgets(
      'group cards stay square and fit titles at $width and ${scale}x',
      (
        tester,
      ) async {
        final titles = [
          'A',
          'B two line title',
          'C three or more lines of bookmark group names',
          "D ${List.filled(12, 'Lesezeichen 日本語').join(' ')}",
          'E' * 100,
        ];
        await _pump(
          tester,
          _Library(
            _state(
              groups: [
                for (var i = 0; i < titles.length; i++) _group('$i', titles[i]),
              ],
            ),
          ),
          size: Size(width, 5000),
          textScale: scale,
        );
        for (final title in titles) {
          final finder = find.text(title);
          final text = tester.widget<Text>(finder);
          expect(text.style!.fontSize, inInclusiveRange(12, 16));
          expect(text.textScaler!.scale(12), 12 * scale);
          final paragraph = tester.renderObject<RenderParagraph>(finder);
          if (text.style!.fontSize! > 12) {
            expect(paragraph.didExceedMaxLines, isFalse);
            expect(text.overflow, TextOverflow.visible);
          } else {
            expect(text.overflow, TextOverflow.ellipsis);
            expect(text.maxLines, greaterThanOrEqualTo(1));
          }
          final card = find
              .ancestor(of: finder, matching: find.byType(InkWell))
              .first;
          final preview = find.descendant(
            of: card,
            matching: find.byType(BookmarkGroupPreviewGrid),
          );
          expect(
            tester.getRect(preview).contains(tester.getRect(finder).topLeft),
            isTrue,
          );
          expect(
            tester
                .getRect(preview)
                .contains(tester.getRect(finder).bottomRight),
            isTrue,
          );
          expect(
            tester.getRect(card).contains(tester.getRect(finder).bottomLeft),
            isTrue,
          );
        }
        final cards = [
          for (final title in titles) tester.getRect(_cardInk(title)),
        ];
        for (var i = 0; i < cards.length; i++) {
          for (var j = i + 1; j < cards.length; j++) {
            expect(cards[i].overlaps(cards[j]), isFalse);
          }
        }
        for (final card in cards) {
          expect(card.height, closeTo(card.width, 0.001));
          expect(card.size, cards.first.size);
        }
        final columns = width < 500
            ? 2
            : width < 850
            ? 3
            : 4;
        for (var i = 0; i < cards.length; i++) {
          expect(cards[i].top, cards[i ~/ columns * columns].top);
          if (i >= columns) {
            expect(
              cards[i].top - cards[i - columns].bottom,
              closeTo(12, 0.001),
            );
          }
        }
        expect(tester.widget<Text>(find.text('A')).style!.fontSize, 16);
        expect(tester.widget<Text>(find.text(titles.last)).style!.fontSize, 12);
        final longCard = _cardInk(titles.last);
        final menu = find.descendant(
          of: longCard,
          matching: find.byType(PopupMenuButton<String>),
        );
        expect(
          tester.getRect(menu).overlaps(tester.getRect(find.text(titles.last))),
          isFalse,
        );
        final titleRect = tester.getRect(find.text(titles.last));
        final cardRect = tester.getRect(longCard);
        expect(titleRect.bottom, greaterThan(cardRect.center.dy));
        expect(titleRect.bottom, lessThanOrEqualTo(cardRect.bottom - 8));
        expect(tester.getRect(menu).left - titleRect.right, closeTo(0, 0.001));
        await tester.tap(menu);
        await tester.pumpAndSettle();
        expect(find.text('Rename'), findsOneWidget);
        expect(find.text('Duplicate'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'preview is uniformly shaded without separate title or menu backgrounds',
    (
      tester,
    ) async {
      final boundaryKey = GlobalKey();
      await _pump(
        tester,
        _Library(_state(groups: [_group('g', 'Saved')])),
        size: const Size(320, 700),
        home: RepaintBoundary(
          key: boundaryKey,
          child: Theme(
            data: ThemeData(scaffoldBackgroundColor: Colors.cyan),
            child: const BookmarkGroupBrowserPage(),
          ),
        ),
      );
      final card = _cardInk('Saved');
      final cardRect = tester.getRect(card);
      final titleRect = tester.getRect(find.text('Saved'));
      final menuRect = tester.getRect(
        find.descendant(
          of: card,
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final origin = tester.getTopLeft(find.byKey(boundaryKey));
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        try {
          final bytes = (await image.toByteData())!;
          List<int> pixel(Offset point) {
            final local = point - origin;
            final offset =
                (local.dy.floor() * image.width + local.dx.floor()) * 4;
            return [for (var i = 0; i < 4; i++) bytes.getUint8(offset + i)];
          }

          final lowerPreview = pixel(
            cardRect.bottomCenter - const Offset(0, 12),
          );
          expect(lowerPreview[1], inExclusiveRange(0, 188));
          expect(lowerPreview[2], inExclusiveRange(0, 212));
          // The same gradient continues around the text and through the menu's
          // empty touch-target padding, without a separate dark rectangle.
          for (final (point, referenceX) in [
            (titleRect.topLeft + const Offset(2, -4), cardRect.center.dx),
            (menuRect.topRight + const Offset(-2, 20), cardRect.right - 2),
          ]) {
            final actual = pixel(point);
            final backdrop = pixel(Offset(referenceX, point.dy));
            // Allow the soft text shadow's small antialiasing contribution.
            for (var channel = 0; channel < 4; channel++) {
              expect(actual[channel], closeTo(backdrop[channel], 3));
            }
          }
        } finally {
          image.dispose();
        }
      });
      expect(tester.takeException(), isNull);
    },
  );

  test('case-insensitive ordering uses identity to break equal-name ties', () {
    final groups = bookmarkGroupsByName([
      _group('z', 'alpha'),
      _group('a', 'Alpha'),
      _group('b', 'Beta'),
    ]);
    expect(groups.map((g) => g.id).toSet(), {_id('a'), _id('z'), _id('b')});
    expect(groups.take(2).map((g) => g.id), ([_id('a'), _id('z')]..sort()));
    expect(
      bookmarkFoldersByName([
        const CollectionFolder(id: 'z', name: 'alpha'),
        const CollectionFolder(id: 'a', name: 'Alpha', position: 9),
      ]).map((f) => f.id),
      ['a', 'z'],
    );
  });

  test(
    'recursive badges count groups once, including deep and repeated names',
    () {
      final folders = [
        const CollectionFolder(id: 'root', name: 'Artists'),
        for (var i = 0; i < 120; i++)
          CollectionFolder(
            id: 'f$i',
            name: 'Folder',
            parentId: i == 0 ? 'root' : 'f${i - 1}',
          ),
      ];
      final groups = [
        _group('direct', 'Same', folder: 'root'),
        for (var i = 0; i < 120; i++) _group('g$i', 'Same', folder: 'f$i'),
        _group('outside', 'Same'),
      ];
      final counts = bookmarkFolderMembershipCounts(
        folders: folders,
        groups: [...groups, groups.first],
        membershipGroupIds: groups.map((g) => g.id).toSet(),
      );
      expect(counts['root'], 121);
      expect(counts['f119'], 1);
      expect(counts['f0'], 120);
      expect(
        bookmarkFolderMembershipCounts(
          folders: folders,
          groups: groups,
          membershipGroupIds: {},
        ),
        isEmpty,
      );
    },
  );

  for (final (width, textScale) in [(400.0, 1.0), (320.0, 1.8)]) {
    testWidgets(
      'Home shortcuts precede divider, folders, and alphabetical groups ($width, $textScale)',
      (tester) async {
        final library = _state(
          folders: [
            const CollectionFolder(id: 'z', name: 'zebra'),
            const CollectionFolder(id: 'a', name: 'Artists', position: 9),
          ],
          groups: [
            BookmarkGroup(
              id: defaultBookmarkGroupId,
              name: 'Default',
              bookmarkIds: {},
            ),
            _group('ordinary-default', 'Default'),
            _group('z', 'z group'),
            _group('a', 'alpha group'),
          ],
        );
        await _pump(
          tester,
          _Library(library),
          size: Size(width, 1200),
          textScale: textScale,
        );
        expect(_above(tester, 'All', 'Artists'), isTrue);
        expect(find.text('No Group'), findsNothing);
        expect(find.text('Default'), findsNWidgets(2));
        final all = tester.getRect(find.text('All'));
        final systemDefault = tester.getRect(find.text('Default').first);
        expect(systemDefault.top, all.top);
        expect(systemDefault.left, greaterThan(all.right));
        expect(_above(tester, 'Artists', 'zebra'), isTrue);
        expect(_above(tester, 'zebra', 'alpha group'), isTrue);
        expect(_above(tester, 'alpha group', 'z group'), isTrue);
        final divider = tester.getRect(find.byType(Divider));
        expect(
          divider.top,
          greaterThan(tester.getRect(find.text('All')).bottom),
        );
        expect(divider.top, greaterThan(systemDefault.bottom));
        expect(
          divider.bottom,
          lessThan(tester.getRect(find.text('Default').last).top),
        );
        expect(
          divider.bottom,
          lessThan(tester.getRect(find.text('Artists')).top),
        );
        expect(find.byIcon(Icons.create_new_folder_outlined), findsNothing);
        await tester.tap(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byType(PopupMenuButton<String>),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Add groups folder'), findsOneWidget);
        expect(find.text('Add group'), findsOneWidget);
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        await _menu(tester, 'alpha group');
        expect(find.text('Move Up'), findsNothing);
        expect(find.text('Move Down'), findsNothing);
        expect(find.text('Move'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'Home shortcuts are inaccessible during selection and recover navigation',
    (tester) async {
      final semantics = tester.ensureSemantics();

      final library = _Library(
        _state(
          groups: [
            BookmarkGroup(
              id: defaultBookmarkGroupId,
              name: 'Default',
              bookmarkIds: {},
            ),
            _group('g', 'Saved'),
          ],
        ),
      );
      final router = await _pump(tester, library);
      await tester.longPress(find.text('Saved'));
      await tester.pumpAndSettle();
      for (final label in ['All', 'Default']) {
        final ink = tester.widget<InkWell>(_cardInk(label));
        expect(ink.onTap, isNull);
        final opacity = tester.widget<Opacity>(
          find
              .ancestor(of: find.text(label), matching: find.byType(Opacity))
              .first,
        );
        expect(opacity.opacity, lessThan(1));
        final node = tester.getSemantics(find.text(label));
        expect(
          node.getSemanticsData().flagsCollection.isEnabled,
          Tristate.isFalse,
        );
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/');
        expect(find.text('1 item selected'), findsOneWidget);
      }
      expect(library.targets, isEmpty);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.text('opened all'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets(
    'creation and rename use current folder and immediately sort new names',
    (tester) async {
      final library = _Library(
        _state(
          folders: [
            const CollectionFolder(id: 'root', name: 'Artists'),
          ],
          groups: [
            _group('a', 'Alpha', folder: 'root'),
            _group('z', 'Zeta', folder: 'root'),
          ],
        ),
      );
      await _pump(tester, library);
      await tester.tap(find.text('Artists'));
      await tester.pumpAndSettle();
      expect(find.text('All'), findsNothing);
      expect(find.byType(Divider), findsNothing);
      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add groups folder'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(legacy.TextField), ' Child ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(library.library.folders.last.parentId, 'root');
      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add group'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(legacy.TextField), ' New ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(library.library.groups.last.folderId, 'root');
      await _menu(tester, 'Zeta');
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(legacy.TextField), 'Aardvark');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(_above(tester, 'Aardvark', 'Alpha'), isTrue);
    },
  );

  for (final movingFolder in [false, true]) {
    testWidgets(
      'Move starts in current parent, excludes descendants, and confirms Home ($movingFolder)',
      (tester) async {
        final library = _Library(
          _state(
            folders: [
              const CollectionFolder(id: 'root', name: 'Artists'),
              const CollectionFolder(
                id: 'child',
                name: 'Child',
                parentId: 'root',
              ),
              const CollectionFolder(
                id: 'deep',
                name: 'Deep',
                parentId: 'child',
              ),
            ],
            groups: [_group('g', 'Saved', folder: 'root')],
          ),
        );
        await _pump(tester, library);
        await tester.tap(find.text('Artists'));
        await tester.pumpAndSettle();
        await _menu(tester, movingFolder ? 'Child' : 'Saved');
        await tester.tap(find.text('Move'));
        await tester.pumpAndSettle();
        final dialog = _alertDialogs();
        expect(
          find.descendant(of: dialog, matching: find.text('Artists')),
          findsOneWidget,
        );
        expect(_moveButton(tester).onPressed, isNull);
        if (movingFolder) {
          expect(
            find.descendant(of: dialog, matching: find.text('Child')),
            findsNothing,
          );
          expect(
            find.descendant(of: dialog, matching: find.text('Deep')),
            findsNothing,
          );
        } else {
          await tester.tap(
            find.descendant(of: dialog, matching: find.text('Child')),
          );
          await tester.pumpAndSettle();
          expect(_moveButton(tester).onPressed, isNotNull);
          expect(
            find.descendant(of: dialog, matching: find.text('Deep')),
            findsOneWidget,
          );
        }
        await tester.tap(
          find.descendant(of: dialog, matching: find.text('Home')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Move here'));
        await tester.pumpAndSettle();
        expect(library.moves.single.destination, isNull);
        expect(
          movingFolder
              ? library.moves.single.folderIds
              : library.moves.single.groupIds,
          {movingFolder ? 'child' : _id('g')},
        );
      },
    );
  }

  testWidgets(
    'mixed selection Move starts in parent and preserves the selected unit',
    (tester) async {
      final library = _Library(
        _state(
          folders: [
            const CollectionFolder(id: 'root', name: 'Artists'),
            const CollectionFolder(
              id: 'child',
              name: 'Child',
              parentId: 'root',
            ),
          ],
          groups: [_group('g', 'Saved', folder: 'root')],
        ),
      );
      await _pump(tester, library);
      await tester.tap(find.text('Artists'));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Saved'));
      await tester.tap(find.text('Child'));
      await tester.pumpAndSettle();
      expect(find.text('2 items selected'), findsOneWidget);
      await tester.tap(find.widgetWithText(MultiSelectButton, 'Move'));
      await tester.pumpAndSettle();
      expect(_moveButton(tester).onPressed, isNull);
      await tester.tap(
        find.descendant(
          of: _alertDialogs(),
          matching: find.text('Home'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move here'));
      await tester.pumpAndSettle();
      expect(library.moves.single.groupIds, {_id('g')});
      expect(library.moves.single.folderIds, {'child'});
      expect(library.moves.single.destination, isNull);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'bookmark menu matches normal context row typography and height at ${scale}x text',
      (tester) async {
        await _pump(
          tester,
          _Library(_state()),
          size: const Size(320, 700),
          textScale: scale,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    KurumiContextMenuTile(title: 'Normal', onTap: () {}),
                    BookmarkPickerMenuItem(
                      title: 'Saved',
                      icon: const Icon(Symbols.bookmarks),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        final normal = tester.getSize(find.byType(KurumiContextMenuTile));
        final bookmark = tester.getSize(find.byType(BookmarkPickerMenuItem));
        expect(bookmark.height, normal.height);
        TextStyle? style(String label) => tester
            .widget<RichText>(
              find.descendant(
                of: find.text(label),
                matching: find.byType(RichText),
              ),
            )
            .text
            .style;
        final expected = style('Normal')!;
        final actual = style('Saved')!;
        expect(actual.fontSize, expected.fontSize);
        expect(actual.height, expected.height);
        expect(actual.fontWeight, expected.fontWeight);
        expect(actual.letterSpacing, expected.letterSpacing);
        expect(
          tester.getSize(find.byIcon(Symbols.bookmarks)),
          const Size(20, 20),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'bookmark submenu text spacing matches actual context items at ${scale}x text',
      (tester) async {
        await _pump(
          tester,
          _Library(
            _state(groups: [_group('one', 'One'), _group('two', 'Two')]),
          ),
          home: _Launcher(entry: 'context', post: _bookmark.toPost()),
          size: const Size(320, 700),
          textScale: scale,
        );
        await tester.longPress(find.text('Open picker'));
        await tester.pumpAndSettle();
        final first = tester.getRect(find.text('Normal'));
        final second = tester.getRect(find.text('Other'));
        final gap = second.top - first.bottom;
        final step = second.top - first.top;
        await tester.tap(find.text('Bookmark'));
        await tester.pumpAndSettle();
        final one = tester.getRect(find.text('One'));
        final two = tester.getRect(find.text('Two'));
        expect(two.top - one.bottom, gap);
        expect(two.top - one.top, step);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final entry in ['anchored', 'context']) {
    testWidgets('$entry popup uses compact rows and separators at each level', (
      tester,
    ) async {
      final library = _Library(
        _state(
          folders: [
            const CollectionFolder(id: 'root', name: 'Artists'),
            const CollectionFolder(
              id: 'child',
              name: 'Cookie',
              parentId: 'root',
            ),
          ],
          groups: [
            _group('plain', 'Saved'),
            _group('nested', 'Nested', folder: 'root'),
          ],
        ),
      );
      await _pump(
        tester,
        library,
        home: _Launcher(entry: entry, post: _bookmark.toPost()),
      );
      if (entry == 'context') {
        await tester.longPress(find.text('Open picker'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bookmark'));
      } else {
        await tester.tap(find.text('Open picker'));
      }
      await tester.pumpAndSettle();
      final picker = find.byType(BookmarkFolderPickerContents);
      void expectMenu() {
        expect(
          find.descendant(
            of: picker,
            matching: find.byType(legacy.ListTile),
          ),
          findsNothing,
        );
        final rows = find.descendant(
          of: picker,
          matching: find.byType(BookmarkPickerMenuItem),
        );
        expect(rows, findsWidgets);
        final rectangles = <Rect>[];
        for (final row in rows.evaluate()) {
          final item = find.byWidget(row.widget);
          expect(
            find.descendant(
              of: item,
              matching: find.byType(KurumiPopupMenuItem),
            ),
            findsOneWidget,
          );
          rectangles.add(tester.getRect(item));
        }
        expect(
          rectangles.map((r) => r.height).toSet().length,
          1,
          reason: rectangles.map((r) => r.height).toList().toString(),
        );
        final back = find.descendant(of: picker, matching: find.text('Back'));
        final dividers = find.descendant(
          of: picker,
          matching: find.byType(Divider),
        );
        expect(
          dividers,
          back.evaluate().isEmpty ? findsOneWidget : findsNWidgets(2),
        );
        for (final divider in tester.widgetList<Divider>(dividers)) {
          expect(divider.height, 8);
          expect(divider.indent, 12);
          expect(divider.endIndent, 12);
        }
        final creation = tester.getRect(
          find.descendant(of: picker, matching: find.text('Create new group')),
        );
        expect(
          tester.getRect(dividers.last).bottom,
          lessThanOrEqualTo(creation.top),
        );
        if (back.evaluate().isNotEmpty) {
          expect(
            tester.getRect(dividers.first).top,
            greaterThanOrEqualTo(tester.getRect(back).bottom),
          );
        }
      }

      expectMenu();
      if (entry == 'anchored') {
        expect(find.byType(KurumiAnchor), findsWidgets);
        expect(tester.getSize(picker).width, lessThanOrEqualTo(200));
        expect(_alertDialogs(), findsNothing);
      }
      await tester.tap(find.text('Artists'));
      await tester.pumpAndSettle();
      expectMenu();
      await tester.tap(find.text('Cookie'));
      await tester.pumpAndSettle();
      expectMenu();
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Nested'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'anchored popup scrolls many groups without growing beyond the viewport',
    (tester) async {
      final library = _Library(
        _state(
          groups: [
            for (var i = 0; i < 40; i++)
              _group('g$i', 'Saved ${i.toString().padLeft(2, '0')}'),
          ],
        ),
      );
      await _pump(
        tester,
        library,
        home: _Launcher(entry: 'anchored', post: _bookmark.toPost()),
        size: const Size(320, 700),
        textScale: 2,
      );
      await tester.tap(find.text('Open picker'));
      await tester.pumpAndSettle();
      final picker = find.byType(BookmarkFolderPickerContents);
      expect(tester.getSize(picker).height, lessThanOrEqualTo(420));
      await tester.scrollUntilVisible(
        find.text('Saved 39'),
        150,
        scrollable: find
            .descendant(of: picker, matching: find.byType(Scrollable))
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Saved 39').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Saved 39'));
      await tester.pumpAndSettle();
      expect(library.toggles.single, BookmarkTarget.group(_id('g39')));
      expect(find.text('Open picker'), findsOneWidget);
      expect(find.byType(BookmarkFolderPickerContents), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    },
  );

  for (final entry in [
    'dialog',
    'anchored',
    'context',
    'bulk add',
    'bulk remove',
    'legacy add',
    'legacy remove',
  ]) {
    testWidgets(
      '$entry picker navigates nested folders, badges, and repeated leaf names',
      (tester) async {
        final bookmark = _bookmark;
        final library = _Library(
          _state(
            bookmarks: [bookmark],
            folders: [
              const CollectionFolder(id: 'root', name: 'Artists'),
              const CollectionFolder(
                id: 'child',
                name: 'Cookie',
                parentId: 'root',
              ),
              const CollectionFolder(id: 'other', name: 'Empty'),
            ],
            groups: [
              _group('root-group', 'Shared', folder: 'root', bookmarks: {1}),
              _group('deep-group', 'Shared', folder: 'child', bookmarks: {1}),
              _group('plain', 'Other', folder: 'child'),
            ],
          ),
        );
        await _pump(
          tester,
          library,
          home: _Launcher(entry: entry, post: bookmark.toPost()),
        );
        if (entry == 'context') {
          await tester.longPress(find.text('Open picker'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Bookmark'));
        } else {
          await tester.tap(find.text('Open picker'));
        }
        await tester.pumpAndSettle();
        if (entry.startsWith('legacy')) {
          await tester.tap(
            find.text(
              entry == 'legacy add' ? 'Add to group' : 'Remove from group',
            ),
          );
          await tester.pumpAndSettle();
        }
        expect(find.text('Artists'), findsOneWidget);
        expect(find.text('Shared'), findsNothing);
        final icon = tester.widget<BookmarkFolderMembershipIcon>(
          find.descendant(
            of: find.ancestor(
              of: find.text('Artists'),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is legacy.ListTile ||
                    widget is BookmarkPickerMenuItem,
              ),
            ),
            matching: find.byType(BookmarkFolderMembershipIcon),
          ),
        );
        expect(icon.count, 2);
        expect(library.toggles, isEmpty);
        await tester.tap(find.text('Artists'));
        await tester.pumpAndSettle();
        expect(find.text('Shared'), findsOneWidget);
        final membershipIcon = tester.widget<Icon>(
          find.byIcon(Symbols.bookmarks),
        );
        expect(membershipIcon.fill, 1);
        expect(find.textContaining('Artists /'), findsNothing);
        await tester.tap(find.text('Cookie'));
        await tester.pumpAndSettle();
        expect(find.text('Shared'), findsOneWidget);
        expect(library.toggles, isEmpty);
        // Update the snapshot while the picker stays open, then navigate back.
        library.publish(
          groups: [
            for (final group in library.library.groups)
              group.id == _id('deep-group')
                  ? group.copyWith(bookmarkIds: {})
                  : group,
          ],
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Back').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Home').first);
        await tester.pumpAndSettle();
        final updated = tester.widget<BookmarkFolderMembershipIcon>(
          find.descendant(
            of: find.ancestor(
              of: find.text('Artists'),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is legacy.ListTile ||
                    widget is BookmarkPickerMenuItem,
              ),
            ),
            matching: find.byType(BookmarkFolderMembershipIcon),
          ),
        );
        expect(updated.count, 1);
        await tester.tap(find.text('Artists'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Shared'));
        await tester.pumpAndSettle();
        if (entry.startsWith('bulk')) {
          expect(_Launcher.result?.id, _id('root-group'));
        } else if (entry.startsWith('legacy')) {
          expect(library.legacyGroups.single, _id('root-group'));
        } else {
          expect(
            library.toggles.single,
            BookmarkTarget.group(_id('root-group')),
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      },
    );
  }

  for (final entry in [
    'dialog',
    'anchored',
    'context',
    'bulk add',
    'legacy add',
  ]) {
    testWidgets('$entry creates groups in the currently displayed folder', (
      tester,
    ) async {
      final library = _Library(
        _state(
          folders: [
            const CollectionFolder(id: 'root', name: 'Artists'),
            const CollectionFolder(
              id: 'child',
              name: 'Cookie',
              parentId: 'root',
            ),
          ],
          bookmarks: [_bookmark],
        ),
      );
      await _pump(
        tester,
        library,
        home: _Launcher(entry: entry, post: _bookmark.toPost()),
      );
      if (entry == 'context') {
        await tester.longPress(find.text('Open picker'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bookmark'));
      } else {
        await tester.tap(find.text('Open picker'));
      }
      await tester.pumpAndSettle();
      if (entry == 'legacy add') {
        await tester.tap(find.text('Add to group'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Artists'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cookie'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create new group'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(legacy.TextField), 'Nested group');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(library.library.groups.single.folderId, 'child');
      expect(library.library.groups.single.name, 'Nested group');
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('bulk multi-post picker omits ambiguous folder badges', (
    tester,
  ) async {
    final library = _Library(
      _state(
        folders: [const CollectionFolder(id: 'f', name: 'Artists')],
        groups: [_group('g', 'Saved', folder: 'f')],
      ),
    );
    await _pump(
      tester,
      library,
      home: _Launcher(entry: 'bulk add', post: _bookmark.toPost(), multi: true),
    );
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<BookmarkFolderMembershipIcon>(
            find.byType(BookmarkFolderMembershipIcon),
          )
          .count,
      0,
    );
    expect(
      tester.widget<legacy.Badge>(find.byType(legacy.Badge)).isLabelVisible,
      isFalse,
    );
  });

  for (final entry in ['dialog', 'anchored', 'context', 'bulk add']) {
    testWidgets(
      '$entry picker fits narrow width with enlarged text and long names',
      (tester) async {
        const longName = 'A very long literal // folder name for artists';
        final library = _Library(
          _state(
            folders: [
              const CollectionFolder(id: 'root', name: longName),
              const CollectionFolder(
                id: 'child',
                name: 'Nested',
                parentId: 'root',
              ),
            ],
            groups: [
              _group(
                'g',
                'A long group name without a folder prefix',
                folder: 'child',
              ),
            ],
          ),
        );
        await _pump(
          tester,
          library,
          home: _Launcher(entry: entry, post: _bookmark.toPost()),
          size: const Size(320, 700),
          textScale: 2,
        );
        if (entry == 'context') {
          await tester.longPress(find.text('Open picker'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Bookmark'));
        } else {
          await tester.tap(find.text('Open picker'));
        }
        await tester.pumpAndSettle();
        await tester.tap(find.text(longName));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Nested'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nested'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('A long group name without a folder prefix'),
          100,
          scrollable: find
              .descendant(
                of: find.byType(BookmarkFolderPickerContents),
                matching: find.byType(Scrollable),
              )
              .last,
        );
        expect(
          find.text('A long group name without a folder prefix'),
          findsOneWidget,
        );
        expect(find.text('Back'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'naming dialog keeps Save and Cancel usable with keyboard and enlarged text',
    (tester) async {
      final library = _Library(_state());
      await _pump(tester, library, size: const Size(320, 700), textScale: 2);
      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add group'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(find.byType(legacy.TextField), 'Home group');
      await tester.pumpAndSettle();
      expect(find.text('Cancel').hitTestable(), findsOneWidget);
      expect(find.text('Save').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(library.library.groups.single.folderId, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'badge caps visual count but exposes full count to accessibility',
    (tester) async {
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        const BooruLocalization(
          child: MaterialApp(
            home: Scaffold(body: BookmarkFolderMembershipIcon(count: 123)),
          ),
        ),
      );
      expect(find.text('99+'), findsOneWidget);
      expect(
        find.bySemanticsLabel('123 groups contain this bookmark'),
        findsOneWidget,
      );
      await tester.pumpWidget(
        const BooruLocalization(
          child: MaterialApp(
            home: Scaffold(body: BookmarkFolderMembershipIcon(count: 0)),
          ),
        ),
      );
      expect(
        tester.widget<legacy.Badge>(find.byType(legacy.Badge)).isLabelVisible,
        isFalse,
      );
      semantics.dispose();
    },
  );
}

bool _above(WidgetTester tester, String a, String b) {
  final first = tester.getRect(find.text(a));
  final second = tester.getRect(find.text(b));
  return first.top < second.top ||
      (first.top == second.top && first.left < second.left);
}

Finder _cardInk(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;

Finder _alertDialogs() => find.byWidgetPredicate(
  (widget) => widget.runtimeType.toString() == 'AlertDialog',
);
Future<void> _menu(WidgetTester tester, String label) async {
  final card = _cardInk(label);
  await tester.tap(
    find.descendant(of: card, matching: find.byType(PopupMenuButton<String>)),
  );
  await tester.pumpAndSettle();
}

legacy.FilledButton _moveButton(WidgetTester tester) =>
    tester.widget<legacy.FilledButton>(
      find.ancestor(
        of: find.text('Move here'),
        matching: find.byType(legacy.FilledButton),
      ),
    );

final _config = BooruConfig.fromJson({
  ...BooruConfig.defaultConfig(
    booruType: BooruType.gelbooruV2,
    url: 'https://gelbooru.example',
    customDownloadFileNameFormat: null,
  ).toJson(),
  'id': '00000000-0000-4000-8000-00000000000c',
});
final _bookmark = Bookmark.empty.copyWith(
  id: 1,
  postId: () => 42,
  sourceUrl: 'https://gelbooru.example',
  originalUrl: 'https://gelbooru.example/image.jpg',
);
BookmarkGroup _group(
  String id,
  String name, {
  String? folder,
  Set<int> bookmarks = const {},
}) => BookmarkGroup(
  id: _id(id),
  name: name,
  bookmarkIds: bookmarks,
  folderId: folder,
);
BookmarkLibraryState _state({
  List<CollectionFolder> folders = const [],
  List<BookmarkGroup> groups = const [],
  List<Bookmark> bookmarks = const [],
}) => BookmarkLibraryState(
  bookmarks: bookmarks,
  groups: groups,
  folders: folders,
  activeTarget: const BookmarkTarget.defaultGroup(),
);

Future<GoRouter> _pump(
  WidgetTester tester,
  _Library library, {
  Widget? home,
  double textScale = 1,
  Size size = const Size(400, 1000),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => home ?? const BookmarkGroupBrowserPage(),
      ),
      GoRoute(
        path: '/bookmarks/group',
        builder: (_, state) =>
            Scaffold(body: Text('opened ${state.uri.queryParameters['kind']}')),
      ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bookmarkProvider.overrideWith(() => library),
        firstMatchingConfigByBooruTypeProvider.overrideWith(
          (ref, _) => BooruConfig.empty,
        ),
        settingsProvider.overrideWithValue(Settings.defaultSettings),
        automaticMediaLoadingEnabledProvider.overrideWithValue(false),
        selectionOptionsProvider.overrideWithValue(
          const SelectionOptions(
            behavior: SelectionBehavior.manual,
            dragSelection: DragSelectionOptions(),
            haptics: null,
          ),
        ),
        routerProvider.overrideWithValue(router),
        deterministicFaviconDioOverride(),
        defaultImageCacheManagerProvider.overrideWithValue(TestImageCache({})),
      ],
      child: OKToast(
        child: BooruLocalization(
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: KurumiTheme(
                data: KurumiThemeData.fromMaterial(Theme.of(context)),
                child: MaterialUiCompatibilityBridge(child: child!),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

class _Launcher extends ConsumerWidget {
  const _Launcher({
    required this.entry,
    required this.post,
    this.multi = false,
  });
  final String entry;
  final Post post;
  final bool multi;
  static BookmarkGroupSelectionTarget? result;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final button = ElevatedButton(
      onPressed: () async {
        if (entry == 'dialog') {
          await showBookmarkGroupPicker(
            context,
            config: _config.auth,
            post: post,
          );
        } else if (entry.startsWith('legacy')) {
          await showBookmarkMultiSelectionActions(
            context,
            ref: ref,
            bookmarks: ref.read(bookmarkProvider).requireValue.items,
          );
        } else {
          result = await showBookmarkGroupSelectionDialog(
            context,
            operation: entry == 'bulk remove'
                ? BookmarkMultiSelectionOperation.remove
                : BookmarkMultiSelectionOperation.add,
            posts: [
              post,
              if (multi) _bookmark.copyWith(id: 2, postId: () => 43).toPost(),
            ],
            config: _config.auth,
          );
        }
      },
      child: const Text('Open picker'),
    );
    return Scaffold(
      body: Center(
        child: entry == 'context'
            ? KurumiContextMenu(
                child: button,
                menuItemsBuilder: (_) => [
                  KurumiContextMenuTile(title: 'Normal', onTap: () {}),
                  KurumiContextMenuTile(title: 'Other', onTap: () {}),
                  BookmarkContextMenuSection(post: post, config: _config.auth),
                ],
              )
            : entry == 'anchored'
            ? BookmarkGroupPickerAnchor(
                config: _config.auth,
                post: post,
                builder: (context, show) => ElevatedButton(
                  onPressed: show,
                  child: const Text('Open picker'),
                ),
              )
            : button,
      ),
    );
  }
}

class _Library extends BookmarkLibraryNotifier {
  _Library(this.library);
  BookmarkLibraryState library;
  var failMoves = false;
  var failDuplicates = false;
  final targets = <BookmarkTarget>[];
  final toggles = <BookmarkTarget>[];
  final legacyGroups = <String>[];
  final moves =
      <({Set<String> folderIds, Set<String> groupIds, String? destination})>[];
  @override
  FutureOr<BookmarkLibraryState> build() => library;
  void publish({List<BookmarkGroup>? groups, List<CollectionFolder>? folders}) {
    library = _state(
      bookmarks: library.items,
      groups: groups ?? library.groups,
      folders: folders ?? library.folders,
    );
    state = AsyncData(library);
  }

  @override
  Future<bool> setActiveTarget(BookmarkTarget target) async {
    targets.add(target);
    return true;
  }

  @override
  Future<BookmarkGroup> createGroup(
    String name, {
    bool activate = false,
    String? folderId,
  }) async {
    final group = _group(
      'new-${library.groups.length}',
      name,
      folder: folderId,
    );
    publish(groups: [...library.groups, group]);
    return group;
  }

  @override
  Future<CollectionFolder> createFolder(String name, {String? parentId}) async {
    final folder = CollectionFolder(
      id: 'new-${library.folders.length}',
      name: name,
      parentId: parentId,
    );
    publish(folders: [...library.folders, folder]);
    return folder;
  }

  @override
  Future<void> renameGroup(String id, String name) async {
    publish(
      groups: [
        for (final group in library.groups)
          group.id == id ? group.copyWith(name: name) : group,
      ],
    );
  }

  @override
  Future<void> renameFolder(String id, String name) async {
    publish(
      folders: [
        for (final folder in library.folders)
          folder.id == id ? folder.copyWith(name: name) : folder,
      ],
    );
  }

  @override
  Future<List<BookmarkGroup>> duplicateGroups(
    Map<String, String> names, {
    required List<BookmarkGroup> expectedGroups,
  }) async {
    if (failDuplicates) throw StateError('Duplicate rejected');
    final copies = [
      for (final group in expectedGroups)
        BookmarkGroup(
          id: _id('copy-${group.id}'),
          name: names[group.id]!,
          bookmarkIds: group.bookmarkIds,
          folderId: group.folderId,
          position: group.position,
        ),
    ];
    publish(groups: [...library.groups, ...copies]);
    return copies;
  }

  @override
  Future<void> moveFolderItems({
    Set<String> folderIds = const {},
    Set<String> groupIds = const {},
    required String? destination,
  }) async {
    if (failMoves) throw StateError('Move rejected');
    moves.add((
      folderIds: Set.of(folderIds),
      groupIds: Set.of(groupIds),
      destination: destination,
    ));
    publish(
      groups: [
        for (final g in library.groups)
          groupIds.contains(g.id)
              ? g.copyWith(folderId: destination, home: destination == null)
              : g,
      ],
      folders: [
        for (final f in library.folders)
          folderIds.contains(f.id)
              ? f.copyWith(parentId: destination, home: destination == null)
              : f,
      ],
    );
  }

  @override
  Future<void> addExistingBookmarksToGroup(
    Iterable<Bookmark> bookmarks,
    String groupId, {
    void Function()? onSuccess,
    void Function()? onError,
  }) async {
    legacyGroups.add(groupId);
  }

  @override
  Future<void> removeFromGroup(
    Iterable<Bookmark> bookmarks,
    String groupId, {
    void Function(BookmarkGroupRemovalResult)? onRemoved,
    void Function()? onSuccess,
    void Function()? onError,
  }) async {
    legacyGroups.add(groupId);
  }

  @override
  Future<({BookmarkGroup group, int addedCount})> createGroupWithPosts(
    String name,
    BooruConfigAuth config,
    Iterable<Post> posts, {
    String? folderId,
  }) async {
    final group = await createGroup(name, folderId: folderId);
    return (group: group, addedCount: posts.length);
  }

  @override
  Future<BookmarkToggleOutcome> togglePostTarget(
    BooruConfigAuth config,
    Post post, {
    BookmarkTarget? target,
    bool activateTarget = false,
    void Function(BookmarkGroupRemovalResult)? onRemoved,
  }) async {
    toggles.add(target!);
    return BookmarkToggleOutcome.added;
  }
}

String _id(String name) => const Uuid().v5(Namespace.url.value, name);
