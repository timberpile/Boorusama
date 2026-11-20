import 'package:booru_clients/core.dart';
import 'package:booru_clients/gelbooru.dart';
import 'package:boorusama/boorus/gelbooru_v2/configs/widgets.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/auth/src/pages/cookie_access_webview_page.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/create/providers.dart';
import 'package:boorusama/core/configs/create/src/types/edit_booru_config_id.dart';
import 'package:boorusama/core/configs/create/widgets.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/debug/data.dart';
import 'package:boorusama/foundation/browser/providers.dart';
import 'package:boorusama/foundation/browser/types.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../support/fake_embedded_browser.dart';

void main() {
  testWidgets('reads website cookies for both Favorite paths', (tester) async {
    final (browser, draft) = await _openRule34Login(tester);
    browser.cookiesByUri[browser.loadedUris.single] = [_clearance];
    _setSession(browser, userId: '42');

    await _import(tester);

    expect(find.byType(CookieAccessWebViewPage), findsNothing);
    expect(_sessionFromDraft(draft()), isNotNull);
    expect(draft().login, '42');
    expect(draft().apiKey, 'fake-api-key');
  });

  testWidgets('missing cookies keep the browser open for a retry', (
    tester,
  ) async {
    final (browser, draft) = await _openRule34Login(tester);
    browser.cookiesByUri[browser.loadedUris.single] = [_clearance];

    await _import(tester);

    expect(
      find.textContaining('hasn’t provided a usable Rule34 session'),
      findsOneWidget,
    );
    expect(find.textContaining('a different Rule34 account'), findsNothing);
    expect(find.byType(CookieAccessWebViewPage), findsOneWidget);
    expect(browser.disposed, false);
    expect(draft().passHash, isNull);
    expect(draft().login, '42');
    expect(draft().apiKey, 'fake-api-key');
    expect(tester.takeException(), isNull);

    _setSession(browser, userId: '42');
    await _import(tester);

    expect(find.byType(CookieAccessWebViewPage), findsNothing);
    expect(_sessionFromDraft(draft()), isNotNull);
  });

  testWidgets('a session scoped to one Favorite path is not imported', (
    tester,
  ) async {
    final (browser, draft) = await _openRule34Login(tester);
    browser.cookiesByUri[_addUri] = _session('42', path: '/public');

    await _import(tester);

    expect(
      find.textContaining('hasn’t provided a usable Rule34 session'),
      findsOneWidget,
    );
    expect(draft().passHash, isNull);
  });

  testWidgets('only a complete session for a different ID reports a mismatch', (
    tester,
  ) async {
    final (browser, draft) = await _openRule34Login(tester);
    _setSession(browser, userId: '43');

    await _import(tester);

    expect(find.textContaining('a different Rule34 account'), findsOneWidget);
    expect(find.byType(CookieAccessWebViewPage), findsOneWidget);
    expect(draft().login, '42');
    expect(draft().apiKey, 'fake-api-key');
    expect(draft().passHash, isNull);
  });
}

final _addUri = Uri.https('rule34.xxx', '/public/addfav.php');
final _indexUri = Uri.https('rule34.xxx', '/index.php');
const _clearance = BrowserCookie(
  name: 'cf_clearance',
  value: 'fake-clearance',
  domain: 'rule34.xxx',
  path: '/',
);

List<BrowserCookie> _session(String userId, {String path = '/'}) => [
  BrowserCookie(
    name: Rule34WebsiteSession.userIdCookie,
    value: '$userId.fake-signature',
    domain: 'rule34.xxx',
    path: path,
  ),
  BrowserCookie(
    name: Rule34WebsiteSession.sessionCookie,
    value: 'fake-session',
    domain: 'rule34.xxx',
    path: path,
  ),
];

Rule34WebsiteSession? _sessionFromDraft(BooruConfigData draft) =>
    Rule34WebsiteSession.fromStoredValue(draft.passHash, userId: draft.login);

void _setSession(FakeEmbeddedBrowserSession browser, {required String userId}) {
  browser.cookiesByUri[_addUri] = _session(userId);
  browser.cookiesByUri[_indexUri] = _session(userId);
}

Future<void> _import(WidgetTester tester) async {
  await tester.tap(find.text('Access Cookie'));
  await tester.pumpAndSettle();
}

Future<(FakeEmbeddedBrowserSession, BooruConfigData Function())>
_openRule34Login(WidgetTester tester) async {
  tester.view.physicalSize = const Size(720, 760);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  const url = 'https://rule34.xxx/';
  final profile = BooruConfig.fromJson({
    ...BooruConfig.defaultConfig(
      booruType: BooruType.gelbooruV2,
      url: url,
      customDownloadFileNameFormat: null,
    ).toJson(),
    'id': '00000000-0000-4000-8000-000000000042',
    'login': '42',
    'apiKey': 'fake-api-key',
  });
  final browser = FakeEmbeddedBrowserSession();
  final factory = FakeEmbeddedBrowserFactory(sessions: [browser]);
  final editId = EditBooruConfigId.fromConfig(profile);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        booruConfigProvider.overrideWith(
          () => BooruConfigNotifier(initialConfigs: [profile]),
        ),
        embeddedBrowserFactoryProvider.overrideWithValue(factory),
        loggerProvider.overrideWithValue(AppLogger()),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          theme: Kurumi.themeFrom(
            KurumiThemeMode.light,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            systemDarkMode: false,
          ),
          builder: (context, child) => KurumiTheme(
            data: KurumiThemeData.fromMaterial(Theme.of(context)),
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
          ),
          home: CreateBooruConfigScope(
            id: editId,
            config: profile,
            child: Scaffold(
              body: GelbooruV2AuthView(
                authConfig: GelbooruV2Config.siteCapabilities(url).auth,
                requireMatchingWebsiteSession: true,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  final target = find.byType(GelbooruV2AuthView);
  final scope = ProviderScope.containerOf(
    tester.element(target),
    listen: false,
  );
  final login = find.text('Login with Browser');
  await tester.ensureVisible(login);
  await tester.tap(login);
  await tester.pumpAndSettle();

  expect(find.byType(CookieAccessWebViewPage), findsOneWidget);
  expect(tester.takeException(), isNull);
  return (browser, () => scope.read(editBooruConfigProvider(editId)));
}
