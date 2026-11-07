import 'dart:async';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/providers/pool_bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/providers/related_bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/providers/recent_bookmark_groups_provider.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_library_service.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark_capability.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_group_picker.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_group_name_dialog.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/related/related_family.dart';
import 'package:boorusama/core/posts/related/related_posts_order_value.dart';
import 'package:flutter/material.dart' as legacy;
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:oktoast/oktoast.dart';

import 'pool_bookmark_test_utils.dart';

final _config = BooruConfig.defaultConfig(
  booruType: BooruType.danbooru,
  url: 'https://danbooru.donmai.us',
  customDownloadFileNameFormat: null,
);
final _family = RelatedFamilyReference.fromPost(testRelatedPost(10));
final _related = RelatedCollectionBookmark(
  family: _family,
  localId: poolGroupB,
  createdAt: DateTime.utc(2026),
  observedAt: DateTime.utc(2026),
  groupIds: {},
);

BookmarkPickerRequest _request(String kind) => kind == 'Related'
    ? RelatedBookmarkPickerRequest(config: _config, family: _family)
    : RemotePoolBookmarkPickerRequest(
        config: _config,
        pool: RemoteBookmarkPool(
          id: 10,
          title: kind,
          category: kind == 'Series'
              ? BookmarkedPoolCategory.series
              : BookmarkedPoolCategory.collection,
          total: 20,
        ),
      );
CollectionBookmark _draft(String kind) => kind == 'Related'
    ? _related
    : testPool(
        groups: {},
        category: kind == 'Series'
            ? BookmarkedPoolCategory.series
            : BookmarkedPoolCategory.collection,
      );

