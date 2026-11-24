import 'dart:async';
import 'dart:convert';

import 'package:booru_clients/core.dart';
import 'package:booru_clients/gelbooru.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import 'package:boorusama/boorus/gelbooru/configs/widgets.dart';
import 'package:boorusama/boorus/gelbooru_v2/configs/widgets.dart';
import 'package:boorusama/boorus/philomena/configs/widgets.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/auth/widgets.dart';
import 'package:boorusama/core/configs/auth/src/website_credentials.dart';
import 'package:boorusama/core/configs/auth/src/widgets/website_credential_import_button.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/create/providers.dart';
import 'package:boorusama/core/configs/create/src/types/edit_booru_config_id.dart';
import 'package:boorusama/core/configs/create/widgets.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/foundation/browser/providers.dart';
import 'package:boorusama/foundation/browser/types.dart';

import '../../support/fake_embedded_browser.dart';

const _key = 'synthetic-api-key-9876';
const _session = 'synthetic-website-session';
const _browserAccount = '84';

Finder _websiteLoginAction(String label) => find.descendant(
  of: find.byType(WebsiteCredentialImportButton),
  matching: find.text(label),
);

void main() {
  for (final site in [
    WebsiteCredentialSite.gelbooru,
    WebsiteCredentialSite.rule34,
  ]) {
    testWidgets(
      '$site replaces the whole draft on confirmation and saves normally',
      (
        tester,
      ) async {
        final setup = await _open(tester, site);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await _finishLogin(tester, setup.browser, site);

        expect(find.text('Import Website Credentials'), findsOneWidget);
        expect(find.text('User ID: $_browserAccount'), findsOneWidget);
        expect(find.text('API Key: ••••••••'), findsOneWidget);
        expect(find.textContaining(_key), findsNothing);
        expect(find.textContaining(_session), findsNothing);
        expect(setup.draft().login, '42');
        expect(setup.draft().apiKey, 'previous-key');
        expect(setup.saved, isEmpty);

        final apply = find.text('Use Credentials');
        await tester.ensureVisible(apply);
        await tester.tap(apply);
        await tester.pumpAndSettle();
        tester.view.resetViewInsets();
        await tester.pump();

        final expectedSession = site == WebsiteCredentialSite.gelbooru
            ? _session
            : Rule34WebsiteSession.fromCookies(
                signedUserId: '$_browserAccount.synthetic-signature',
                token: _session,
              )!.toStoredValue();
        expect(setup.draft().login, _browserAccount);
        expect(setup.draft().apiKey, _key);
        expect(setup.draft().passHash, expectedSession);
        expect(setup.saved, isEmpty);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is EditableText && widget.controller.text == _key,
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(setup.saved.single.login, _browserAccount);
        expect(setup.saved.single.apiKey, _key);
        expect(setup.saved.single.passHash, expectedSession);
      },
    );
  }

  testWidgets(
    'Realbooru shows the imported account and logs it out',
    (
      tester,
    ) async {
      const site = WebsiteCredentialSite.realbooru;
      final logoutBrowser = FakeEmbeddedBrowserSession();
      var apiProbes = 0;
      final setup = await _open(
        tester,
        site,
        additionalSessions: [logoutBrowser],
        validator: (_, _, _, _) async {
          apiProbes++;
          return false;
        },
      );
      await _finishLogin(tester, setup.browser, site);

      expect(apiProbes, 0);
      expect(find.text('Website session available'), findsOneWidget);
      expect(find.text('API Key: ••••••••'), findsNothing);
      await tester.tap(find.text('Use Credentials'));
      await tester.pumpAndSettle();

      expect(_websiteLoginAction('Re-Login'), findsOneWidget);
      expect(find.byType(EditableText), findsNothing);
      expect(find.text('Login with Browser'), findsNothing);
      expect(setup.saved, isEmpty);
      expect(setup.draft().login, _browserAccount);
      expect(setup.draft().apiKey, isEmpty);
      expect(setup.draft().passHash, _session);

      final account = find.text('User ID: $_browserAccount');
      expect(account, findsOneWidget);
      expect(
        tester.getBottomLeft(account).dy,
        lessThan(tester.getTopLeft(_websiteLoginAction('Re-Login')).dy),
      );
      _setSession(logoutBrowser, site);
      await tester.tap(find.text('Logout'));
      await tester.pump();

      expect(logoutBrowser.loadedUris, [
        Uri.https(site.host, '/index.php', {
          'page': 'account',
          's': 'login',
          'code': '01',
        }),
      ]);
      expect(find.text('Logging out…'), findsOneWidget);
      expect(setup.draft().login, _browserAccount);
      logoutBrowser.emit(
        BrowserEvent(
          kind: BrowserEventKind.navigationCompleted,
          uri: Uri.parse('about:blank'),
        ),
      );
      await tester.pump();
      expect(find.text('Logging out…'), findsOneWidget);
      logoutBrowser.cookiesByUri.clear();
      logoutBrowser.current = site.optionsUri;
      await _completePage(tester, logoutBrowser);
      await tester.pumpAndSettle();

      expect(logoutBrowser.disposed, isTrue);
      expect(_websiteLoginAction('Login'), findsOneWidget);
      expect(account, findsNothing);
      expect(find.text('Logout'), findsNothing);
      expect(setup.draft().login, isEmpty);
      expect(setup.draft().apiKey, isEmpty);
      expect(setup.draft().passHash, isNull);
      expect(setup.saved, isEmpty);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(setup.saved.single.login, isEmpty);
      expect(setup.saved.single.apiKey, isEmpty);
      expect(setup.saved.single.passHash, isNull);
    },
  );

  test('Realbooru logout leaves a different browser account alone', () async {
    final browser = FakeEmbeddedBrowserSession();
    _setSession(browser, WebsiteCredentialSite.realbooru, userId: '85');
    final factory = FakeEmbeddedBrowserFactory(sessions: [browser]);

    expect(
      await signOutRealbooruBrowser(factory, userId: _browserAccount),
      isTrue,
    );
    expect(browser.loadedUris, isEmpty);
    expect(browser.disposed, isTrue);
  });

  for (final site in [
    WebsiteCredentialSite.danbooru,
    WebsiteCredentialSite.safebooru,
    WebsiteCredentialSite.e621,
    WebsiteCredentialSite.derpibooru,
  ]) {
    testWidgets(
      '$site imports an existing key and populates the draft fields',
      (
        tester,
      ) async {
        const login = 'website_user';
        const alternateKey = 'second-synthetic-api-key';
        final setup = await _open(tester, site, withCredentials: false);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        final browser = setup.browser;
        if (site.destinationScript case final script?) {
          browser.javascriptResults[script] = '84';
          await _completePage(tester, browser);
          expect(browser.loadedUris, [
            site.loginUri,
            Uri.https(site.host, '/users/84/api_keys'),
          ]);
        } else {
          browser.current = site.optionsUri;
        }
        browser.javascriptResults[site.extractorScript] = jsonEncode([
          if (site.importsLogin)
            {'login': login, 'name': 'Other Client', 'apiKey': alternateKey},
          {
            if (site.importsLogin) ...{'login': login, 'name': 'Boorusama'},
            'apiKey': _key,
          },
        ]);
        await _completePage(tester, browser);
        await tester.pumpAndSettle();

        if (site.importsLogin) {
          expect(find.text('Choose an API Key'), findsOneWidget);
          expect(find.textContaining(alternateKey), findsNothing);
          final keyChoice = find.text('Boorusama');
          await tester.ensureVisible(keyChoice);
          await tester.tap(keyChoice);
          await tester.pumpAndSettle();
          expect(find.text('Username: $login'), findsOneWidget);
        }
        expect(find.text('API Key: ••••••••'), findsOneWidget);
        expect(find.text('Website session available'), findsNothing);
        expect(find.textContaining(_key), findsNothing);

        final apply = find.text('Use Credentials');
        await tester.ensureVisible(apply);
        await tester.tap(apply);
        await tester.pumpAndSettle();
        expect(setup.draft().login, site.importsLogin ? login : '');
        expect(setup.draft().apiKey, _key);
        expect(setup.draft().passHash, isNull);
        expect(setup.saved, isEmpty);
        expect(_websiteLoginAction('Re-Login'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is EditableText && widget.controller.text == _key,
          ),
          findsOneWidget,
        );
      },
    );
  }

  test(
    'Realbooru requires signed-in browser evidence and matching cookies',
    () {
      const site = WebsiteCredentialSite.realbooru;
      const session = (userId: '84', passHash: _session);
      for (final result in ['signed-in', '"signed-in"']) {
        final credentials = site.candidates(result, session: session).single;
        expect(credentials.login, session.userId);
        expect(credentials.passHash, session.passHash);
      }
      expect(site.candidates('guest', session: session), isEmpty);
      expect(site.candidates('', session: session), isEmpty);
      expect(site.candidates('signed-in'), isEmpty);
    },
  );

  testWidgets('Realbooru rejects a guest page with stale session cookies', (
    tester,
  ) async {
    const site = WebsiteCredentialSite.realbooru;
    final setup = await _open(tester, site);
    final browser = setup.browser;
    _setSession(browser, site);
    browser.current = site.optionsUri;
    browser.javascriptResults[site.extractorScript] = '';
    await _completePage(tester, browser);
    await tester.pumpAndSettle();

    expect(find.textContaining('confirmed your sign-in'), findsOneWidget);
    expect(find.text('Import Website Credentials'), findsNothing);
    expect(setup.draft().login, '42');

    _setExtraction(browser, site, userId: _browserAccount);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Import Website Credentials'), findsOneWidget);
  });

  test('key probes use their site’s authentication and success response', () {
    const danbooru = WebsiteCredentialSite.danbooru;
    final pair = danbooru
        .candidates(
          jsonEncode([
            {'login': 'website_user', 'apiKey': _key},
          ]),
        )
        .single;
    expect(danbooru.probeUri(pair), Uri.https(danbooru.host, '/profile.json'));
    expect(
      WebsiteCredentialSite.safebooru.probeUri(pair),
      Uri.https('safebooru.donmai.us', '/profile.json'),
    );
    expect(danbooru.probeHeaders(pair)['Authorization'], startsWith('Basic '));
    expect(
      danbooru.acceptsProbe({'id': 84, 'name': pair.login}, credentials: pair),
      isTrue,
    );
    expect(
      danbooru.acceptsProbe({
        'id': 84,
        'name': 'another_user',
      }, credentials: pair),
      isFalse,
    );

    const e621 = WebsiteCredentialSite.e621;
    expect(e621.probeUri(pair).queryParameters, {'limit': '1'});
    expect(
      e621.acceptsProbe({
        'posts': [
          {'id': 99},
        ],
      }),
      isTrue,
    );
    expect(
      e621.acceptsProbe({'success': false, 'message': 'Access denied'}),
      isFalse,
    );

    const derpibooru = WebsiteCredentialSite.derpibooru;
    expect(derpibooru.probeUri(pair).path, '/api/v1/json/filters/user');
    expect(derpibooru.acceptsProbe({'filters': [], 'total': 0}), isTrue);
    expect(derpibooru.acceptsProbe({'images': [], 'total': 0}), isFalse);
  });

  testWidgets('import changes Login to Re-Login in a new draft', (
    tester,
  ) async {
    const site = WebsiteCredentialSite.gelbooru;
    final setup = await _open(tester, site, withCredentials: false);
    await _finishLogin(tester, setup.browser, site);

    await tester.tap(find.text('Use Credentials'));
    await tester.pumpAndSettle();

    expect(_websiteLoginAction('Re-Login'), findsOneWidget);
    expect(setup.draft().login, _browserAccount);
    expect(setup.saved, isEmpty);
  });

  testWidgets(
    'cancelled preview keeps the website open for another extraction',
    (
      tester,
    ) async {
      const site = WebsiteCredentialSite.rule34;
      final setup = await _open(tester, site);
      await _finishLogin(tester, setup.browser, site);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(setup.draft().login, '42');
      expect(setup.draft().apiKey, 'previous-key');
      expect(setup.saved, isEmpty);
      expect(setup.browser.disposed, isFalse);
      expect(setup.browser.current, site.optionsUri);
      expect(find.text('Import Website Credentials'), findsNothing);

      await tester.tap(find.text('Extract Credentials'));
      await tester.pumpAndSettle();
      expect(find.text('Import Website Credentials'), findsOneWidget);
      expect(setup.draft().login, '42');
    },
  );

  for (final site in [
    WebsiteCredentialSite.rule34,
    WebsiteCredentialSite.realbooru,
  ]) {
    testWidgets(
      '$site rejects an account that changed while the preview was open',
      (tester) async {
        final setup = await _open(tester, site);
        await _finishLogin(tester, setup.browser, site);
        _setSession(setup.browser, site, userId: '85');

        await tester.tap(find.text('Use Credentials'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining("Couldn't read a matching website session"),
          findsOneWidget,
        );
        expect(setup.draft().login, '42');
        expect(setup.saved, isEmpty);
      },
    );
  }

  testWidgets('an incomplete or mismatched extraction can be retried', (
    tester,
  ) async {
    const site = WebsiteCredentialSite.gelbooru;
    var checks = 0;
    final setup = await _open(
      tester,
      site,
      validator: (_, _, _, _) async => ++checks > 1,
    );
    await _finishLogin(tester, setup.browser, site, extractedUserId: '85');

    expect(checks, 0);
    expect(
      find.textContaining("Couldn't read an existing API key"),
      findsOneWidget,
    );

    _setExtraction(setup.browser, site, userId: _browserAccount);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(checks, 1);
    expect(find.textContaining("Couldn't verify API access"), findsOneWidget);
    expect(setup.draft().login, '42');

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(checks, 2);
    expect(find.text('Import Website Credentials'), findsOneWidget);
  });

  testWidgets(
    'foreign navigation cancels validation and drops a late success',
    (
      tester,
    ) async {
      const site = WebsiteCredentialSite.rule34;
      final result = Completer<bool>();
      CancelToken? probe;
      final setup = await _open(
        tester,
        site,
        validator: (_, _, _, token) {
          probe = token;
          return result.future;
        },
      );
      await _finishLogin(tester, setup.browser, site, settle: false);
      expect(probe, isNotNull);

      final foreign = Uri.https('different.example', '/index.php', {
        'page': 'account',
        's': 'options',
      });
      setup.browser.current = foreign;
      setup.browser.emit(
        BrowserEvent(kind: BrowserEventKind.navigationStarted, uri: foreign),
      );
      await _completePage(tester, setup.browser);
      expect(probe!.isCancelled, isTrue);

      result.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('Import Website Credentials'), findsNothing);
      expect(setup.draft().login, '42');
    },
  );

  testWidgets('a newer credential draft wins over an in-flight import', (
    tester,
  ) async {
    const site = WebsiteCredentialSite.gelbooru;
    final setup = await _open(tester, site);
    await _finishLogin(tester, setup.browser, site);
    setup.updateKey('newer-draft-key');

    await tester.tap(find.text('Use Credentials'));
    await tester.pumpAndSettle();

    expect(setup.draft().login, '42');
    expect(setup.draft().apiKey, 'newer-draft-key');
    expect(setup.saved, isEmpty);
  });

  testWidgets('unsupported platforms can return with the back button', (
    tester,
  ) async {
    final setup = await _open(
      tester,
      WebsiteCredentialSite.gelbooru,
      availability: const BrowserAvailability(
        kind: BrowserAvailabilityKind.unsupportedPlatform,
        backend: BrowserBackend.unsupported,
      ),
    );
    expect(
      find.text('Embedded browser is unavailable on this platform.'),
      findsOneWidget,
    );

    expect(find.text('Manual entry'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(_websiteLoginAction('Re-Login'), findsOneWidget);
    expect(setup.draft().login, '42');
  });

  test(
    'site matching rejects alternate domains, transports and account routes',
    () {
      for (final url in [
        'https://gelbooru.com.example/',
        'https://gelbooru.com:8443/',
        'http://gelbooru.com/',
        'https://user@gelbooru.com/',
        'https://gelbooru.com/index.php?page=account&s=options',
      ]) {
        expect(
          WebsiteCredentialSite.forProfile(BooruType.gelbooru, url),
          isNull,
        );
      }
      expect(
        WebsiteCredentialSite.forProfile(
          BooruType.gelbooruV2,
          'https://api.rule34.xxx/',
        ),
        isNull,
      );
      expect(
        WebsiteCredentialSite.rule34.isOptions(
          Uri.parse(
            'https://rule34.xxx/index.php?page=account&s=options&s=login',
          ),
        ),
        isFalse,
      );
    },
  );

  test(
    'the probe recognizes only a successful shape from the correct site',
    () {
      const gelbooru = WebsiteCredentialSite.gelbooru;
      const rule34 = WebsiteCredentialSite.rule34;
      final post = {'id': 9};
      expect(
        gelbooru.acceptsProbe(
          jsonEncode({
            '@attributes': {'count': 12},
            'post': [post],
          }),
        ),
        isTrue,
      );
      expect(rule34.acceptsProbe([post]), isTrue);

      for (final payload in [
        null,
        [],
        [{}],
        '<html>Sign in</html>',
        '"Missing authentication"',
        '{"error":"Invalid API key"}',
        '{"success":false,"message":"search down"}',
      ]) {
        expect(rule34.acceptsProbe(payload), isFalse);
        expect(gelbooru.acceptsProbe(payload), isFalse);
      }
    },
  );

  test('cookies must be usable on both website endpoints', () async {
    const site = WebsiteCredentialSite.rule34;
    final browser = FakeEmbeddedBrowserSession();
    addTearDown(browser.dispose);
    _setSession(browser, site);
    browser.cookiesByUri.remove(Uri.https(site.host, '/public/addfav.php'));
    expect(await site.readSession(browser), isNotNull);
    expect(await site.readSession(browser, forImport: true), isNull);

    _setSession(browser, site, expiresUtc: DateTime.utc(2000));
    expect(await site.readSession(browser), isNull);
  });
}

Future<void> _finishLogin(
  WidgetTester tester,
  FakeEmbeddedBrowserSession browser,
  WebsiteCredentialSite site, {
  String extractedUserId = _browserAccount,
  bool settle = true,
}) async {
  expect(browser.loadedUris, [site.loginUri]);
  await _completePage(tester, browser);
  expect(browser.loadedUris, [site.loginUri]);

  _setSession(browser, site);
  _setExtraction(browser, site, userId: extractedUserId);
  browser.current = Uri.https(site.host, '/index.php', {
    'page': 'post',
    's': 'list',
  });
  await _completePage(tester, browser);
  expect(browser.loadedUris, [site.loginUri, site.optionsUri]);
  await _completePage(tester, browser);

  if (settle) await tester.pumpAndSettle();
}

Future<void> _completePage(
  WidgetTester tester,
  FakeEmbeddedBrowserSession browser,
) async {
  browser.emit(
    BrowserEvent(
      kind: BrowserEventKind.navigationStarted,
      uri: browser.current,
    ),
  );
  browser.emit(
    BrowserEvent(
      kind: BrowserEventKind.navigationCompleted,
      uri: browser.current,
    ),
  );
  await tester.pump();
}

void _setExtraction(
  FakeEmbeddedBrowserSession browser,
  WebsiteCredentialSite site, {
  required String userId,
}) {
  if (site == WebsiteCredentialSite.realbooru) {
    browser.javascriptResults[site.extractorScript] = 'signed-in';
    return;
  }
  final result = jsonEncode({'userId': userId, 'apiKey': _key});
  browser.javascriptResults[site.extractorScript] =
      site == WebsiteCredentialSite.rule34 ? jsonEncode(result) : result;
}

void _setSession(
  FakeEmbeddedBrowserSession browser,
  WebsiteCredentialSite site, {
  String userId = _browserAccount,
  DateTime? expiresUtc,
}) {
  BrowserCookie cookie(String name, String value) => BrowserCookie(
    name: name,
    value: value,
    domain: site.host,
    path: '/',
    expiresUtc: expiresUtc,
  );
  final cookies = switch (site) {
    WebsiteCredentialSite.gelbooru || WebsiteCredentialSite.realbooru => [
      cookie('user_id', userId),
      cookie('pass_hash', _session),
    ],
    WebsiteCredentialSite.rule34 => [
      cookie(Rule34WebsiteSession.userIdCookie, '$userId.synthetic-signature'),
      cookie(Rule34WebsiteSession.sessionCookie, _session),
    ],
    _ => throw ArgumentError('The site does not use a website session'),
  };
  for (final path in ['/index.php', '/public/addfav.php']) {
    browser.cookiesByUri[Uri.https(site.host, path)] = cookies;
  }
}

Future<
  ({
    FakeEmbeddedBrowserSession browser,
    BooruConfigData Function() draft,
    void Function(String) updateKey,
    List<BooruConfigData> saved,
  })
>
_open(
  WidgetTester tester,
  WebsiteCredentialSite site, {
  BrowserAvailability? availability,
  WebsiteCredentialValidator? validator,
  bool withCredentials = true,
  List<FakeEmbeddedBrowserSession> additionalSessions = const [],
}) async {
  tester.view.physicalSize = const Size(375, 760);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final url = 'https://${site.host}/';
  final profile = BooruConfig.fromJson({
    ...BooruConfig.defaultConfig(
      booruType: switch (site) {
        WebsiteCredentialSite.gelbooru => BooruType.gelbooru,
        WebsiteCredentialSite.danbooru ||
        WebsiteCredentialSite.safebooru => BooruType.danbooru,
        WebsiteCredentialSite.e621 => BooruType.e621,
        WebsiteCredentialSite.derpibooru => BooruType.philomena,
        _ => BooruType.gelbooruV2,
      },
      url: url,
      customDownloadFileNameFormat: null,
    ).toJson(),
    'id': '00000000-0000-4000-8000-000000000042',
    'name': 'Website profile',
    'login': withCredentials ? '42' : '',
    'apiKey': withCredentials ? 'previous-key' : '',
  });
  final browser = FakeEmbeddedBrowserSession();
  final factory = FakeEmbeddedBrowserFactory(
    sessions: [browser, ...additionalSessions],
    availability: availability,
  );
  final id = EditBooruConfigId.fromConfig(profile);
  final saved = <BooruConfigData>[];
  final authView = switch (site) {
    WebsiteCredentialSite.gelbooru => const GelbooruAuthView(),
    WebsiteCredentialSite.rule34 ||
    WebsiteCredentialSite.realbooru => GelbooruV2AuthView(
      authConfig: GelbooruV2Config.siteCapabilities(url).auth,
      requireMatchingWebsiteSession: site == WebsiteCredentialSite.rule34,
    ),
    WebsiteCredentialSite.danbooru ||
    WebsiteCredentialSite.safebooru ||
    WebsiteCredentialSite.e621 => const DefaultBooruAuthConfigView(
      showWebsiteLogin: true,
    ),
    WebsiteCredentialSite.derpibooru => const PhilomenaAuthConfigView(),
  };
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        booruConfigProvider.overrideWith(
          () => _RecordingConfigNotifier(profile, saved),
        ),
        embeddedBrowserFactoryProvider.overrideWithValue(factory),
        websiteCredentialValidatorProvider.overrideWithValue(
          validator ?? (_, _, _, _) async => true,
        ),
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
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.5),
              ),
              child: child!,
            ),
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => CreateBooruConfigScope(
                      id: id,
                      config: profile,
                      child: Scaffold(
                        appBar: AppBar(
                          actions: const [
                            CreateOrUpdateBooruConfigButton(
                              canSubmit: null,
                            ),
                          ],
                        ),
                        body: authView,
                      ),
                    ),
                  ),
                ),
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open editor'));
  await tester.pumpAndSettle();

  final scope = ProviderScope.containerOf(
    tester.element(find.byType(authView.runtimeType)),
    listen: false,
  );
  final loginAction = _websiteLoginAction(
    withCredentials && site.importsKey ? 'Re-Login' : 'Login',
  );
  expect(
    tester.getCenter(loginAction).dx,
    closeTo(tester.view.physicalSize.width / 2, 0.1),
  );
  await tester.tap(loginAction);
  await tester.pumpAndSettle();

  return (
    browser: browser,
    draft: () => scope.read(editBooruConfigProvider(id)),
    updateKey: scope.read(editBooruConfigProvider(id).notifier).updateApiKey,
    saved: saved,
  );
}

class _RecordingConfigNotifier extends BooruConfigNotifier {
  _RecordingConfigNotifier(BooruConfig config, this.saved)
    : super(initialConfigs: [config]);

  final List<BooruConfigData> saved;

  @override
  Future<void> update({
    required BooruConfigData booruConfigData,
    required String oldConfigId,
    void Function(String message)? onFailure,
    void Function(BooruConfig booruConfig)? onSuccess,
  }) async {
    saved.add(booruConfigData);
  }
}
