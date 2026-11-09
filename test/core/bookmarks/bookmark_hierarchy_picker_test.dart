import 'dart:async';

import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/providers/recent_bookmark_groups_provider.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_library_service.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_group_picker.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/navigation/app_navigation.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/related/related_posts_order_value.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart' show ModalRoute, PredictiveBackRoute;
import 'package:go_router/go_router.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:oktoast/oktoast.dart';

import 'pool_bookmark_test_utils.dart';

const _rootId = '11111111-1111-4111-8111-111111111111';
const _childId = '22222222-2222-4222-8222-222222222222';
const _leafId = '33333333-3333-4333-8333-333333333333';

final _config = BooruConfig.defaultConfig(
  booruType: BooruType.danbooru,
  url: 'https://danbooru.donmai.us',
  customDownloadFileNameFormat: null,
);

final _root = BookmarkGroup(
  id: _rootId,
  name: 'Root group',
  bookmarkIds: {},
);
final _child = BookmarkGroup(
  id: _childId,
  name: 'Child group',
  parentGroupId: _rootId,
  bookmarkIds: {},
);
final _leaf = BookmarkGroup(
  id: _leafId,
  name: 'Leaf group',
  parentGroupId: _childId,
  bookmarkIds: {},
);
final _pool = testPool(id: 321, groups: {});

void main() {
  for (final direction in TextDirection.values) {
    testWidgets(
      'nested picker separates navigation from direct selection in $direction',
      (tester) async {
        final fixture = await _mount(
          tester,
          direction: direction,
          size: const Size(320, 700),
          textScale: 2,
          recentGroups: [_root],
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final pickerRect = tester.getRect(find.byType(BookmarkGroupPicker));
        expect(pickerRect.width, lessThanOrEqualTo(420));
        expect(pickerRect.left, greaterThanOrEqualTo(0));
        expect(pickerRect.right, lessThanOrEqualTo(320));

        await _tapTrailing(tester, _rootId, direction);
        expect(_path(tester), 'Root group');
        await _tapTrailing(tester, _childId, direction);
        expect(_path(tester), 'Root group / Child group');
        expect(find.byKey(_groupRowKey(_leafId)), findsOneWidget);
        expect(fixture.library.toggledGroupIds, isEmpty);
        expect(fixture.library.creations, 0);

        // The body region remains the direct-selection action. The trailing
        // 20% region above is the only part that navigates into a child.
        await _tapBody(tester, _leafId, direction);
        await tester.pumpAndSettle();
        expect(fixture.library.toggledGroupIds, [_leafId]);
        expect(fixture.library.creations, 0);
        expect(find.byType(BookmarkGroupPicker), findsNothing);
        expect(tester.takeException(), isNull);
        await _finish(tester);
      },
    );
  }

  for (final dialog in [false, true]) {
    for (final back in ['system', 'escape', 'visible']) {
      testWidgets(
        '${dialog ? 'dialog' : 'anchor'} $back Back returns one nested level',
        (tester) async {
          final fixture = await _mount(tester, dialog: dialog);
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          await _tapTrailing(tester, _rootId, TextDirection.ltr);
          await _tapTrailing(tester, _childId, TextDirection.ltr);
          expect(_path(tester), 'Root group / Child group');

          switch (back) {
            case 'system':
              await tester.binding.handlePopRoute();
              break;
            case 'escape':
              await tester.sendKeyEvent(LogicalKeyboardKey.escape);
              break;
            case 'visible':
              await tester.tap(
                find.byKey(const ValueKey('bookmark-picker-back')),
              );
              break;
          }
          await tester.pumpAndSettle();

          expect(_path(tester), 'Root group');
          expect(find.byType(BookmarkGroupPicker), findsOneWidget);
          expect(fixture.library.toggledGroupIds, isEmpty);
          expect(fixture.library.creations, 0);
          expect(tester.takeException(), isNull);
          await _finish(tester);
        },
      );
    }
  }

  for (final dialog in [false, true]) {
    testWidgets(
      '${dialog ? 'dialog' : 'anchor'} Back at the root returns to the caller',
      (tester) async {
        final fixture = await _mount(tester, dialog: dialog);
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await _tapTrailing(tester, _rootId, TextDirection.ltr);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(_path(tester), 'Home');
        expect(find.byType(BookmarkGroupPicker), findsOneWidget);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(BookmarkGroupPicker), findsNothing);
        expect(fixture.library.toggledGroupIds, isEmpty);
        expect(fixture.library.creations, 0);
        expect(tester.takeException(), isNull);
        await _finish(tester);
      },
    );

    testWidgets(
      '${dialog ? 'dialog' : 'anchor'} cancelled predictive Back preserves navigation',
      (tester) async {
        final fixture = await _mount(tester, dialog: dialog);
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await _tapTrailing(tester, _rootId, TextDirection.ltr);
        await _tapTrailing(tester, _childId, TextDirection.ltr);
        expect(_path(tester), 'Root group / Child group');

        final route = ModalRoute.of(
          tester.element(find.byType(BookmarkGroupPicker)),
        )!;
        expect(route, isA<PredictiveBackRoute>());
        final gesture = route as PredictiveBackRoute;
        gesture.handleStartBackGesture(progress: 0);
        gesture.handleUpdateBackGestureProgress(progress: 0.4);
        gesture.handleCancelBackGesture();
        await tester.pumpAndSettle();

        expect(_path(tester), 'Root group / Child group');
        expect(find.byType(BookmarkGroupPicker), findsOneWidget);
        expect(fixture.library.toggledGroupIds, isEmpty);
        expect(fixture.library.creations, 0);
        expect(tester.takeException(), isNull);
        await _finish(tester);
      },
    );
  }
}

