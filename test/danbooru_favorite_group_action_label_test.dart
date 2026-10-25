import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/providers.dart';
import 'package:boorusama/core/posts/favorites/providers.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/widgets/multi_selection_action_bar.dart';
import 'package:boorusama/boorus/danbooru/posts/listing/src/danbooru_post_grid_presentation.dart';
import 'package:boorusama/boorus/danbooru/posts/post/types.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:i18n/src/gen/strings.g.dart' show LocaleSettings;
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:selection_mode/selection_mode.dart';

import 'package:boorusama/boorus/danbooru/posts/listing/src/danbooru_multi_selection_actions.dart';
import 'package:boorusama/core/analytics/providers.dart';
import 'package:boorusama/core/analytics/download.dart';
import 'package:boorusama/core/bookmarks/src/data/bookmark_convert.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/configs/manage/widgets.dart';
import 'package:boorusama/core/downloads/downloader/providers.dart';
import 'package:boorusama/core/downloads/downloader/types.dart';
import 'package:boorusama/core/downloads/filename/providers.dart';
import 'package:boorusama/core/downloads/filename/types.dart';
import 'package:boorusama/core/downloads/urls/providers.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_grid_controller.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/themes/colors/types.dart';
import 'package:boorusama/foundation/info/package_info.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:foundation/foundation.dart';
import 'package:boorusama/boorus/danbooru/users/user/providers.dart';
import 'package:boorusama/boorus/danbooru/users/user/types.dart';

