import 'package:boorusama/boorus/pixiv/works/bookmark_actions.dart';
import 'package:boorusama/core/bookmarks/providers.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_group_picker.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_group_name_dialog.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/groups/group_capability.dart';
import 'package:boorusama/core/content/groups/group_source_provider.dart';
import 'package:boorusama/core/posts/pools/pool_grid_item.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/content/widgets/native_content_grid.dart';
import 'package:boorusama/core/configs/manage/widgets.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/navigation/destination_activity.dart';
import 'package:boorusama/core/posts/details/src/routes/details_route_context.dart';
import 'package:boorusama/core/posts/details/src/types/viewer_entry.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';
import 'package:i18n/i18n.dart';
import 'package:oktoast/oktoast.dart';

import '../../../application/support/fake_image_dio.dart';
import 'work_bookmark_widget_fixture.dart';

Widget timeline(
  WorkBookmarkWidgetFixture fixture, {
  ValueNotifier<int>? generation,
}) => Scaffold(
  body: DestinationPageActivity(
    child: ListenableBuilder(
      listenable: Listenable.merge([
        fixture.active,
        if (generation != null) generation,
      ]),
      builder: (context, _) => NavigationActivity(
        active: fixture.active.value && NavigationActivity.of(context),
        child: CurrentBooruConfigScope(
          config: fixture.access.config!,
          accessKey: fixture.access.key,
          requireAccess: true,
          child: NativeContentGrid(
            access: fixture.access,
            queryIdentity: generation?.value,
            fetchPage: (_) async => NativeContentPage(
              entries: [
                GroupContentEntry(
                  summary: bookmarkData(fixture.access, id: 120).summary,
                ),
                GroupContentEntry(
                  summary: bookmarkData(fixture.access, id: 220).summary,
                ),
              ],
              hasMore: false,
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  for (final narrow in [false, true]) {
    for (final selected in [1, 2]) {
      testWidgets(
        'timeline standard selection bookmarks $selected actual Works, narrow=$narrow',
        (tester) async {
          final router = _RecordingRouter();
          addTearDown(router.dispose);
          final fixture = await mountWorkBookmarks(
            tester,
            narrow: narrow,
            overrides: [
              automaticMediaLoadingEnabledProvider.overrideWithValue(false),
              deterministicImageDioOverride(),
              deterministicFaviconDioOverride(),
              routerProvider.overrideWithValue(router),
            ],
            homeBuilder: timeline,
          );
          expect(find.byType(PixivWorkBookmarkContextMenu), findsNothing);
          await tester.longPress(find.text('Work 120'));
          await tester.pumpAndSettle();
          expect(find.text('1 item selected'), findsOneWidget);
          expect(find.text('Entire Work'), findsNothing);
          if (selected == 2) {
            await tester.tap(find.text('Work 220'));
            await tester.pumpAndSettle();
            expect(find.text('2 items selected'), findsOneWidget);
          }
          expect(
            router.opened,
            isEmpty,
            reason: 'Selection taps never open a neighboring Work',
          );
          await tester.tap(find.text('Bookmark'));
          await tester.pumpAndSettle();
          if (selected == 1) {
            final request =
                tester
                        .widget<BookmarkGroupPicker>(
                          find.byType(BookmarkGroupPicker),
                        )
                        .request
                    as ContentGroupBookmarkPickerRequest;
            expect(request.draft.reference.sourceKey, 'work:120');
          } else {
            expect(find.text('Add Bookmarks to Group'), findsOneWidget);
          }
          await saveBookmark(tester, fixture);
          final state = fixture.container.read(bookmarkProvider).requireValue;
          expect(
            state.items,
            isEmpty,
            reason: 'Whole Works never become saved member Pages',
          );
          expect(state.records, hasLength(selected));
          expect(state.records, everyElement(isA<ContentGroupBookmark>()));
          expect(
            state.records
                .cast<ContentGroupBookmark>()
                .map((record) => record.reference.sourceKey)
                .toSet(),
            selected == 1 ? {'work:120'} : {'work:120', 'work:220'},
          );
          expect(
            state.groupsById[fixture.destinationId]!.bookmarkIds,
            state.records.map((record) => record.id).toSet(),
          );
          await tester.tap(find.byTooltip('Close'));
          await tester.pumpAndSettle();
          expect(find.byType(PixivSelectedWorksBookmarkButton), findsNothing);
          await tester.tap(find.text('Work 220'));
          await tester.pumpAndSettle();
          final opened = router.opened.single;
          expect(opened.initialIndex, 1);
          expect(
            (opened.entries![opened.initialIndex] as GroupViewerEntry)
                .summary
                .reference
                .sourceKey,
            'work:220',
          );
          expect(opened.config?.id, fixture.access.config!.id);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'refresh clears occurrence selection and revoked profile cannot save a bulk picker',
    (tester) async {
      final generation = ValueNotifier(0);
      addTearDown(generation.dispose);
      final router = _RecordingRouter();
      final fixture = await mountWorkBookmarks(
        tester,
        overrides: [
          automaticMediaLoadingEnabledProvider.overrideWithValue(false),
          deterministicImageDioOverride(),
          deterministicFaviconDioOverride(),
          routerProvider.overrideWithValue(router),
        ],
        homeBuilder: (fixture) => timeline(fixture, generation: generation),
      );
      await tester.longPress(find.text('Work 120'));
      await tester.pumpAndSettle();
      final staleTap = tester
          .widgetList<PoolGridItem>(find.byType(PoolGridItem))
          .first
          .onTap;
      generation.value++;
      await tester.pumpAndSettle();
      expect(find.byType(PixivSelectedWorksBookmarkButton), findsNothing);
      staleTap();
      await tester.pumpAndSettle();
      expect(
        router.opened,
        isEmpty,
        reason:
            'A refreshed occurrence cannot inherit an earlier card callback',
      );
      await tester.longPress(find.text('Work 120'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Work 220'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bookmark'));
      await tester.pumpAndSettle();
      fixture.container.read(fixture.current.notifier).state = null;
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey(('bookmark-picker-group', fixture.destinationId))),
      );
      await tester.pumpAndSettle();
      expect((await tester.runAsync(fixture.repository.readAll))!, isEmpty);
      expect(
        (await tester.runAsync(fixture.groups.getGroups))!,
        hasLength(2),
        reason: 'Only No Group and the existing destination remain',
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final revoke in [false, true]) {
    testWidgets(
      'multi-Work creation uses the normal Group picker atomically (revoke=$revoke)',
      (tester) async {
        final fixture = await mountWorkBookmarks(
          tester,
          narrow: true,
          overrides: [
            automaticMediaLoadingEnabledProvider.overrideWithValue(false),
            deterministicFaviconDioOverride(),
          ],
          homeBuilder: timeline,
        );
        await tester.longPress(find.text('Work 120'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Work 220'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bookmark'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('bookmark-picker-create-group')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(BookmarkGroupNameDialog), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Selected Works');
        tester.view.viewInsets = const FakeViewPadding(bottom: 180);
        await tester.pumpAndSettle();
        if (revoke) {
          fixture.container.read(fixture.current.notifier).state = null;
          await tester.pumpAndSettle();
          await tester.tap(find.text('Save'));
          await tester.pumpAndSettle();
          expect(
            await workBookmarkIO(tester, fixture.repository.readAll),
            isEmpty,
          );
          expect(
            (await workBookmarkIO(
              tester,
              fixture.groups.getGroups,
            )).where((group) => group.name == 'Selected Works'),
            isEmpty,
          );
          expect(
            find.text(Translations().bookmark.groups.operation_failed),
            findsOneWidget,
          );
          dismissAllToast();
          // oktoast retains its delayed animation future after dismissal.
          // Advance the controlled error-toast clock before test invariants.
          await tester.pump(const Duration(seconds: 4));
          await tester.pumpAndSettle();
        } else {
          await commitBookmarkInteraction(
            tester,
            fixture,
            () => tester.tap(find.text('Save')),
          );
          final state = fixture.container.read(bookmarkProvider).requireValue;
          expect(
            state.records
                .cast<ContentGroupBookmark>()
                .map((record) => record.reference.sourceKey)
                .toSet(),
            {'work:120', 'work:220'},
          );
          expect(state.items, isEmpty);
          expect(
            state.groups
                .singleWhere((group) => group.name == 'Selected Works')
                .bookmarkIds,
            state.records.map((record) => record.id).toSet(),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'a native engine presentation without selection never inherits Pixiv Bookmark actions',
    (tester) async {
      await mountWorkBookmarks(
        tester,
        overrides: [
          automaticMediaLoadingEnabledProvider.overrideWithValue(false),
          booruGroupCapabilityProvider.overrideWith(
            (ref, engine) => BooruGroupCapability(
              engine: BooruType.pixiv,
              keyCodec: const BooruContentKeyCodec(BooruType.pixiv),
              createSource: (_, _) =>
                  throw StateError('Timeline must not load member Pages'),
              presentation: _NoSelectionPresentation(),
            ),
          ),
        ],
        homeBuilder: timeline,
      );
      await tester.longPress(find.text('Work 120'));
      await tester.pumpAndSettle();
      expect(find.byType(PixivSelectedWorksBookmarkButton), findsNothing);
      expect(find.text('Entire Work'), findsNothing);
      expect(find.text('1 item selected'), findsNothing);
    },
  );

  testWidgets(
    'normal desktop selection supports modifier taps and Select All',
    (tester) async {
      final fixture = await mountWorkBookmarks(
        tester,
        overrides: [
          automaticMediaLoadingEnabledProvider.overrideWithValue(false),
          deterministicImageDioOverride(),
          deterministicFaviconDioOverride(),
        ],
        homeBuilder: timeline,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.text('Work 120'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text('1 item selected'), findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text('2 items selected'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      fixture.active.value = false;
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Work 120'));
      await tester.pumpAndSettle();
      expect(find.byType(PixivSelectedWorksBookmarkButton), findsNothing);
      expect(
        fixture.container.read(bookmarkProvider).requireValue.records,
        isEmpty,
      );
    },
  );
}

class _RecordingRouter implements GoRouter {
  @override
  void dispose() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  final opened = <DetailsRouteContext<Post>>[];
  @override
  Future<T?> push<T extends Object?>(String location, {Object? extra}) async {
    opened.add(extra! as DetailsRouteContext<Post>);
    return null;
  }
}

class _NoSelectionPresentation implements BooruGroupPresentation {
  @override
  bool supports(ContentGroupSummary summary) => true;
  @override
  GroupLayout layoutFor(ContentGroupSummary summary) => GroupLayout.mediaPager;
  @override
  String memberLabel(BuildContext context, ContentGroupSummary summary) =>
      'Pages';
  @override
  Widget buildCard(BuildContext context, ContentGroupSummary summary) =>
      const SizedBox();
  @override
  Widget buildDetails(BuildContext context, ContentGroupDetails details) =>
      const SizedBox();
}