void main() {
  test('equivalent remote metadata preserves the active request identity', () {
    expect(_request('Series'), _request('Series'));
    expect(_request('Collection'), isNot(_request('Series')));
  });
  for (final dialog in [false, true]) {
    for (final kind in ['Series', 'Collection', 'Related']) {
      for (final exit in ['save', 'cancel', 'source change']) {
        testWidgets(
          '$kind creation transfers deferred ownership (dialog=$dialog, $exit)',
          (tester) async {
            final fixture = await _mount(
              tester,
              request: _request(kind),
              dialog: dialog,
            );
            await tester.tap(find.text('Open'));
            await tester.pumpAndSettle();
            expect(find.byType(BookmarkGroupPicker), findsOneWidget);
            expect(find.byType(legacy.AlertDialog), findsNothing);
            expect(find.byType(legacy.Dialog), findsNothing);
            expect(fixture.gate.isCompleted, isFalse);
            await tester.tap(
              find.byKey(const ValueKey('bookmark-picker-create-group')),
            );
            await tester.pumpAndSettle();
            // The original anchor/content has gone; the new route owns the draft.
            expect(find.byType(BookmarkGroupPicker), findsNothing);
            expect(find.byType(BookmarkGroupNameDialog), findsOneWidget);
            await tester.enterText(
              find.byType(TextField),
              'Created destination',
            );
            await tester.tap(find.text('Save'));
            await tester.pump();
            await tester.tap(find.text('Save'));
            expect(fixture.library.creations, isEmpty);
            if (exit == 'cancel') {
              await tester.tap(find.text('Cancel'));
            } else if (exit == 'source change') {
              fixture.profiles.replace([
                _config.copyWith(name: 'Changed source'),
              ]);
            }
            fixture.gate.complete(_draft(kind));
            await tester.pumpAndSettle();
            expect(fixture.library.creations.length, exit == 'save' ? 1 : 0);
            if (exit == 'save') {
              final created = fixture.library.creations.single;
              expect(created.posts, isEmpty);
              expect(created.pools.single.identity, _draft(kind).identity);
              expect(find.byType(BookmarkGroupNameDialog), findsNothing);
              expect(find.text('Open'), findsOneWidget);
            } else if (exit == 'source change') {
              expect(find.byType(BookmarkGroupNameDialog), findsOneWidget);
              await tester.tap(find.text('Cancel'));
            }
            await _finish(tester);
          },
        );
      }
      testWidgets(
        '$kind cancels pending writes before reverse animation (dialog=$dialog)',
        (tester) async {
          final fixture = await _mount(
            tester,
            request: _request(kind),
            dialog: dialog,
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Destination'));
          await tester.pump();
          await tester.tap(find.text('Destination'));
          await tester.tap(
            find.byKey(const ValueKey('bookmark-picker-create-group')),
          );
          await tester.pump();
          expect(find.byType(BookmarkGroupNameDialog), findsNothing);
          // Do not wait for disposal: resolve while the closing widget is mounted.
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          fixture.gate.complete(_draft(kind));
          await tester.pumpAndSettle();
          expect(fixture.library.toggles, isEmpty);
          expect(fixture.library.creations, isEmpty);
          expect(find.byType(BookmarkGroupPicker), findsNothing);
          await _finish(tester);
        },
      );
    }
  }
  for (final dialog in [false, true]) {
    testWidgets(
      'Post creation retains its exact source through handoff (dialog=$dialog)',
      (tester) async {
        final fixture = await _mount(
          tester,
          request: PostBookmarkPickerRequest(
            config: _config.auth,
            post: testRelatedPost(10),
          ),
          dialog: dialog,
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('bookmark-picker-create-group')),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Post destination');
        fixture.profiles.replace([_config.copyWith(name: 'Changed source')]);
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(fixture.library.creations, isEmpty);
        await tester.tap(find.text('Cancel'));
        await _finish(tester);
      },
    );
    for (final kind in ['Series', 'Collection', 'Related']) {
      testWidgets(
        'stored $kind opens without resolving metadata (dialog=$dialog)',
        (tester) async {
          final draft = _draft(kind);
          final fixture = await _mount(
            tester,
            request: StoredBookmarkPickerRequest(
              config: _config.auth,
              collection: draft,
              source: _config,
            ),
            dialog: dialog,
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(fixture.gate.isCompleted, isFalse);
          await tester.tap(find.text('Destination'));
          await tester.pumpAndSettle();
          expect(fixture.library.toggles.single.identity, draft.identity);
          expect(fixture.library.creations, isEmpty);
          expect(find.byType(BookmarkGroupPicker), findsNothing);
          await _finish(tester);
        },
      );
    }
  }
  for (final direction in TextDirection.values) {
    testWidgets(
      'pointer popup fits available space and restores focus in $direction',
      (tester) async {
        tester.view.physicalSize = const Size(320, 520);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final focus = FocusNode();
        addTearDown(focus.dispose);
        await _mount(
          tester,
          request: PostBookmarkPickerRequest(
            config: _config.auth,
            post: testRelatedPost(10),
          ),
          dialog: false,
          focus: focus,
          direction: direction,
        );
        focus.requestFocus();
        await tester.pump();
        await tester.tap(find.text('Open'), kind: PointerDeviceKind.mouse);
        await tester.pumpAndSettle();
        final rect = tester.getRect(find.byType(BookmarkGroupPicker));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(520));
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(focus.hasFocus, isTrue);
        await _finish(tester);
      },
    );
  }
}

Future<
  ({Completer<CollectionBookmark> gate, _Library library, _Profiles profiles})
>
_mount(
  WidgetTester tester, {
  required BookmarkPickerRequest request,
  required bool dialog,
  FocusNode? focus,
  TextDirection direction = TextDirection.ltr,
}) async {
  final gate = Completer<CollectionBookmark>();
  final library = _Library();
  final profiles = _Profiles();
  final container = ProviderContainer(
    overrides: [
      bookmarkProvider.overrideWith(() => library),
      booruConfigProvider.overrideWith(() => profiles),
      recentBookmarkGroupsProvider.overrideWith((ref) async => []),
      poolBookmarkDraftProvider.overrideWith((ref, request) => gate.future),
      relatedBookmarkDraftProvider.overrideWith((ref, request) => gate.future),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
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
              child: Directionality(textDirection: direction, child: child!),
            ),
          ),
          home: Scaffold(
            body: Align(
              alignment: AlignmentDirectional.bottomStart,
              child: Builder(
                builder: (context) => dialog
                    ? TextButton(
                        focusNode: focus,
                        onPressed: () =>
                            showBookmarkPickerDialog(context, request: request),
                        child: const Text('Open'),
                      )
                    : BookmarkGroupPickerAnchor(
                        request: request,
                        builder: (context, show) => TextButton(
                          focusNode: focus,
                          onPressed: show,
                          child: const Text('Open'),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (gate: gate, library: library, profiles: profiles);
}

Future<void> _finish(WidgetTester tester) async {
  dismissAllToast(showAnim: false);
  await tester.pump(const Duration(seconds: 6));
  expect(tester.takeException(), isNull);
}

class _Profiles extends BooruConfigNotifier {
  _Profiles() : super(initialConfigs: [_config]);
  void replace(List<BooruConfig> value) => state = value;
}

class _Library extends BookmarkLibraryNotifier {
  final creations = <({List<Post> posts, List<CollectionBookmark> pools})>[];
  final toggles = <CollectionBookmark>[];
  @override
  FutureOr<BookmarkLibraryState> build() => BookmarkLibraryState(
    bookmarks: [],
    groups: [
      BookmarkGroup(id: poolGroupA, name: 'Destination', bookmarkIds: {}),
    ],
  );
  @override
  Future<BookmarkToggleOutcome> togglePoolTarget(
    CollectionBookmark draft, {
    required String groupId,
    RelatedPostsOrder? initialRelatedOrder,
    void Function(BookmarkGroupRemovalResult)? onRemoved,
  }) async {
    toggles.add(draft);
    return BookmarkToggleOutcome.added;
  }

  @override
  Future<({BookmarkGroup group, int addedCount})> createGroupWithPosts(
    String name,
    BooruConfigAuth config,
    Iterable<Post> posts, {
    String? folderId,
    List<CollectionBookmark> pools = const [],
    RelatedPostsOrder? initialRelatedOrder,
  }) async {
    creations.add((posts: posts.toList(), pools: pools));
    return (
      group: BookmarkGroup(id: poolGroupB, name: name, bookmarkIds: {}),
      addedCount: posts.length + pools.length,
    );
  }
}
