import 'package:boorusama/core/app_scope.dart';
import 'package:boorusama/core/themes/theme/widgets.dart';
import 'package:boorusama/core/bookmarks/src/pages/bookmark_group_browser_page.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_profile_availability.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_group_selectors.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_grid_entry.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:boorusama/core/content/groups/group_source_provider.dart';
import 'package:boorusama/boorus/danbooru/pools/group_capability.dart';
import 'package:boorusama/core/posts/details/src/types/post_presentation_fallback_reason.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/post_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/stored_group_snapshot.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_local_group_card.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_pool_card.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';
import 'package:kurumi/kurumi.dart';

import 'support/app_flow_finders.dart';
import 'support/fake_booru_backend.dart';
import 'support/headless_app_harness.dart';

const _parent = '10000000-0000-4000-8000-000000000001';
const _child = '10000000-0000-4000-8000-000000000002';

class _Configs extends BooruConfigNotifier {
  _Configs(BooruConfig config) : super(initialConfigs: [config]);
  void replace(List<BooruConfig> values) => state = values;
}

class _Bookmarks extends BookmarkLibraryNotifier {
  _Bookmarks(this.initial);
  final BookmarkLibraryState initial;
  @override
  BookmarkLibraryState build() => initial;
}

BookmarkLibraryState _library(BooruConfig config, {required bool hinted}) {
  final date = DateTime.utc(2026, 1, 1);
  final legacy = PostBookmark(
    id: 101,
    booruId: config.booruId,
    createdAt: date,
    updatedAt: date,
    thumbnailUrl: '',
    sampleUrl: '',
    originalUrl: '',
    sourceUrl: config.url,
    width: 100,
    height: 100,
    md5: '',
    tags: const {'cat'},
    realSourceUrl: null,
    format: 'jpg',
    imageUrlResolver: const DefaultImageUrlResolver(),
    postId: 101,
    metadata: const {},
  );
  final post = legacy.post.copyWith(
    origin: PostOrigin.fromSource(
      booruType: BooruType.danbooru,
      booruId: config.booruId,
      source: config.url,
      profileIdHint: hinted ? config.id : null,
    ),
  );
  final savedPost = legacy.copyWith(
    post: post,
    snapshot: const StoredPostCodec().encode(post),
  );
  final reference = const ContentReferenceCodec().parse(
    engine: BooruType.danbooru,
    site: Uri.parse(config.url),
    kind: ContentKind.group,
    sourceKey: 'pool:42',
  );
  final pool = ContentGroupBookmark(
    id: 102,
    snapshot: StoredGroupSnapshot(
      summary: ContentGroupSummary(reference: reference, title: 'Saved pool'),
    ),
    createdAt: date,
    observedAt: date,
    sourceProfileHint: hinted ? config.id : null,
  );
  return BookmarkLibraryState(
    bookmarks: [savedPost],
    records: [savedPost, pool],
    groups: [
      BookmarkGroup(
        id: defaultBookmarkGroupId,
        name: 'Default',
        bookmarkIds: const {},
      ),
      BookmarkGroup(id: _parent, name: 'Parent', bookmarkIds: const {101, 102}),
      BookmarkGroup(
        id: _child,
        name: 'Child',
        parentGroupId: _parent,
        bookmarkIds: const {101, 102},
      ),
    ],
  );
}

