import 'dart:async';

import 'package:booru_clients/nhentai.dart';
import 'package:boorusama/boorus/nhentai/galleries/mapper.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_group_picker.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/content_media_access.dart';
import 'package:boorusama/core/content/groups/group_members_provider.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/posts/details/src/types/viewer_entry.dart';
import 'package:boorusama/core/posts/details/src/widgets/group_viewer_scope.dart';
import 'package:boorusama/core/posts/details/src/widgets/media_group_viewer.dart';
import 'package:boorusama/core/posts/details/src/widgets/native_metadata_selection.dart';
import 'package:boorusama/core/posts/details/src/widgets/post_viewer_transformation_scope.dart';
import 'package:boorusama/core/posts/media_preload/providers.dart';
import 'package:boorusama/core/posts/media_preload/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import '../../../boorus/nhentai/fixtures.dart';
import '../../search/following_topics/following_topic_test_utils.dart';

class _Bookmarks extends BookmarkLibraryNotifier {
  @override
  BookmarkLibraryState build() =>
      BookmarkLibraryState(bookmarks: const [], groups: const []);
}

class _Members extends GroupMembersController {
  _Members(this.value, this.next);
  final Future<void> Function(_Members)? next;
  final GroupMembersState Function() value;
  @override
  Future<GroupMembersState> build(GroupLoadKey key) async => value();
  @override
  Future<void> loadNext() async => next?.call(this);
  void pending() => state = const AsyncLoading();
  void publish(GroupMembersState next) => state = AsyncData(next);
}

class _Fixture {
  _Fixture({
    String occurrence = 'first',
    String? initialMemberKey,
    int pageCount = 3,
  }) {
    details = ContentGroupDetails(
      summary: ContentGroupSummary(
        reference: nhentaiGalleryReference(access, 101),
        title: 'Fixture Gallery',
        memberCount: pageCount,
      ),
      description: const GroupDescription(
        text: '<b>Selectable description</b>',
        format: GroupTextFormat.html,
      ),
    );
    final json = galleryJson();
    if (pageCount != 3) {
      json['num_pages'] = pageCount;
      json['pages'] = [
        for (var page = 1; page <= pageCount; page++)
          {
            'number': page,
            'width': 100,
            'height': 200,
            if (page != 2) 'path': 'galleries/7001/$page.webp',
          },
      ];
    }
    final dto = NhentaiGalleryDetails.fromJson(json);
    final posts = nhentaiGalleryPosts(dto, access, galleryPolicy());
    members = GroupMembersState(
      members: [
        for (var page = 1; page <= pageCount; page++)
          GroupMember(
            reference: nhentaiPageReference(access, 101, page),
            memberKey: 'page-$page',
            sourcePosition: page - 1,
            availability: page == 2
                ? MemberAvailability.unavailable
                : MemberAvailability.available,
          ),
      ],
      resolved: {
        for (final post in posts)
          const ContentReferenceCodec()
              .fromPost(post, site: Uri.parse(access.config!.url))!
              .identity: PostContentEntry(
            reference: const ContentReferenceCodec().fromPost(
              post,
              site: Uri.parse(access.config!.url),
            )!,
            post: post,
          ),
      },
      generation: 1,
      sourceTotal: pageCount,
      firstPageLoaded: true,
    );
    harness = FollowingTopicHarness(
      profiles: [access.config!],
      overrides: [
        zoomStudyEnabledProvider.overrideWithValue(false),
        currentContentAccessKeyProvider.overrideWithValue(access.key),
        contentAccessContextProvider.overrideWith(
          (ref, key) => key == access.key ? access : null,
        ),
        bookmarkProvider.overrideWith(_Bookmarks.new),
        groupMembersProvider.overrideWith(
          () => _Members(
            () => initialBatch ?? members,
            (controller) => onNext?.call(controller) ?? Future.value(),
          ),
        ),
        contentOccurrencePreloadManagerProvider.overrideWith((ref, request) {
          final manager = PreloadManager(
            preloader: (_, _) async {},
            isEnabled: () => false,
          );
          ref.onDispose(manager.dispose);
          return manager;
        }),
      ],
    );
    entry = GroupViewerEntry(
      summary: details.summary,
      occurrenceId: occurrence,
      source: ViewerSourceBinding(access.config!),
      initialMemberKey: initialMemberKey,
    );
  }
  final access = galleryAccess();
  final bucket = PageStorageBucket();
  GroupMembersState? initialBatch;
  Future<void> Function(_Members)? onNext;
  GroupMembersState firstBatch(int count) {
    final first = members.members.take(count).toList();
    final identities = first.map((member) => member.reference.identity).toSet();
    return GroupMembersState(
      members: first,
      resolved: {
        for (final entry in members.resolved.entries)
          if (identities.contains(entry.key)) entry.key: entry.value,
      },
      next: count < members.members.length
          ? ContentCursor('fixture-next')
          : null,
      generation: members.generation,
      sourceTotal: members.sourceTotal,
      firstPageLoaded: true,
    );
  }

