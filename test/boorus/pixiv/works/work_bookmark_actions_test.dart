import 'dart:async';

import 'package:boorusama/boorus/pixiv/works/bookmark_actions.dart';
import 'package:boorusama/boorus/pixiv/works/work_mapper.dart';
import 'package:boorusama/core/bookmarks/providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/recent_bookmark_groups_provider.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_library_service.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_target.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_group_picker.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_group_name_dialog.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/groups/group_capability.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:oktoast/oktoast.dart';

import 'work_test_fixtures.dart';

const _groupId = '33333333-3333-4333-8333-333333333333';

void main() {
  for (final narrow in [false, true]) {
    testWidgets('tap saves only the Work, narrow=$narrow', (tester) async {
      final fixture = await _mount(tester, narrow: narrow);
      await tester.tap(find.byTooltip('Bookmark Work'));
      await tester.pumpAndSettle();
      final request =
          tester
                  .widget<BookmarkGroupPicker>(
                    find.byType(BookmarkGroupPicker),
                  )
                  .request
              as ContentGroupBookmarkPickerRequest;
      expect(request.draft.reference.sourceKey, 'work:120');
      expect(request.draft.id, 0);
      expect(request.savedRecordId, isNull);
      expect(request.draft.snapshot.details, isNotNull);
      await _save(tester);
      expect(fixture.library.works.single.reference.sourceKey, 'work:120');
      expect(fixture.library.pages, isEmpty);
    });

    testWidgets(
      'held action captures the Page before later selection, narrow=$narrow',
      (tester) async {
        final fixture = await _mount(tester, narrow: narrow);
        final captured = fixture.data.value.page;
        await tester.longPress(find.byTooltip('Bookmark Work'));
        await tester.pumpAndSettle();
        expect(find.text('Bookmark current Page'), findsOneWidget);
        fixture.data.value = _data(fixture.access, page: 0);
        await tester.pump();
        await tester.tap(find.text('Bookmark current Page'));
        await tester.pumpAndSettle();
        final request =
            tester
                    .widget<BookmarkGroupPicker>(
                      find.byType(BookmarkGroupPicker),
                    )
                    .request
                as PostBookmarkPickerRequest;
        expect(request.post, same(captured));
        await _save(tester);
        expect(fixture.library.pages.single.booruData, request.post.booruData);
        expect(fixture.library.works, isEmpty);
      },
    );

    testWidgets(
      'new Group handoff retains the Work with keyboard, narrow=$narrow',
      (tester) async {
        final fixture = await _mount(tester, narrow: narrow);
        await tester.tap(find.byTooltip('Bookmark Work'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('bookmark-picker-create-group')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(BookmarkGroupNameDialog), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Whole artworks');
        tester.view.viewInsets = const FakeViewPadding(bottom: 180);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 6));
        expect(fixture.library.works.single.reference.sourceKey, 'work:120');
        expect(fixture.library.pages, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Summary-only Work omits an unavailable Page choice', (
    tester,
  ) async {
    final fixture = await _mount(tester);
    fixture.data.value = _data(fixture.access, page: null);
    await tester.pump();
    await tester.longPress(find.byTooltip('Bookmark Work'));
    await tester.pumpAndSettle();
    expect(find.text('Bookmark current Page'), findsNothing);
    expect(find.text('Bookmark Work'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('revoked access rejects an already open frozen request', (
    tester,
  ) async {
    final fixture = await _mount(tester);
    await tester.tap(find.byTooltip('Bookmark Work'));
    await tester.pumpAndSettle();
    fixture.container.read(fixture.current.notifier).state = null;
    await _save(tester);
    expect(fixture.library.works, isEmpty);
    expect(fixture.library.pages, isEmpty);
  });
}

GroupBookmarkPresentationData _data(
  ContentAccessContext access, {
  int? page = 2,
}) {
  final dto = work();
  return GroupBookmarkPresentationData(
    access: access,
    summary: pixivWorkSummary(dto, access),
    details: pixivWorkDetails(dto, access),
    page: page == null ? null : pixivWorkPagePosts(dto, access)[page],
  );
}

Future<void> _save(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const ValueKey(('bookmark-picker-group', _groupId))),
  );
  await tester.pumpAndSettle();
  // Expire toast timers using the controlled clock before test invariants run.
  await tester.pump(const Duration(seconds: 6));
  expect(tester.takeException(), isNull);
}

Future<
  ({
    ProviderContainer container,
    _Library library,
    ContentAccessContext access,
    StateProvider<ContentAccessContext?> current,
    ValueNotifier<GroupBookmarkPresentationData> data,
  })
>
_mount(WidgetTester tester, {bool narrow = false}) async {
  final access = workAccess();
  final current = StateProvider<ContentAccessContext?>((ref) => access);
  final data = ValueNotifier(_data(access));
  final library = _Library();
  final container = ProviderContainer(
    overrides: [
      bookmarkProvider.overrideWith(() => library),
      booruConfigProvider.overrideWith(
        () => BooruConfigNotifier(initialConfigs: [access.config!]),
      ),
      contentAccessContextProvider.overrideWith((ref, key) {
        final value = ref.watch(current);
        return value?.key == key ? value : null;
      }),
      recentBookmarkGroupsProvider.overrideWith((ref) async => []),
    ],
  );
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(narrow ? 320 : 400, 800);
  addTearDown(() async {
    dismissAllToast(showAnim: false);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    container.dispose();
    data.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewInsets();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: BooruLocalization(
        child: MaterialApp(
          theme: ThemeData(extensions: const [KurumiExtendedColorScheme()]),
          builder: (context, child) => KurumiTheme(
            data: KurumiThemeData.fromMaterial(Theme.of(context)),
            child: OKToast(
              child: MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(narrow ? 2 : 1)),
                child: child!,
              ),
            ),
          ),
          home: Scaffold(
            body: Center(
              child: ValueListenableBuilder(
                valueListenable: data,
                builder: (context, value, _) =>
                    PixivWorkBookmarkButton(data: value),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (
    container: container,
    library: library,
    access: access,
    current: current,
    data: data,
  );
}

class _Library extends BookmarkLibraryNotifier {
  final works = <ContentGroupBookmark>[];
  final pages = <Post>[];
  @override
  FutureOr<BookmarkLibraryState> build() => BookmarkLibraryState(
    bookmarks: const [],
    records: const [],
    groups: [BookmarkGroup(id: _groupId, name: 'Destination', bookmarkIds: {})],
  );
  @override
  Future<BookmarkToggleOutcome> toggleContentGroupTarget(
    ContentGroupBookmark draft, {
    required String groupId,
    void Function()? beforeCommit,
    void Function(BookmarkGroupRemovalResult)? onRemoved,
  }) async {
    beforeCommit?.call();
    works.add(draft);
    return BookmarkToggleOutcome.added;
  }

  @override
  Future<BookmarkToggleOutcome> togglePostTarget(
    BooruConfigAuth config,
    Post post, {
    BookmarkTarget target = const BookmarkTarget.defaultGroup(),
    void Function(BookmarkGroupRemovalResult)? onRemoved,
  }) async {
    pages.add(post);
    return BookmarkToggleOutcome.added;
  }

  @override
  Future<void> createGroupWithContentDraft(
    String name,
    ContentGroupBookmark draft, {
    String? parentGroupId,
    void Function()? beforeCommit,
  }) async {
    beforeCommit?.call();
    works.add(draft);
  }
}
