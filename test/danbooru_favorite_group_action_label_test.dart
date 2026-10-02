import 'dart:async';

import 'package:flutter/material.dart';
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
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/downloads/downloader/providers.dart';
import 'package:boorusama/core/downloads/downloader/types.dart';
import 'package:boorusama/core/downloads/filename/providers.dart';
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
  testWidgets(
    'keeps the account favorite-group action disabled with no selection',
    (tester) async {
      await _pumpActions(
        tester,
        isDevEnvironment: false,
        currentUser: UserSelf.placeholder(),
        width: 360,
      );

      final action = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Add to account favorite group',
        ),
      );
      expect(action.properties.button, isTrue);
      expect(action.properties.enabled, isFalse);
      expect(action.properties.onTap, isNull);

      await tester.tap(find.text('Add to account favorite group'));
      await tester.pumpAndSettle();

      expect(find.text('Add to account favorite group'), findsOneWidget);
    },
  );

  testWidgets(
    'keeps the account favorite-group overflow action disabled with no selection',
    (tester) async {
      await _pumpActions(
        tester,
        isDevEnvironment: false,
        currentUser: UserSelf.placeholder(),
      );

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();

      final action = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Add to account favorite group',
        ),
      );
      expect(action.properties.button, isTrue);
      expect(action.properties.enabled, isFalse);
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
      await tester.tap(find.byIcon(Icons.more_horiz));
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

      await tester.tap(find.byIcon(Icons.more_horiz));
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

        await tester.tap(find.byIcon(Icons.more_horiz));
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

      await tester.tap(find.byIcon(Icons.more_horiz));
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

        await tester.tap(find.byIcon(Icons.more_horiz));
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
  int selectedCount = 0,
  _RecordingNavigatorObserver? navigator,
  double width = 210,
}) async {
  await tester.runAsync(() => LocaleSettings.setLocaleRaw(locale));
  addTearDown(
    () => tester.runAsync(() => LocaleSettings.setLocaleRaw('en-US')),
  );

  final config = BooruConfig.empty.copyWith(
    url: 'https://danbooru.donmai.us',
    login: loggedIn ? 'test-account' : '',
    apiKey: loggedIn ? 'test-api-key' : '',
  );
  final posts = List.generate(
    selectedCount,
    (index) => Bookmark.empty
        .copyWith(postId: () => index + 1, width: 100, height: 100)
        .toPost(),
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
        downloadFilenameBuilderProvider.overrideWith((ref, auth) => null),
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
                child: DanbooruMultiSelectionActions(
                  postController: postController,
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
