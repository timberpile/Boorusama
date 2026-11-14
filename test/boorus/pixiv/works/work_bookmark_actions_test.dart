import 'package:boorusama/boorus/pixiv/posts/types.dart';
import 'package:boorusama/boorus/pixiv/works/bookmark_actions.dart';
import 'package:boorusama/boorus/pixiv/works/work_presentation.dart';
import 'package:boorusama/core/bookmarks/providers.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/post_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_group_picker.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_group_name_dialog.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/groups/group_capability.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'work_bookmark_widget_fixture.dart';

void main() {
  for (final narrow in [false, true]) {
    for (final choosePage in [false, true]) {
      testWidgets(
        'production choice to durable picker, Page=$choosePage, narrow=$narrow',
        (tester) async {
          final fixture = await mountWorkBookmarks(tester, narrow: narrow);
          final captured = fixture.data.value!.page;
          await tester.longPress(find.byTooltip('Entire Work'));
          await tester.pumpAndSettle();
          // Real route coverage must retain the owner awaiting this dialog.
          expect(find.byType(PixivWorkBookmarkButton), findsOneWidget);
          expect(find.text('Page fallback'), findsNothing);
          expect(find.byType(KurumiDropdownIcon), findsOneWidget);
          fixture.data.value = bookmarkData(fixture.access, page: 0);
          await tester.pump();
          await tester.tap(
            find.text(choosePage ? 'Current Page' : 'Entire Work'),
          );
          await tester.pumpAndSettle();
          final request = tester
              .widget<BookmarkGroupPicker>(
                find.byType(BookmarkGroupPicker),
              )
              .request;
          if (choosePage) {
            expect((request as PostBookmarkPickerRequest).post, same(captured));
          } else {
            final draft = (request as ContentGroupBookmarkPickerRequest).draft;
            expect(draft.id, 0);
            expect(draft.reference.sourceKey, 'work:120');
            expect(draft.snapshot.details, isNotNull);
          }
          await saveBookmark(tester, fixture);
          final records = (await tester.runAsync(fixture.repository.readAll))!;
          expect(records, hasLength(1));
          final groups = (await tester.runAsync(fixture.groups.getGroups))!;
          expect(
            groups
                .singleWhere((g) => g.id == fixture.destinationId)
                .bookmarkIds,
            {records.single.id},
          );
          if (choosePage) {
            expect(records.single, isA<PostBookmark>());
            final post = (records.single as PostBookmark).post;
            expect(post.illustId, 120);
            expect(post.pageIndex, 2);
          } else {
            expect(records.single, isA<ContentGroupBookmark>());
          }
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('direct tap saves only the Work, narrow=$narrow', (
      tester,
    ) async {
      final fixture = await mountWorkBookmarks(tester, narrow: narrow);
      await tester.tap(find.byTooltip('Entire Work'));
      await tester.pumpAndSettle();
      await saveBookmark(tester, fixture);
      final state = fixture.container.read(bookmarkProvider).requireValue;
      expect(state.records.single, isA<ContentGroupBookmark>());
      expect(state.items, isEmpty);
    });

    testWidgets(
      'new Group handoff retains Work with keyboard, narrow=$narrow',
      (
        tester,
      ) async {
        final fixture = await mountWorkBookmarks(tester, narrow: narrow);
        await tester.tap(find.byTooltip('Entire Work'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('bookmark-picker-create-group')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(BookmarkGroupNameDialog), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Whole artworks');
        tester.view.viewInsets = const FakeViewPadding(bottom: 180);
        await tester.pumpAndSettle();
        await commitBookmarkInteraction(
          tester,
          fixture,
          () => tester.tap(find.text('Save')),
        );
        final state = fixture.container.read(bookmarkProvider).requireValue;
        expect(state.records.single, isA<ContentGroupBookmark>());
        expect(state.items, isEmpty);
        expect(
          state.groups
              .singleWhere((g) => g.name == 'Whole artworks')
              .bookmarkIds,
          {state.records.single.id},
        );
      },
    );
  }

  testWidgets('confirmed single Page has only the direct Work action', (
    tester,
  ) async {
    final fixture = await mountWorkBookmarks(tester);
    fixture.data.value = bookmarkData(fixture.access, pageCount: 1, page: 0);
    await tester.pumpAndSettle();
    expect(find.byType(KurumiDropdownIcon), findsNothing);
    expect(
      tester
          .widget<KurumiActionIconButton>(
            find.byType(KurumiActionIconButton),
          )
          .onLongPress,
      isNull,
    );
    await tester.tap(find.byTooltip('Entire Work'));
    await tester.pumpAndSettle();
    await saveBookmark(tester, fixture);
    expect(
      fixture.container.read(bookmarkProvider).requireValue.records.single,
      isA<ContentGroupBookmark>(),
    );
  });

  testWidgets('unknown count is not mistaken for a single Page', (
    tester,
  ) async {
    final fixture = await mountWorkBookmarks(tester);
    fixture.data.value = bookmarkData(fixture.access, pageCount: null);
    await tester.pumpAndSettle();
    expect(find.byType(KurumiDropdownIcon), findsOneWidget);
    await tester.longPress(find.byTooltip('Entire Work'));
    await tester.pumpAndSettle();
    expect(find.text('Current Page'), findsOneWidget);
  });

  testWidgets('summary-only or foreign Page is not an actionable choice', (
    tester,
  ) async {
    final fixture = await mountWorkBookmarks(tester);
    for (final foreign in [false, true]) {
      final data = bookmarkData(fixture.access, page: null);
      fixture.data.value = GroupBookmarkPresentationData(
        access: data.access,
        summary: data.summary,
        details: data.details,
        page: foreign ? bookmarkData(fixture.access, id: 121).page : null,
      );
      await tester.pumpAndSettle();
      await tester.longPress(find.byTooltip('Entire Work'));
      await tester.pumpAndSettle();
      expect(find.text('Current Page'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  for (final workSaved in [false, true]) {
    for (final pageSaved in [false, true]) {
      testWidgets('independent states: Work=$workSaved, Page=$pageSaved', (
        tester,
      ) async {
        final fixture = await mountWorkBookmarks(tester);
        if (workSaved) {
          await tester.tap(find.byTooltip('Entire Work'));
          await tester.pumpAndSettle();
          await saveBookmark(tester, fixture);
        }
        if (pageSaved) {
          await tester.longPress(find.byTooltip('Entire Work'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Current Page'));
          await tester.pumpAndSettle();
          await saveBookmark(tester, fixture);
        }
        final before = _mainIcon(tester);
        expect(before.fill, workSaved ? 1 : 0);
        await tester.longPress(find.byTooltip('Entire Work'));
        await tester.pumpAndSettle();
        expect(_mainIcon(tester).fill, before.fill);
        expect(_mainIcon(tester).color, before.color);
        expect(
          _choiceIcon(tester, 'pixiv-bookmark-work-choice').fill,
          workSaved ? 1 : 0,
        );
        expect(
          _choiceIcon(tester, 'pixiv-bookmark-page-choice').fill,
          pageSaved ? 1 : 0,
        );
        expect(find.byType(KurumiDropdownIcon), findsOneWidget);
        expect(
          fixture.container.read(bookmarkProvider).requireValue.records.length,
          (workSaved ? 1 : 0) + (pageSaved ? 1 : 0),
        );
      });
    }
  }

  for (final nextSaved in [false, true]) {
    testWidgets('inactive neighbor keeps Work identity, saved=$nextSaved', (
      tester,
    ) async {
      final fixture = await mountWorkBookmarks(tester);
      await tester.tap(find.byTooltip('Entire Work'));
      await tester.pumpAndSettle();
      await saveBookmark(tester, fixture);
      if (nextSaved) {
        fixture.data.value = bookmarkData(fixture.access, id: 121);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Entire Work'));
        await tester.pumpAndSettle();
        await saveBookmark(tester, fixture);
      }
      for (final id in [120, 121, 120, 121]) {
        fixture.active.value = false;
        fixture.data.value = bookmarkData(fixture.access, id: id);
        await tester.pump();
        expect(find.text('Page fallback'), findsNothing);
        expect(_mainIcon(tester).fill, id == 120 || nextSaved ? 1 : 0);
        final preview = _mainIcon(tester);
        fixture.active.value = true;
        await tester.pump();
        expect(_mainIcon(tester).fill, preview.fill);
        expect(_mainIcon(tester).color, preview.color);
      }
    });
  }

  for (final invalidate in [
    'dismiss',
    'work',
    'access',
    'profile',
    'unmount',
  ]) {
    testWidgets('choice rejects $invalidate without writing', (tester) async {
      final fixture = await mountWorkBookmarks(tester);
      await tester.longPress(find.byTooltip('Entire Work'));
      await tester.pumpAndSettle();
      switch (invalidate) {
        case 'dismiss':
          await tester.binding.handlePopRoute();
        case 'work':
          fixture.data.value = bookmarkData(fixture.access, id: 121);
        case 'access':
          fixture.container.read(fixture.current.notifier).state = null;
        case 'profile':
          fixture.container.read(booruConfigProvider.notifier).state = [];
        case 'unmount':
          fixture.data.value = null;
      }
      await tester.pumpAndSettle();
      if (invalidate != 'dismiss') {
        await tester.tap(find.text('Current Page'));
        await tester.pumpAndSettle();
      }
      expect(find.byType(BookmarkGroupPicker), findsNothing);
      expect((await tester.runAsync(fixture.repository.readAll)), isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('dismissed destination picker does not write', (tester) async {
    final fixture = await mountWorkBookmarks(tester);
    await tester.longPress(find.byTooltip('Entire Work'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Current Page'));
    await tester.pumpAndSettle();
    expect(find.byType(BookmarkGroupPicker), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect((await tester.runAsync(fixture.repository.readAll)), isEmpty);
  });

  testWidgets('overflow has no duplicate Work or Page bookmark actions', (
    tester,
  ) async {
    final fixture = await mountWorkBookmarks(tester);
    final context = tester.element(find.byType(PixivWorkBookmarkButton));
    expect(
      const PixivWorkPresentation().buildBookmarkMenuButtons(
        context,
        fixture.data.value!,
      ),
      isEmpty,
    );
  });
}

Icon _mainIcon(WidgetTester tester) => tester.widget<Icon>(
  find.descendant(
    of: find.byKey(const ValueKey('pixiv-work-bookmark-trigger')),
    matching: find.byIcon(Symbols.bookmark),
  ),
);

Icon _choiceIcon(WidgetTester tester, String key) => tester.widget<Icon>(
  find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byIcon(Symbols.bookmark),
  ),
);
