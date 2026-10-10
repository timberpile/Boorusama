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
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_context_menu_section.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_folder_picker_contents.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_group_picker.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_multi_selection.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/groups/folder_tree.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_symbols_icons/symbols.dart';

void main() {
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
        expect(find.text('1 selected'), findsOneWidget);
      }
      expect(library.targets, isEmpty);
      await tester.tap(find.byTooltip('Cancel'));
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
      await tester.enterText(find.byType(TextField), ' Child ');
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
      await tester.enterText(find.byType(TextField), ' New ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(library.library.groups.last.folderId, 'root');
      await _menu(tester, 'Zeta');
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Aardvark');
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
        final dialog = find.byType(AlertDialog);
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
      expect(find.text('2 selected'), findsOneWidget);
      await tester.tap(find.byTooltip('Move'));
      await tester.pumpAndSettle();
      expect(_moveButton(tester).onPressed, isNull);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
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
          find.descendant(of: picker, matching: find.byType(ListTile)),
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
        expect(find.byType(AlertDialog), findsNothing);
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
                    widget is ListTile || widget is BookmarkPickerMenuItem,
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
                    widget is ListTile || widget is BookmarkPickerMenuItem,
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
      await tester.enterText(find.byType(TextField), 'Nested group');
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
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
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
      await tester.enterText(find.byType(TextField), 'Home group');
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
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
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
Future<void> _menu(WidgetTester tester, String label) async {
  final stack = find
      .ancestor(of: find.text(label), matching: find.byType(Stack))
      .first;
  await tester.tap(
    find.descendant(of: stack, matching: find.byType(PopupMenuButton<String>)),
  );
  await tester.pumpAndSettle();
}

FilledButton _moveButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.ancestor(
    of: find.text('Move here'),
    matching: find.byType(FilledButton),
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
        routerProvider.overrideWithValue(router),
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
                child: child!,
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
  Future<void> moveFolderItems({
    Set<String> folderIds = const {},
    Set<String> groupIds = const {},
    required String? destination,
  }) async {
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