void main() {
  test('local availability requires a profile or registered safe media', () {
    final config = FakeBooruBackend().config;
    final publicConfig = BooruConfig.fromJson({
      ...config.toJson(),
      'url': 'https://danbooru.donmai.us',
      'booruId': BooruType.danbooru.id,
      'booruIdHint': BooruType.danbooru.id,
    });
    final library = _library(publicConfig, hinted: false);
    final original = library.items.single;
    PostBookmark withUrl(String url) => PostBookmark(
      id: original.id,
      booruId: BooruType.danbooru.id,
      createdAt: original.createdAt,
      updatedAt: original.updatedAt,
      thumbnailUrl: url,
      sampleUrl: '',
      originalUrl: '',
      sourceUrl: publicConfig.url,
      width: 100,
      height: 100,
      md5: '',
      tags: const {'cat'},
      realSourceUrl: null,
      format: 'jpg',
      imageUrlResolver: const DefaultImageUrlResolver(),
      postId: 101,
      metadata: const {},
    );
    BookmarkLibraryState withPost(PostBookmark post) => BookmarkLibraryState(
      bookmarks: [post],
      records: [
        post,
        ...library.records.where((record) => record.id != post.id),
      ],
      groups: library.groups,
    );
    final safe = withPost(withUrl('https://cdn.donmai.us/sample/1.jpg'));
    final projection = BookmarkProfileAvailability(safe, []);
    expect(projection.postIds, {101});
    expect(projection.collectionIds, isEmpty);
    expect(safe.records, hasLength(2));
    expect(
      BookmarkProfileAvailability(
        safe,
        [],
        policy: const AnonymousSourcePolicy(enabled: false),
      ).postIds,
      isEmpty,
    );
    final unsafe = withPost(withUrl('https://localhost/1.jpg'));
    expect(BookmarkProfileAvailability(unsafe, []).postIds, isEmpty);
    expect(BookmarkProfileAvailability(unsafe, [publicConfig]).postIds, {101});
    final second = BooruConfig.fromJson({
      ...publicConfig.toJson(),
      'id': '00000000-0000-4000-8000-000000000002',
    });
    final ambiguous = BookmarkProfileAvailability(safe, [publicConfig, second]);
    expect(ambiguous.postIds, isEmpty);
    expect(
      ambiguous.unavailableReasons[101],
      PostPresentationFallbackReason.ambiguousProfile,
    );
    final unavailable = BookmarkProfileAvailability(unsafe, []);
    List<BookmarkGridEntry> selected(
      String group,
      String source,
      List<String> tags,
    ) => selectBookmarkGridEntries(
      state: unsafe,
      view: BookmarkView.group(group),
      selectedTags: tags,
      selectedBooruUrl: source,
      sortType: BookmarkSortType.newest,
    );
    expect(
      unavailable.countsForEntries(
        selected(_parent, 'danbooru.donmai.us', ['cat']),
      ),
      {PostPresentationFallbackReason.unavailableEngine: 1},
    );
    expect(
      unavailable.countsForEntries(selected(_parent, 'other.example', ['cat'])),
      isEmpty,
    );
    expect(
      unavailable.countsForEntries(
        selected(_parent, 'danbooru.donmai.us', ['dog']),
      ),
      isEmpty,
    );
    expect(
      unavailable.countsForEntries(
        selected(defaultBookmarkGroupId, 'danbooru.donmai.us', ['cat']),
      ),
      isEmpty,
    );

    expect(
      unavailable.countsForEntries([
        BookmarkPostEntry(unsafe.items.single),
        BookmarkPostEntry(unsafe.items.single),
      ]),
      {PostPresentationFallbackReason.unavailableEngine: 1},
    );
  });

  for (final hinted in [true, false]) {
    testWidgets(
      'saved media availability follows compatible profiles (hinted=$hinted)',
      (tester) async {
        final backend = FakeBooruBackend();
        final initial = _library(backend.config, hinted: hinted);
        late _Configs configs;
        final harness = await HeadlessAppHarness.mount(
          tester,
          booruBackend: backend,
          viewportSize: const Size(390, 1100),
          additionalOverrides: [
            bookmarkProvider.overrideWith(() => _Bookmarks(initial)),
            booruGroupCapabilityProvider.overrideWith(
              (ref, type) => type == BooruType.danbooru
                  ? createDanbooruGroupCapability(ref)
                  : null,
            ),
            booruConfigProvider.overrideWith(
              () => configs = _Configs(backend.config),
            ),
          ],
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          BoorusamaAppScope(
            runtime: harness.runtime,
            additionalOverrides: [
              bookmarkProvider.overrideWith(() => _Bookmarks(initial)),
              booruGroupCapabilityProvider.overrideWith(
                (ref, type) => type == BooruType.danbooru
                    ? createDanbooruGroupCapability(ref)
                    : null,
              ),
              booruConfigProvider.overrideWith(
                () => configs = _Configs(backend.config),
              ),
            ],
            child: MediaQuery.fromView(
              view: tester.view,
              child: ThemeBuilder(
                useProfileAppearance: false,
                builder: (theme, _) => MaterialApp(
                  theme: theme,
                  builder: (context, child) => KurumiTheme(
                    data: KurumiThemeData.fromMaterial(Theme.of(context)),
                    child: child!,
                  ),
                  home: const BookmarkGroupBrowserPage(groupId: _parent),
                ),
              ),
            ),
          ),
        );
        await harness.settle(tester);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(BookmarkGroupBrowserPage)),
          listen: false,
        );
        Future<void> setProfiles(List<BooruConfig> profiles) async {
          configs.replace(profiles);
          await harness.settle(tester);
        }

        void retained() {
          final state = container.read(bookmarkProvider).valueOrNull!;
          expect(identical(state, initial), isTrue);
          expect(state.records, hasLength(2));
          expect(state.groupsById[_parent]!.bookmarkIds, {101, 102});
          expect(state.groupsById[_child]!.bookmarkIds, {101, 102});
        }

        void media({required bool visible}) {
          expect(postTile(101), visible ? findsOneWidget : findsNothing);
          expect(
            find.byType(BookmarkPoolCard),
            visible ? findsOneWidget : findsNothing,
          );
          final child = tester.widget<BookmarkLocalGroupCard>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is BookmarkLocalGroupCard && widget.title == 'Child',
            ),
          );
          expect(child.previews.length, visible ? 1 : 0);
          expect(child.pools.length, visible ? 1 : 0);
          retained();
        }

        await setProfiles([]);
        media(visible: false);
        if (hinted) {
          await setProfiles([backend.config]);
          media(visible: true);
          final otherAccount = BooruConfig.fromJson({
            ...backend.config.toJson(),
            'id': '00000000-0000-4000-8000-000000000002',
            'login': 'other-account',
          });
          await setProfiles([backend.config, otherAccount]);
          media(visible: true);
          configs.replace([otherAccount]);
          await tester.pump();
          expect(postTile(101), findsNothing);
          expect(find.byType(BookmarkPoolCard), findsNothing);
          final childAfterRevocation = tester.widget<BookmarkLocalGroupCard>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is BookmarkLocalGroupCard && widget.title == 'Child',
            ),
          );
          expect(childAfterRevocation.previews, isEmpty);
          expect(childAfterRevocation.pools, isEmpty);
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is DefaultImageGridItem &&
                  widget.config.login == 'other-account',
            ),
            findsNothing,
          );
          await harness.settle(tester);
          media(visible: false);
          await setProfiles([]);
          media(visible: false);
          final wrongPath = BooruConfig.fromJson({
            ...backend.config.toJson(),
            'url': '${backend.config.url}other',
          });
          await setProfiles([wrongPath]);
          media(visible: false);
          final wrongEngine = BooruConfig.fromJson({
            ...backend.config.toJson(),
            'booruId': BooruType.gelbooru.id,
            'booruIdHint': BooruType.gelbooru.id,
          });
          await setProfiles([wrongEngine]);
          media(visible: false);
        } else {
          final second = BooruConfig.fromJson({
            ...backend.config.toJson(),
            'id': '00000000-0000-4000-8000-000000000002',
          });
          await setProfiles([backend.config, second]);
          media(visible: false);
          await setProfiles([backend.config]);
          media(visible: true);
          await setProfiles([]);
          media(visible: false);
        }
      },
    );
  }
}
