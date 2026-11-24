// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'test_helpers.dart';

RouteInformation createRouteInformation(String location, [Object? extra]) {
  return RouteInformation(
    uri: Uri.parse(location),
    state: RouteInformationState<void>(type: NavigatingType.go, extra: extra),
  );
}

void main() {
  Future<GoRouteInformationParser> createParser(
    WidgetTester tester, {
    required List<RouteBase> routes,
    int redirectLimit = 5,
    GoRouterRedirect? redirect,
  }) async {
    final router = GoRouter(routes: routes, redirectLimit: redirectLimit, redirect: redirect);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    return router.routeInformationParser;
  }

  testWidgets('GoRouteInformationParser can parse route', (tester) async {
    final routes = <GoRoute>[
      GoRoute(
        path: '/',
        builder: (_, _) => const Placeholder(),
        routes: <GoRoute>[GoRoute(path: 'abc', builder: (_, _) => const Placeholder())],
      ),
    ];
    final parser = await createParser(
      tester,
      routes: routes,
      redirectLimit: 100,
      redirect: (_, _) => null,
    );

    final BuildContext context = tester.element(find.byType(Router<Object>));

    var matchesObj = await parser.parseRouteInformationWithDependencies(
      createRouteInformation('/'),
      context,
    );
    var matches = matchesObj.matches;
    expect(matches.length, 1);
    expect(matchesObj.uri.toString(), '/');
    expect(matchesObj.extra, isNull);
    expect(matches[0].matchedLocation, '/');
    expect(matches[0].route, routes[0]);

    final extra = Object();
    matchesObj = await parser.parseRouteInformationWithDependencies(
      createRouteInformation('/abc?def=ghi', extra),
      context,
    );
    matches = matchesObj.matches;
    expect(matches.length, 2);
    expect(matchesObj.uri.toString(), '/abc?def=ghi');
    expect(matchesObj.extra, extra);
    expect(matches[0].matchedLocation, '/');
    expect(matches[0].route, routes[0]);

    expect(matches[1].matchedLocation, '/abc');
    expect(matches[1].route, routes[0].routes[0]);
  });

  testWidgets('GoRouteInformationParser can handle empty path for non http uri', (
    tester,
  ) async {
    final routes = <GoRoute>[
      GoRoute(
        path: '/',
        builder: (_, _) => const Placeholder(),
        routes: <GoRoute>[GoRoute(path: 'abc', builder: (_, _) => const Placeholder())],
      ),
    ];
    final parser = await createParser(
      tester,
      routes: routes,
      redirectLimit: 100,
      redirect: (_, _) => null,
    );

    final BuildContext context = tester.element(find.byType(Router<Object>));

    final matchesObj = await parser.parseRouteInformationWithDependencies(
      createRouteInformation('elbaapp://domain'),
      context,
    );
    final matches = matchesObj.matches;
    expect(matches.length, 1);
    expect(matchesObj.uri.toString(), 'elbaapp://domain/');
  });

  testWidgets('GoRouteInformationParser cleans up uri', (tester) async {
    final routes = <GoRoute>[
      GoRoute(
        path: '/',
        builder: (_, _) => const Placeholder(),
        routes: <GoRoute>[GoRoute(path: 'abc', builder: (_, _) => const Placeholder())],
      ),
    ];
    final parser = await createParser(
      tester,
      routes: routes,
      redirectLimit: 100,
      redirect: (_, _) => null,
    );

    final BuildContext context = tester.element(find.byType(Router<Object>));

    final matchesObj = await parser.parseRouteInformationWithDependencies(
      createRouteInformation('http://domain/abc/?query=bde'),
      context,
    );
    final matches = matchesObj.matches;
    expect(matches.length, 2);
    expect(matchesObj.uri.toString(), 'http://domain/abc?query=bde');
  });

  testWidgets(
    "GoRouteInformationParser can parse deeplink root route and maintain uri's scheme, host, query and fragment",
    (tester) async {
      const expectedScheme = 'https';
      const expectedHost = 'www.example.com';
      const expectedQuery = 'abc=def';
      const expectedFragment = 'abc';
      const expectedUriString = '$expectedScheme://$expectedHost/?$expectedQuery#$expectedFragment';
      final routes = <GoRoute>[GoRoute(path: '/', builder: (_, _) => const Placeholder())];
      final parser = await createParser(
        tester,
        routes: routes,
        redirectLimit: 100,
        redirect: (_, _) => null,
      );

      final BuildContext context = tester.element(find.byType(Router<Object>));

      final matchesObj = await parser.parseRouteInformationWithDependencies(
        createRouteInformation(expectedUriString),
        context,
      );
      final matches = matchesObj.matches;
      expect(matches.length, 1);
      expect(matchesObj.uri.toString(), expectedUriString);
      expect(matchesObj.uri.scheme, expectedScheme);
      expect(matchesObj.uri.host, expectedHost);
      expect(matchesObj.uri.query, expectedQuery);
      expect(matchesObj.uri.fragment, expectedFragment);

      expect(matches[0].matchedLocation, '/');
      expect(matches[0].route, routes[0]);
    },
  );

  testWidgets(
    "GoRouteInformationParser can parse deeplink route with a path and maintain uri's scheme, host, query and fragment",
    (tester) async {
      const expectedScheme = 'https';
      const expectedHost = 'www.example.com';
      const expectedPath = '/abc';
      const expectedQuery = 'abc=def';
      const expectedFragment = 'abc';
      const expectedUriString =
          '$expectedScheme://$expectedHost$expectedPath?$expectedQuery#$expectedFragment';
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (_, _) => const Placeholder(),
          routes: <GoRoute>[GoRoute(path: 'abc', builder: (_, _) => const Placeholder())],
        ),
      ];
      final parser = await createParser(
        tester,
        routes: routes,
        redirectLimit: 100,
        redirect: (_, _) => null,
      );

      final BuildContext context = tester.element(find.byType(Router<Object>));

      final matchesObj = await parser.parseRouteInformationWithDependencies(
        createRouteInformation(expectedUriString),
        context,
      );
      final matches = matchesObj.matches;
      expect(matches.length, 2);
      expect(matchesObj.uri.toString(), expectedUriString);
      expect(matchesObj.uri.scheme, expectedScheme);
      expect(matchesObj.uri.host, expectedHost);
      expect(matchesObj.uri.path, expectedPath);
      expect(matchesObj.uri.query, expectedQuery);
      expect(matchesObj.uri.fragment, expectedFragment);

      expect(matches[0].matchedLocation, '/');
      expect(matches[0].route, routes[0]);

      expect(matches[1].matchedLocation, '/abc');
      expect(matches[1].route, routes[0].routes[0]);
    },
  );

  testWidgets(
    'GoRouteInformationParser can restore full route matches if optionURLReflectsImperativeAPIs is true',
    (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (_, _) => const Placeholder(),
          routes: <GoRoute>[GoRoute(path: 'abc', builder: (_, _) => const Placeholder())],
        ),
      ];
      GoRouter.optionURLReflectsImperativeAPIs = true;
      final router = await createRouter(routes, tester, navigatorKey: navKey);

      // Generate RouteMatchList with imperative route match
      router.go('/abc');
      await tester.pumpAndSettle();
      router.push('/');
      await tester.pumpAndSettle();
      final matchList = router.routerDelegate.currentConfiguration;
      expect(matchList.uri.toString(), '/abc');
      expect(matchList.matches.length, 3);

      final restoredRouteInformation = router.routeInformationParser.restoreRouteInformation(
        matchList,
      )!;
      expect(restoredRouteInformation.uri.path, '/');

      // Can restore back to original RouteMatchList.
      final parsedRouteMatch = await router.routeInformationParser
          .parseRouteInformationWithDependencies(restoredRouteInformation, navKey.currentContext!);
      expect(parsedRouteMatch.uri.toString(), '/abc');
      expect(parsedRouteMatch.matches.length, 3);

      GoRouter.optionURLReflectsImperativeAPIs = false;
    },
  );

  test('GoRouteInformationParser can retrieve route by name', () {
    final routes = <GoRoute>[
      GoRoute(
        path: '/',
        builder: (_, _) => const Placeholder(),
        routes: <GoRoute>[
          GoRoute(path: 'abc', name: 'lowercase', builder: (_, _) => const Placeholder()),
          GoRoute(path: 'efg', name: 'camelCase', builder: (_, _) => const Placeholder()),
          GoRoute(path: 'hij', name: 'snake_case', builder: (_, _) => const Placeholder()),
        ],
      ),
    ];

    final configuration = createRouteConfiguration(
      routes: routes,
      redirectLimit: 100,
      topRedirect: (_, _) => null,
      navigatorKey: GlobalKey<NavigatorState>(),
    );

    expect(configuration.namedLocation('lowercase'), '/abc');
    expect(configuration.namedLocation('camelCase'), '/efg');
    expect(configuration.namedLocation('snake_case'), '/hij');

    // With query parameters
    expect(configuration.namedLocation('lowercase'), '/abc');
    expect(
      configuration.namedLocation('lowercase', queryParameters: const <String, String>{'q': '1'}),
      '/abc?q=1',
    );
    expect(
      configuration.namedLocation(
        'lowercase',
        queryParameters: const <String, String>{'q': '1', 'g': '2'},
      ),
      '/abc?q=1&g=2',
    );
  });

  test('GoRouteInformationParser can retrieve route by name with query parameters', () {
    final routes = <GoRoute>[
      GoRoute(
        path: '/',
        builder: (_, _) => const Placeholder(),
        routes: <GoRoute>[
          GoRoute(path: 'abc', name: 'routeName', builder: (_, _) => const Placeholder()),
        ],
      ),
    ];

    final configuration = createRouteConfiguration(
      routes: routes,
      redirectLimit: 100,
      topRedirect: (_, _) => null,
      navigatorKey: GlobalKey<NavigatorState>(),
    );

    expect(
      configuration.namedLocation(
        'routeName',
        queryParameters: const <String, dynamic>{
          'q1': 'v1',
          'q2': <String>['v2', 'v3'],
        },
      ),
      '/abc?q1=v1&q2=v2&q2=v3',
    );
  });

  testWidgets('GoRouteInformationParser returns error when unknown route', (
    tester,
  ) async {
    final routes = <GoRoute>[
      GoRoute(
        path: '/',
        builder: (_, _) => const Placeholder(),
        routes: <GoRoute>[GoRoute(path: 'abc', builder: (_, _) => const Placeholder())],
      ),
    ];
    final parser = await createParser(
      tester,
      routes: routes,
      redirectLimit: 100,
      redirect: (_, _) => null,
    );

    final BuildContext context = tester.element(find.byType(Router<Object>));

    final matchesObj = await parser.parseRouteInformationWithDependencies(
      createRouteInformation('/def'),
      context,
    );
    final matches = matchesObj.matches;
    expect(matches.length, 0);
    expect(matchesObj.uri.toString(), '/def');
    expect(matchesObj.extra, isNull);
    expect(matchesObj.error!.toString(), 'GoException: no routes for location: /def');
  });

  testWidgets('GoRouteInformationParser calls redirector with correct uri when unknown route', (
    tester,
  ) async {
    String? lastRedirectLocation;
    final routes = <GoRoute>[
      GoRoute(
        path: '/',
        builder: (_, _) => const Placeholder(),
        routes: <GoRoute>[GoRoute(path: 'abc', builder: (_, _) => const Placeholder())],
      ),
    ];
    final parser = await createParser(
      tester,
      routes: routes,
      redirectLimit: 100,
      redirect: (_, state) {
        lastRedirectLocation = state.uri.toString();
        return null;
      },
    );

    final BuildContext context = tester.element(find.byType(Router<Object>));
    await parser.parseRouteInformationWithDependencies(createRouteInformation('/def'), context);
    expect(lastRedirectLocation, '/def');
  });

  testWidgets('GoRouteInformationParser can work with route parameters', (
    tester,
  ) async {
    final routes = <GoRoute>[
      GoRoute(
        path: '/',
        builder: (_, _) => const Placeholder(),
        routes: <GoRoute>[
          GoRoute(path: ':uid/family/:fid', builder: (_, _) => const Placeholder()),
        ],
      ),
    ];
    final parser = await createParser(
      tester,
      routes: routes,
      redirectLimit: 100,
      redirect: (_, _) => null,
    );

    final BuildContext context = tester.element(find.byType(Router<Object>));
    final matchesObj = await parser.parseRouteInformationWithDependencies(
      createRouteInformation('/123/family/456'),
      context,
    );
    final matches = matchesObj.matches;

    expect(matches.length, 2);
    expect(matchesObj.uri.toString(), '/123/family/456');
    expect(matchesObj.pathParameters.length, 2);
    expect(matchesObj.pathParameters['uid'], '123');
    expect(matchesObj.pathParameters['fid'], '456');
    expect(matchesObj.extra, isNull);
    expect(matches[0].matchedLocation, '/');

    expect(matches[1].matchedLocation, '/123/family/456');
  });

  testWidgets('GoRouteInformationParser processes top level redirect when there is no match', (
    tester,
  ) async {
    final routes = <GoRoute>[
      GoRoute(
        path: '/',
        builder: (_, _) => const Placeholder(),
        routes: <GoRoute>[
          GoRoute(path: ':uid/family/:fid', builder: (_, _) => const Placeholder()),
        ],
      ),
    ];
    final parser = await createParser(
      tester,
      routes: routes,
      redirectLimit: 100,
      redirect: (context, state) {
        if (state.uri.toString() != '/123/family/345') {
          return '/123/family/345';
        }
        return null;
      },
    );

    final BuildContext context = tester.element(find.byType(Router<Object>));
    final matchesObj = await parser.parseRouteInformationWithDependencies(
      createRouteInformation('/random/uri'),
      context,
    );
    final matches = matchesObj.matches;

    expect(matches.length, 2);
    expect(matchesObj.uri.toString(), '/123/family/345');
    expect(matches[0].matchedLocation, '/');

    expect(matches[1].matchedLocation, '/123/family/345');
  });

  testWidgets('GoRouteInformationParser can do route level redirect when there is a match', (
    tester,
  ) async {
    final routes = <GoRoute>[
      GoRoute(
        path: '/',
        builder: (_, _) => const Placeholder(),
        routes: <GoRoute>[
          GoRoute(path: ':uid/family/:fid', builder: (_, _) => const Placeholder()),
          GoRoute(
            path: 'redirect',
            redirect: (_, _) => '/123/family/345',
            builder: (_, _) => throw UnimplementedError(),
          ),
        ],
      ),
    ];
    final parser = await createParser(
      tester,
      routes: routes,
      redirectLimit: 100,
      redirect: (_, _) => null,
    );

    final BuildContext context = tester.element(find.byType(Router<Object>));
    final matchesObj = await parser.parseRouteInformationWithDependencies(
      createRouteInformation('/redirect'),
      context,
    );
    final matches = matchesObj.matches;

    expect(matches.length, 2);
    expect(matchesObj.uri.toString(), '/123/family/345');
    expect(matches[0].matchedLocation, '/');

    expect(matches[1].matchedLocation, '/123/family/345');
  });

  testWidgets('GoRouteInformationParser throws an exception when route is malformed', (
    tester,
  ) async {
    final routes = <GoRoute>[GoRoute(path: '/abc', builder: (_, _) => const Placeholder())];
    final parser = await createParser(
      tester,
      routes: routes,
      redirectLimit: 100,
      redirect: (_, _) => null,
    );

    final BuildContext context = tester.element(find.byType(Router<Object>));
    expect(() async {
      await parser.parseRouteInformationWithDependencies(
        createRouteInformation('::Not valid URI::'),
        context,
      );
    }, throwsA(isA<FormatException>()));
  });

  testWidgets('GoRouteInformationParser returns an error if a redirect is detected.', (
    tester,
  ) async {
    final routes = <GoRoute>[
      GoRoute(
        path: '/abc',
        builder: (_, _) => const Placeholder(),
        redirect: (context, state) => state.uri.toString(),
      ),
    ];
    final parser = await createParser(
      tester,
      routes: routes,
      redirect: (_, _) => null,
    );

    final BuildContext context = tester.element(find.byType(Router<Object>));
    final matchesObj = await parser.parseRouteInformationWithDependencies(
      createRouteInformation('/abd'),
      context,
    );
    final matches = matchesObj.matches;

    expect(matches, hasLength(0));
    expect(matchesObj.error, isNotNull);
  });

  testWidgets('Creates a match for ShellRoute', (tester) async {
    final routes = <RouteBase>[
      ShellRoute(
        builder: (context, state, child) {
          return Scaffold(body: child);
        },
        routes: <RouteBase>[
          GoRoute(
            path: '/a',
            builder: (context, state) {
              return const Scaffold(body: Text('Screen A'));
            },
          ),
          GoRoute(
            path: '/b',
            builder: (context, state) {
              return const Scaffold(body: Text('Screen B'));
            },
          ),
        ],
      ),
    ];
    final parser = await createParser(
      tester,
      routes: routes,
      redirect: (_, _) => null,
    );

    final BuildContext context = tester.element(find.byType(Router<Object>));
    final matchesObj = await parser.parseRouteInformationWithDependencies(
      createRouteInformation('/a'),
      context,
    );
    final matches = matchesObj.matches;

    expect(matches, hasLength(1));
    final match = matches.first as ShellRouteMatch;
    expect(match.matches, hasLength(1));
    expect(matchesObj.error, isNull);
  });

  testWidgets('GoRouteInformationParser can handle path without leading slash', (
    tester,
  ) async {
    final routes = <RouteBase>[GoRoute(path: '/abc', builder: (_, _) => const Placeholder())];
    final parser = await createParser(
      tester,
      routes: routes,
      redirectLimit: 100,
      redirect: (_, _) => null,
    );

    final BuildContext context = tester.element(find.byType(Router<Object>));

    final matchesObj = await parser.parseRouteInformationWithDependencies(
      createRouteInformation('abc'),
      context,
    );
    final matches = matchesObj.matches;
    expect(matches.length, 1);
    expect(matchesObj.uri.toString(), '/abc');
  });
}