ValueKey<(String, String)> _groupRowKey(String id) =>
    ValueKey(('bookmark-picker-group', id));

String _path(WidgetTester tester) {
  final path = find.byKey(const ValueKey('bookmark-picker-path'));
  return path.evaluate().isEmpty ? 'Home' : tester.widget<Text>(path).data!;
}

Future<void> _tapTrailing(
  WidgetTester tester,
  String groupId,
  TextDirection direction,
) async {
  final rect = tester.getRect(find.byKey(_groupRowKey(groupId)));
  final x = direction == TextDirection.ltr ? rect.right - 40 : rect.left + 40;
  await tester.tapAt(Offset(x, rect.center.dy));
  await tester.pumpAndSettle();
}

Future<void> _tapBody(
  WidgetTester tester,
  String groupId,
  TextDirection direction,
) async {
  final rect = tester.getRect(find.byKey(_groupRowKey(groupId)));
  final x = direction == TextDirection.ltr ? rect.left + 40 : rect.right - 40;
  await tester.tapAt(Offset(x, rect.center.dy));
}

Future<_Fixture> _mount(
  WidgetTester tester, {
  bool dialog = false,
  TextDirection direction = TextDirection.ltr,
  Size size = const Size(400, 900),
  double textScale = 1,
  List<BookmarkGroup> recentGroups = const [],
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final library = _Library();
  final appNavigation = AppNavigation();
  late final GoRouter router;
  router = GoRouter(
    navigatorKey: appNavigation.navigatorKey,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Center(
            child: dialog
                ? TextButton(
                    onPressed: () => showBookmarkPickerDialog(
                      context,
                      request: _request,
                    ),
                    child: const Text('Open'),
                  )
                : BookmarkGroupPickerAnchor(
                    request: _request,
                    builder: (context, show) => TextButton(
                      onPressed: show,
                      child: const Text('Open'),
                    ),
                  ),
          ),
        ),
      ),
    ],
  );
  final container = ProviderContainer(
    overrides: [
      bookmarkProvider.overrideWith(() => library),
      recentBookmarkGroupsProvider.overrideWith((ref) async => recentGroups),
      booruConfigProvider.overrideWith(
        () => BooruConfigNotifier(initialConfigs: [_config]),
      ),
      appNavigationProvider.overrideWithValue(appNavigation),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    router.dispose();
  });

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: BooruLocalization(
        child: MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(extensions: const [KurumiExtendedColorScheme()]),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: KurumiTheme(
              data: KurumiThemeData.fromMaterial(Theme.of(context)),
              child: OKToast(
                duration: Duration.zero,
                child: Directionality(
                  textDirection: direction,
                  child: child!,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Fixture(library);
}

Future<void> _finish(WidgetTester tester) async {
  dismissAllToast(showAnim: false);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

final _request = StoredBookmarkPickerRequest(
  config: _config.auth,
  source: _config,
  collection: _pool,
);

final class _Fixture {
  const _Fixture(this.library);
  final _Library library;
}

final class _Library extends BookmarkLibraryNotifier {
  final toggledGroupIds = <String>[];
  var creations = 0;

  @override
  FutureOr<BookmarkLibraryState> build() => BookmarkLibraryState(
    bookmarks: [],
    records: const [],
    groups: [_root, _child, _leaf],
  );

  @override
  Future<BookmarkToggleOutcome> togglePoolTarget(
    CollectionBookmark draft, {
    required String groupId,
    RelatedPostsOrder? initialRelatedOrder,
    void Function(BookmarkGroupRemovalResult)? onRemoved,
  }) async {
    toggledGroupIds.add(groupId);
    return BookmarkToggleOutcome.removed;
  }

  @override
  Future<({BookmarkGroup group, int addedCount})> createGroupWithPosts(
    String name,
    BooruConfigAuth config,
    Iterable<Post> posts, {
    String? folderId,
    String? parentGroupId,
    List<CollectionBookmark> pools = const [],
    RelatedPostsOrder? initialRelatedOrder,
  }) async {
    creations++;
    return (group: _root, addedCount: 0);
  }
}