  late final ContentGroupDetails details;
  late final GroupMembersState members;
  late final FollowingTopicHarness harness;
  late final GroupViewerEntry entry;
  GroupLoadKey get key =>
      GroupLoadKey(reference: details.summary.reference, access: access.key);
  Future<void> mount(WidgetTester tester, {PageController? outer}) =>
      harness.pump(
        tester,
        Scaffold(
          body: NativeMetadataSelectionScope(
            child: PageStorage(
              bucket: bucket,
              child: outer == null
                  ? viewer
                  : PageView(
                      controller: outer,
                      children: [
                        viewer,
                        const Center(child: Text('Next Work')),
                      ],
                    ),
            ),
          ),
        ),
      );
  Widget get viewer => GroupViewerScope(
    entry: entry,
    child: MediaGroupViewer(details: details),
  );
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    harness.dispose();
    await tester.pump();
  }
}

Finder _button(String label) => find.byWidgetPredicate(
  (widget) => widget is IconButton && widget.tooltip == label,
);

void main() {
  testWidgets(
    'single-Page image boundary stays in Work while details swipe changes outer Work',
    (tester) async {
      final fixture = _Fixture(pageCount: 1);
      final outer = PageController();
      addTearDown(outer.dispose);
      await fixture.mount(tester, outer: outer);
      addTearDown(() => fixture.close(tester));
      final imagePager = find.descendant(
        of: find.byType(MediaGroupViewer),
        matching: find.byType(PageView),
      );
      await tester.drag(imagePager, const Offset(-700, 0));
      await tester.pumpAndSettle();
      expect(outer.page, 0);
      final details = find
          .descendant(
            of: find.byType(MediaGroupViewer),
            matching: find.byType(SingleChildScrollView),
          )
          .first;
      await tester.drag(details, const Offset(-700, 0));
      await tester.pumpAndSettle();
      expect(outer.page, 1);
      expect(find.text('Next Work'), findsOneWidget);
      outer.jumpToPage(0);
      await tester.pumpAndSettle();
      final text = find.textContaining('Selectable description');
      await tester.longPressAt(tester.getTopLeft(text) + const Offset(12, 12));
      await tester.pumpAndSettle();
      expect(
        tester
            .state<SelectableRegionState>(find.byType(SelectableRegion))
            .selectionOverlay,
        isNotNull,
      );
    },
  );

  testWidgets(
    'native controls and scrollable metadata fit narrow short layout at enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 360);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final fixture = _Fixture();
      await fixture.mount(tester);
      addTearDown(() => fixture.close(tester));
      expect(_button('Bookmark Work / Gallery').hitTestable(), findsOneWidget);
      expect(_button('Download current Page').hitTestable(), findsOneWidget);
      await tester.tap(_button('Overview'));
      await tester.pump();
      expect(_button('Image View').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'portable Page beyond first40 waits for its stable slot before publishing actions',
    (tester) async {
      final fixture = _Fixture(pageCount: 85, initialMemberKey: 'page-45');
      fixture.initialBatch = fixture.firstBatch(40);
      final ready = Completer<void>();
      var loads = 0;
      fixture.onNext = (controller) async {
        loads++;
        await ready.future;
        controller.publish(fixture.members);
      };
      await fixture.mount(tester);
      addTearDown(() => fixture.close(tester));
      expect(loads, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<IconButton>(_button('Download current Page')).onPressed,
        isNull,
      );
      expect(find.text('40 / 85'), findsNothing);
      ready.complete();
      await tester.pumpAndSettle();
      expect(find.text('45 / 85'), findsOneWidget);
      expect(
        tester.widget<IconButton>(_button('Download current Page')).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'evicted occurrence restores late Page, Overview and its bounded transform checkpoint',
    (tester) async {
      final fixture = _Fixture(pageCount: 85);
      await fixture.mount(tester);
      addTearDown(() => fixture.close(tester));
      final pager = tester.widget<PageView>(find.byType(PageView));
      pager.controller!.jumpToPage(44);
      await tester.pumpAndSettle();
      expect(find.text('45 / 85'), findsOneWidget);
      final transform = tester
          .widget<PostViewerTransformationScope>(
            find.byType(PostViewerTransformationScope).first,
          )
          .controller
          .transformationController;
      final matrix = Matrix4.identity()
        ..scaleByDouble(2, 2, 1, 1)
        ..setTranslationRaw(-20, -30, 0);
      transform.value = matrix;
      await tester.tap(_button('Overview'));
      await tester.pump();
      // The shared viewer constrains injected pan to real painted bounds.
      // Retain that actual visible position, rather than the out-of-bounds input.
      final expected = transform.value.clone();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      fixture.initialBatch = fixture.firstBatch(40);
      fixture.harness.container.invalidate(groupMembersProvider(fixture.key));
      final ready = Completer<void>();
      fixture.onNext = (controller) async {
        await ready.future;
        controller.publish(fixture.members);
      };
      await fixture.mount(tester);
      expect(
        tester.widget<IconButton>(_button('Download current Page')).onPressed,
        isNull,
      );
      ready.complete();
      await tester.pumpAndSettle();
      expect(find.text('45 / 85'), findsOneWidget);
      expect(_button('Image View'), findsOneWidget);
      final restored = tester
          .widget<PostViewerTransformationScope>(
            find.byType(PostViewerTransformationScope).first,
          )
          .controller
          .transformationController
          .value;
      expect(restored.storage, expected.storage);
    },
  );

  testWidgets(
    'real native Page pager retains missing source position and clears Page actions during reload',
    (tester) async {
      final fixture = _Fixture();
      await fixture.mount(tester);
      addTearDown(() => fixture.close(tester));
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.textContaining('Selectable description'), findsOneWidget);
      expect(
        tester.widget<IconButton>(_button('Download current Page')).onPressed,
        isNotNull,
      );
      final pager = find.byType(PageView);
      await tester.drag(pager, const Offset(-700, 0));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('Page unavailable'), findsOneWidget);
      expect(
        tester.widget<IconButton>(_button('Download current Page')).onPressed,
        isNull,
      );
      // Missing media never disables the independent whole-Group target.
      expect(
        tester.widget<IconButton>(_button('Bookmark Work / Gallery')).onPressed,
        isNotNull,
      );
      await tester.drag(pager, const Offset(-700, 0));
      await tester.pumpAndSettle();
      expect(find.text('3 / 3'), findsOneWidget);
      expect(
        tester.widget<IconButton>(_button('Download current Page')).onPressed,
        isNotNull,
      );
      (fixture.harness.container.read(
        groupMembersProvider(fixture.key).notifier,
      ) as _Members).pending();
      await tester.pump();
      expect(
        tester.widget<IconButton>(_button('Download current Page')).onPressed,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets(
    'initial portable Page key opens its real source position; Overview preserves selection',
    (tester) async {
      final fixture = _Fixture(initialMemberKey: 'page-3');
      await fixture.mount(tester);
      addTearDown(() => fixture.close(tester));
      expect(find.text('3 / 3'), findsOneWidget);
      await tester.tap(_button('Overview'));
      await tester.pump();
      expect(_button('Image View'), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('3 / 3'), findsOneWidget);
    },
  );

  testWidgets(
    'normal Bookmark opens only a whole-Group draft with no implicit Page records',
    (tester) async {
      final fixture = _Fixture();
      await fixture.mount(tester);
      addTearDown(() => fixture.close(tester));
      await tester.tap(_button('Bookmark Work / Gallery'));
      await tester.pumpAndSettle();
      final picker = tester.widget<BookmarkGroupPicker>(
        find.byType(BookmarkGroupPicker),
      );
      expect(picker.request, isA<ContentGroupBookmarkPickerRequest>());
      final request = picker.request as ContentGroupBookmarkPickerRequest;
      expect(request.draft.reference, fixture.details.summary.reference);
      expect(request.draft.id, 0);
      expect(
        fixture.harness.container.read(bookmarkProvider).requireValue.records,
        isEmpty,
      );
    },
  );

  testWidgets(
    'hold selects captured Page once and does not invoke normal Group tap',
    (tester) async {
      final fixture = _Fixture(initialMemberKey: 'page-3');
      await fixture.mount(tester);
      addTearDown(() => fixture.close(tester));
      await tester.longPress(_button('Bookmark Work / Gallery'));
      await tester.pumpAndSettle();
      expect(find.byType(BookmarkGroupPicker), findsNothing);
      // This request was captured before displaying the choice surface.
      await tester.tap(find.text('Bookmark current Page'));
      await tester.pumpAndSettle();
      final picker = tester.widget<BookmarkGroupPicker>(
        find.byType(BookmarkGroupPicker),
      );
      final request = picker.request as PostBookmarkPickerRequest;
      expect(
        const ContentReferenceCodec()
            .fromPost(request.post, site: Uri.parse(fixture.access.config!.url))
            ?.sourceKey,
        'gallery-page:101:3',
      );
      expect(
        fixture.harness.container.read(bookmarkProvider).requireValue.records,
        isEmpty,
      );
    },
  );
}