void main() {
  testWidgets('rating sheet retains the selected source profile', (
    tester,
  ) async {
    final selectedProfile = BooruConfig.fromJson({
      ...BooruConfig.defaultConfig(
        booruType: BooruType.danbooru,
        url: 'https://other.danbooru.test',
        customDownloadFileNameFormat: null,
      ).toJson(),
      'id': '00000000-0000-4000-8000-000000000044',
      'url': 'https://other.danbooru.test',
      'login': 'source-account',
      'apiKey': 'source-key',
    });
    await _pumpActions(
      tester,
      isDevEnvironment: true,
      currentUser: UserSelf.placeholder().copyWith(
        level: UserLevel.contributor,
      ),
      selectedCount: 1,
      width: 620,
      actionProfile: selectedProfile,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Rating'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MassEditRatingSheet)),
    );
    expect(
      container.read(currentReadOnlyBooruConfigAuthProvider),
      selectedProfile.auth,
    );
  });

  for (final width in [210.0, 360.0]) {
    testWidgets('empty selection omits all post actions at $width', (
      tester,
    ) async {
      await _pumpActions(
        tester,
        isDevEnvironment: false,
        currentUser: UserSelf.placeholder(),
        width: width,
        selectedCount: 0,
      );
      expect(find.byType(MultiSelectionActionBar), findsNothing);
      expect(find.text('Download'), findsNothing);
      expect(find.text('Bookmark'), findsNothing);
      expect(find.text('Add to account favorite group'), findsNothing);
    });
  }

  testWidgets(
    'single native post has one overflow and one favorite-group action',
    (tester) async {
      await _pumpActions(
        tester,
        isDevEnvironment: false,
        currentUser: UserSelf.placeholder(),
        width: 360,
        selectedCount: 1,
        nativeSingleActions: true,
      );
      expect(find.text('Download').hitTestable(), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz), findsOneWidget);
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      expect(find.text('Add to account favorite group'), findsOneWidget);
    },
  );

  testWidgets(
    'keeps full favorite-group wording in overflow instead of truncating it',
    (tester) async {
      await _pumpActions(
        tester,
        isDevEnvironment: false,
        currentUser: UserSelf.placeholder(),
        selectedCount: 1,
        width: 360,
      );

      expect(find.text('Add to account favorite group'), findsNothing);
      await tester.tap(find.byIcon(Icons.more_horiz).last);
      await tester.pumpAndSettle();

      expect(find.text('Add to account favorite group'), findsOneWidget);
    },
  );

  testWidgets(
    'omits an unavailable rating action from the overflow menu',
    (tester) async {
      await _pumpActions(
        tester,
        isDevEnvironment: true,
        currentUser: UserSelf.placeholder(),
      );

      await tester.tap(find.byIcon(Icons.more_horiz).last);
      await tester.pumpAndSettle();

      expect(find.text('Add to account favorite group'), findsOneWidget);
      expect(find.text('Edit Rating'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              (widget.properties.button ?? false) &&
              widget.properties.label == '',
        ),
        findsNothing,
      );
    },
  );

  for (final unavailable
      in <
        ({
          String state,
          Future<UserSelf?> Function() loadUser,
        })
      >[
        (
          state: 'loading',
          loadUser: () => Completer<UserSelf?>().future,
        ),
        (
          state: 'error',
          loadUser: () => Future<UserSelf?>.error(StateError('profile failed')),
        ),
      ]) {
    testWidgets(
      'omits the rating action while the account profile is ${unavailable.state}',
      (tester) async {
        await _pumpActions(
          tester,
          isDevEnvironment: true,
          currentUserLoader: unavailable.loadUser,
        );

        await tester.tap(find.byIcon(Icons.more_horiz).last);
        await tester.pumpAndSettle();

        expect(find.text('Download'), findsOneWidget);
        expect(find.text('Bookmark'), findsOneWidget);
        expect(find.text('Add to account favorite group'), findsOneWidget);
        expect(find.text('Edit Rating'), findsNothing);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                (widget.properties.button ?? false) &&
                widget.properties.label == '',
          ),
          findsNothing,
        );
      },
    );
  }

  testWidgets(
    'does not show account actions for a logged-out profile',
    (tester) async {
      await _pumpActions(
        tester,
        isDevEnvironment: true,
        loggedIn: false,
      );

      expect(find.text('Download'), findsOneWidget);
      expect(find.text('Bookmark'), findsOneWidget);
      expect(find.text('Add to account favorite group'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              (widget.properties.button ?? false) &&
              widget.properties.label == '',
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'shows a localized rating action for an unrestricted account',
    (tester) async {
      await _pumpActions(
        tester,
        isDevEnvironment: true,
        currentUser: UserSelf.placeholder().copyWith(
          level: UserLevel.contributor,
        ),
        locale: 'fr-FR',
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_horiz).last);
      await tester.pumpAndSettle();

      expect(
        find.text('Ajouter au groupe de favoris du compte'),
        findsOneWidget,
      );
      expect(find.text("Modifier l'évaluation"), findsOneWidget);
      expect(find.text('Edit Rating'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              (widget.properties.button ?? false) &&
              widget.properties.label == '',
        ),
        findsNothing,
      );
    },
  );

  for (final selectedCount in [1, 2]) {
    testWidgets(
      'opens favorite-group selection for $selectedCount selected post(s)',
      (tester) async {
        final navigator = _RecordingNavigatorObserver();
        await _pumpActions(
          tester,
          isDevEnvironment: false,
          currentUser: UserSelf.placeholder(),
          selectedCount: selectedCount,
          navigator: navigator,
          width: 620,
        );

        await tester.tap(find.byIcon(Icons.more_horiz).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add to account favorite group'));

        expect(navigator.pushedRouteNames, contains('add_to_favorite_group'));
      },
    );
  }

  testWidgets(
    'opens the rating editor for an unrestricted account',
    (tester) async {
      final navigator = _RecordingNavigatorObserver();
      await _pumpActions(
        tester,
        isDevEnvironment: true,
        currentUser: UserSelf.placeholder().copyWith(
          level: UserLevel.contributor,
        ),
        locale: 'fr-FR',
        selectedCount: 1,
        navigator: navigator,
        width: 620,
      );
      await tester.pumpAndSettle();
      final pushesBeforeTap = navigator.pushedRouteNames.length;

      await tester.tap(find.text("Modifier l'évaluation"));
      await tester.pump();

      expect(navigator.pushedRouteNames.length, pushesBeforeTap + 1);
      expect(find.text('Rating'), findsOneWidget);
    },
  );

  testWidgets('localizes the favorite-group selection dialog title', (
    tester,
  ) async {
    await tester.pumpWidget(
      BooruLocalization(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Text(
              context.t.favorite_groups.add_to_group_dialog_title,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Add to account favorite group'), findsOneWidget);
  });
}

Future<void> _pumpActions(
  WidgetTester tester, {
  required bool isDevEnvironment,
  UserSelf? currentUser,
  Future<UserSelf?> Function()? currentUserLoader,
  bool loggedIn = true,
  String locale = 'en-US',
  int selectedCount = 1,
  bool nativeSingleActions = false,
  _RecordingNavigatorObserver? navigator,
  double width = 210,
  BooruConfig? actionProfile,
}) async {
  await tester.runAsync(() => LocaleSettings.setLocaleRaw(locale));
  addTearDown(
    () => tester.runAsync(() => LocaleSettings.setLocaleRaw('en-US')),
  );

  final config =
      BooruConfig.defaultConfig(
        booruType: BooruType.danbooru,
        url: 'https://danbooru.donmai.us',
        customDownloadFileNameFormat: null,
      ).copyWith(
        login: loggedIn ? 'test-account' : '',
        apiKey: loggedIn ? 'test-api-key' : '',
      );
  final targetConfig = actionProfile ?? config;
  final posts = List<Post>.generate(
    selectedCount,
    (index) => Post(
      origin: PostOrigin.fromSource(
        booruType: targetConfig.auth.booruType,
        booruId: targetConfig.booruId,
        source: targetConfig.url,
        profileIdHint: targetConfig.id,
      ),
      core: Bookmark.empty
          .copyWith(postId: () => index + 1, width: 100, height: 100)
          .toPost()
          .core,
      booruData: nativeSingleActions
          ? const DanbooruPostData(
              lastCommentAt: null,
              upScore: 0,
              downScore: 0,
              favCount: 0,
              approverId: null,
              generalTags: {},
              metaTags: {},
              hasChildren: false,
              hasLarge: false,
              pixelHash: '',
            )
          : const EmptyPostData(typeKey: 'test'),
    ),
  );
  final postController = PostGridController<Post>(
    fetcher: (_) => TaskEither.right(
      PostResult(posts: posts, total: posts.length),
    ),
    blacklistedTagsFetcher: () async => const {},
    mountedChecker: () => true,
    duplicateTracker: PostDuplicateTracker(),
    onError: (_) {},
    debounceDuration: Duration.zero,
  );
  addTearDown(postController.dispose);
  await postController.refresh();
  final selectionController = SelectionModeController(
    initialEnabled: selectedCount > 0,
    initialSelected: {
      for (var index = 0; index < selectedCount; index++) index,
    },
  );
  addTearDown(selectionController.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        booruConfigProvider.overrideWith(
          () => BooruConfigNotifier(initialConfigs: [config, ?actionProfile]),
        ),
        bookmarkProvider.overrideWith(_EmptyBookmarks.new),
        canFavoriteProvider.overrideWith((ref, auth) => false),
        booruLoginDetailsProvider.overrideWith(
          (ref, auth) => DefaultBooruLoginDetails(
            login: auth.login,
            apiKey: auth.apiKey,
            url: auth.url,
          ),
        ),
        booruPostPresentationProvider.overrideWith(
          (ref, request) => nativeSingleActions
              ? const DanbooruPostGridPresentation()
              : const GenericPostPresentation(),
        ),
        currentReadOnlyBooruConfigProvider.overrideWithValue(config),
        currentReadOnlyBooruConfigAuthProvider.overrideWithValue(config.auth),
        currentReadOnlyBooruConfigDownloadProvider.overrideWithValue(
          config.download,
        ),
        settingsProvider.overrideWithValue(Settings.defaultSettings),
        isDevEnvironmentProvider.overrideWithValue(isDevEnvironment),
        automaticMediaLoadingEnabledProvider.overrideWithValue(false),
        danbooruCurrentUserProvider.overrideWith(
          (ref, _) => currentUserLoader?.call() ?? Future.value(currentUser),
        ),
        analyticsDownloadObserverProvider.overrideWith(
          (ref, auth) => AnalyticsDownloadObserver(
            analytics: null,
            getConfig: () => auth,
          ),
        ),
        downloadFileUrlExtractorProvider.overrideWith(
          (ref, auth) => const UrlInsidePostExtractor(),
        ),
        // This fixture advertises Download, so supply a usable filename service.
        downloadFilenameBuilderProvider.overrideWith(
          (ref, auth) => fallbackFileNameBuilder,
        ),
        downloadMultipleFileCheckProvider.overrideWith(
          (ref, auth) =>
              () => false,
        ),
        httpHeadersProvider.overrideWith((ref, auth) => const {}),
        downloadServiceProvider.overrideWithValue(_UnusedDownloadService()),
        loggerProvider.overrideWithValue(
          ConsoleLogger(options: const ConsoleLoggerOptions.defaults()),
        ),
      ],
      child: SelectionMode(
        controller: selectionController,
        child: BooruLocalization(
          child: MaterialApp(
            navigatorObservers: [?navigator],
            theme: Kurumi.themeFrom(
              KurumiThemeMode.light,
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              systemDarkMode: false,
            ).withBoorusamaColors(),
            builder: (context, child) => KurumiTheme(
              data: KurumiThemeData.fromMaterial(Theme.of(context)),
              child: child!,
            ),
            home: Scaffold(
              body: SizedBox(
                width: width,
                child: actionProfile == null
                    ? DanbooruMultiSelectionActions(
                        postController: postController,
                      )
                    : CurrentBooruConfigScope(
                        config: actionProfile,
                        child: DanbooruMultiSelectionActions(
                          postController: postController,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  final pushedRouteNames = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRouteNames.add(route.settings.name);
    super.didPush(route, previousRoute);
  }
}

class _EmptyBookmarks extends BookmarkLibraryNotifier {
  @override
  BookmarkLibraryState build() => BookmarkLibraryState(
    bookmarks: const [],
    groups: const [],
    activeTarget: const BookmarkTarget.defaultGroup(),
  );
}

class _UnusedDownloadService implements DownloadService {
  @override
  Future<DownloadResult> download(DownloadOptions options) async =>
      throw UnimplementedError();

  @override
  Future<bool> cancelAll(String group) async => throw UnimplementedError();

  @override
  Future<void> pauseAll(String group) async => throw UnimplementedError();

  @override
  Future<void> resumeAll(String group) async => throw UnimplementedError();
}
