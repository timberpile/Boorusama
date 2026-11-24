// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:go_router/src/match.dart';
import 'package:go_router/src/pages/material.dart';
import 'package:logging/logging.dart';

import 'test_helpers.dart';

const enableLogs = false;
final log = Logger('GoRouter tests');

Future<void> sendPlatformUrl(String url, WidgetTester tester) async {
  final testRouteInformation = <String, dynamic>{'location': url};
  final message = const JSONMethodCodec().encodeMethodCall(
    MethodCall('pushRouteInformation', testRouteInformation),
  );
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    message,
    (_) {},
  );
}

void main() {
  if (enableLogs) {
    Logger.root.onRecord.listen((e) => debugPrint('$e'));
  }

  group('path routes', () {
    testWidgets('match home route', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
      ];

      final router = await createRouter(routes, tester);
      final matches = router.routerDelegate.currentConfiguration;
      expect(matches.matches, hasLength(1));
      expect(matches.uri.toString(), '/');
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('If there is more than one route to match, use the first match', (
      tester,
    ) async {
      final routes = <GoRoute>[
        GoRoute(name: '1', path: '/', builder: dummy),
        GoRoute(name: '2', path: '/', builder: dummy),
      ];

      final router = await createRouter(routes, tester);
      router.go('/');
      final matches = router.routerDelegate.currentConfiguration.matches;
      expect(matches, hasLength(1));
      expect((matches.first.route as GoRoute).name, '1');
      expect(find.byType(DummyScreen), findsOneWidget);
    });

    testWidgets('pushReplacement and replace when only one matches', (tester) async {
      final routes = <GoRoute>[
        GoRoute(name: '1', path: '/', builder: dummy),
        GoRoute(name: '2', path: '/a', builder: dummy),
        GoRoute(name: '3', path: '/b', builder: dummy),
      ];

      final router = await createRouter(routes, tester);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/');

      router.replace<void>('/a');
      await tester.pumpAndSettle();
      // When the imperative match is the only match in the route match list,
      // it should update the uri.
      expect(router.routerDelegate.currentConfiguration.uri.path, '/a');

      router.pushReplacement<void>('/b');
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, '/b');
    });

    test('empty path', () {
      expect(() {
        GoRoute(path: '');
      }, throwsA(isAssertionError));
    });

    test('trailing / on sub-route', () {
      expect(() {
        GoRouter(
          routes: <RouteBase>[
            GoRoute(
              path: '/',
              builder: dummy,
              routes: <GoRoute>[GoRoute(path: 'foo/', builder: dummy)],
            ),
          ],
        );
      }, throwsA(isAssertionError));
    });

    testWidgets('match no routes', (tester) async {
      final routes = <GoRoute>[GoRoute(path: '/', builder: dummy)];

      final router = await createRouter(
        routes,
        tester,
        errorBuilder: (context, state) => TestErrorScreen(state.error!),
      );
      router.go('/foo');
      await tester.pumpAndSettle();
      final matches = router.routerDelegate.currentConfiguration.matches;
      expect(matches, hasLength(0));
      expect(find.byType(TestErrorScreen), findsOneWidget);
    });

    testWidgets('match 2nd top level route', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
      ];

      final router = await createRouter(routes, tester);
      router.go('/login');
      await tester.pumpAndSettle();
      final matches = router.routerDelegate.currentConfiguration.matches;
      expect(matches, hasLength(1));
      expect(matches.first.matchedLocation, '/login');
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('match 2nd top level route with subroutes', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'page1',
              builder: (context, state) => const Page1Screen(),
            ),
          ],
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
      ];

      final router = await createRouter(routes, tester);
      router.go('/login');
      await tester.pumpAndSettle();
      final matches = router.routerDelegate.currentConfiguration.matches;
      expect(matches, hasLength(1));
      expect(matches.first.matchedLocation, '/login');
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('match top level route when location has trailing /', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
      ];

      final router = await createRouter(routes, tester);
      router.go('/login/');
      await tester.pumpAndSettle();
      final matches = router.routerDelegate.currentConfiguration.matches;
      expect(matches, hasLength(1));
      expect(matches.first.matchedLocation, '/login');
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('match top level route when location has trailing / (2)', (
      tester,
    ) async {
      final routes = <GoRoute>[
        GoRoute(path: '/profile', builder: dummy, redirect: (_, _) => '/profile/foo'),
        GoRoute(path: '/profile/:kind', builder: dummy),
      ];

      final router = await createRouter(routes, tester);
      router.go('/profile/');
      await tester.pumpAndSettle();
      final matches = router.routerDelegate.currentConfiguration.matches;
      expect(matches, hasLength(1));
      expect(matches.first.matchedLocation, '/profile/foo');
      expect(find.byType(DummyScreen), findsOneWidget);
    });

    testWidgets('match top level route when location has trailing / (3)', (
      tester,
    ) async {
      final routes = <GoRoute>[
        GoRoute(path: '/profile', builder: dummy, redirect: (_, _) => '/profile/foo'),
        GoRoute(path: '/profile/:kind', builder: dummy),
      ];

      final router = await createRouter(routes, tester);
      router.go('/profile/?bar=baz');
      await tester.pumpAndSettle();
      final matches = router.routerDelegate.currentConfiguration.matches;
      expect(matches, hasLength(1));
      expect(matches.first.matchedLocation, '/profile/foo');
      expect(find.byType(DummyScreen), findsOneWidget);
    });

    testWidgets('match top level route when location has scheme/host and has trailing /', (
      tester,
    ) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
      ];

      final router = await createRouter(routes, tester);
      router.go('https://www.domain.com/?bar=baz');
      await tester.pumpAndSettle();
      final matches = router.routerDelegate.currentConfiguration.matches;
      expect(matches, hasLength(1));
      expect(matches.first.matchedLocation, '/');
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('match top level route when location has scheme/host and has trailing / (2)', (
      tester,
    ) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
      ];

      final router = await createRouter(routes, tester);
      router.go('https://www.domain.com/login/');
      await tester.pumpAndSettle();
      final matches = router.routerDelegate.currentConfiguration.matches;
      expect(matches, hasLength(1));
      expect(matches.first.matchedLocation, '/login');
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('match top level route when location has scheme/host and has trailing / (3)', (
      tester,
    ) async {
      final routes = <GoRoute>[
        GoRoute(path: '/profile', builder: dummy, redirect: (_, _) => '/profile/foo'),
        GoRoute(path: '/profile/:kind', builder: dummy),
      ];

      final router = await createRouter(routes, tester);
      router.go('https://www.domain.com/profile/');
      await tester.pumpAndSettle();
      final matches = router.routerDelegate.currentConfiguration.matches;
      expect(matches, hasLength(1));
      expect(matches.first.matchedLocation, '/profile/foo');
      expect(find.byType(DummyScreen), findsOneWidget);
    });

    testWidgets('match top level route when location has scheme/host and has trailing / (4)', (
      tester,
    ) async {
      final routes = <GoRoute>[
        GoRoute(path: '/profile', builder: dummy, redirect: (_, _) => '/profile/foo'),
        GoRoute(path: '/profile/:kind', builder: dummy),
      ];

      final router = await createRouter(routes, tester);
      router.go('https://www.domain.com/profile/?bar=baz');
      await tester.pumpAndSettle();
      final matches = router.routerDelegate.currentConfiguration.matches;
      expect(matches, hasLength(1));
      expect(matches.first.matchedLocation, '/profile/foo');
      expect(find.byType(DummyScreen), findsOneWidget);
    });

    testWidgets('repeatedly pops imperative route does not crash', (tester) async {
      // Regression test for https://github.com/flutter/flutter/issues/123369.
      final home = UniqueKey();
      final settings = UniqueKey();
      final dialog = UniqueKey();
      final navKey = GlobalKey<NavigatorState>();
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (_, _) => DummyScreen(key: home),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, _) => DummyScreen(key: settings),
        ),
      ];
      final router = await createRouter(routes, tester, navigatorKey: navKey);
      expect(find.byKey(home), findsOneWidget);

      router.push('/settings');
      await tester.pumpAndSettle();
      expect(find.byKey(home), findsNothing);
      expect(find.byKey(settings), findsOneWidget);

      showDialog<void>(
        context: navKey.currentContext!,
        builder: (_) => DummyScreen(key: dialog),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(dialog), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(dialog), findsNothing);
      expect(find.byKey(settings), findsOneWidget);

      showDialog<void>(
        context: navKey.currentContext!,
        builder: (_) => DummyScreen(key: dialog),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(dialog), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(dialog), findsNothing);
      expect(find.byKey(settings), findsOneWidget);
    });

    testWidgets('android back button pop in correct order', (tester) async {
      // Regression test for https://github.com/flutter/flutter/issues/141906.
      final routes = <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, _) => const Text('home'),
          routes: <RouteBase>[
            ShellRoute(
              builder: (context, state, child) {
                return Column(children: <Widget>[const Text('shell'), child]);
              },
              routes: <GoRoute>[
                GoRoute(
                  path: 'page',
                  builder: (context, _) {
                    return TextButton(
                      onPressed: () {
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute<void>(
                            builder: (context) {
                              return const Text('pageless');
                            },
                          ),
                        );
                      },
                      child: const Text('page'),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ];
      final router = await createRouter(routes, tester, initialLocation: '/page');
      expect(find.text('shell'), findsOneWidget);
      expect(find.text('page'), findsOneWidget);

      await tester.tap(find.text('page'));
      await tester.pumpAndSettle();
      expect(find.text('shell'), findsNothing);
      expect(find.text('page'), findsNothing);
      expect(find.text('pageless'), findsOneWidget);

      final result = await router.routerDelegate.popRoute();
      expect(result, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('shell'), findsOneWidget);
      expect(find.text('page'), findsOneWidget);
      expect(find.text('pageless'), findsNothing);
    });

    testWidgets('can correctly pop stacks of repeated pages', (tester) async {
      // Regression test for https://github.com/flutter/flutter/issues/#132229.

      final navKey = GlobalKey<NavigatorState>();
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          pageBuilder: (_, _) => const MaterialPage<Object>(child: HomeScreen()),
        ),
        GoRoute(
          path: '/page1',
          pageBuilder: (_, _) => const MaterialPage<Object>(child: Page1Screen()),
        ),
        GoRoute(
          path: '/page2',
          pageBuilder: (_, _) => const MaterialPage<Object>(child: Page2Screen()),
        ),
      ];
      final router = await createRouter(routes, tester, navigatorKey: navKey);
      expect(find.byType(HomeScreen), findsOneWidget);

      router.push('/page1');
      router.push('/page2');
      router.push('/page1');
      router.push('/page2');
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(Page1Screen), findsNothing);
      expect(find.byType(Page2Screen), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();

      final matches = router.routerDelegate.currentConfiguration.matches;
      expect(matches.length, 4);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(Page1Screen), findsOneWidget);
      expect(find.byType(Page2Screen), findsNothing);
    });

    testWidgets('match sub-route', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'login',
              builder: (context, state) => const LoginScreen(),
            ),
          ],
        ),
      ];

      final router = await createRouter(routes, tester);
      router.go('/login');
      await tester.pumpAndSettle();
      final matches = router.routerDelegate.currentConfiguration.matches;
      expect(matches.length, 2);
      expect(matches.first.matchedLocation, '/');
      expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
      expect(matches[1].matchedLocation, '/login');
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('match sub-routes', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'family/:fid',
              builder: (context, state) => const FamilyScreen('dummy'),
              routes: <GoRoute>[
                GoRoute(
                  path: 'person/:pid',
                  builder: (context, state) => const PersonScreen('dummy', 'dummy'),
                ),
              ],
            ),
            GoRoute(
              path: 'login',
              builder: (context, state) => const LoginScreen(),
            ),
          ],
        ),
      ];

      final router = await createRouter(routes, tester);
      {
        final matches = router.routerDelegate.currentConfiguration;
        expect(matches.matches, hasLength(1));
        expect(matches.uri.toString(), '/');
        expect(find.byType(HomeScreen), findsOneWidget);
      }

      router.go('/login');
      await tester.pumpAndSettle();
      {
        final matches = router.routerDelegate.currentConfiguration;
        expect(matches.matches.length, 2);
        expect(matches.matches.first.matchedLocation, '/');
        expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
        expect(matches.matches[1].matchedLocation, '/login');
        expect(find.byType(LoginScreen), findsOneWidget);
      }

      router.go('/family/f2');
      await tester.pumpAndSettle();
      {
        final matches = router.routerDelegate.currentConfiguration;
        expect(matches.matches.length, 2);
        expect(matches.matches.first.matchedLocation, '/');
        expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
        expect(matches.matches[1].matchedLocation, '/family/f2');
        expect(find.byType(FamilyScreen), findsOneWidget);
      }

      router.go('/family/f2/person/p1');
      await tester.pumpAndSettle();
      {
        final matches = router.routerDelegate.currentConfiguration;
        expect(matches.matches.length, 3);
        expect(matches.matches.first.matchedLocation, '/');
        expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
        expect(matches.matches[1].matchedLocation, '/family/f2');
        expect(find.byType(FamilyScreen, skipOffstage: false), findsOneWidget);
        expect(matches.matches[2].matchedLocation, '/family/f2/person/p1');
        expect(find.byType(PersonScreen), findsOneWidget);
      }
    });

    testWidgets('return first matching route if too many subroutes', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'foo/bar',
              builder: (context, state) => const FamilyScreen(''),
            ),
            GoRoute(
              path: 'bar',
              builder: (context, state) => const Page1Screen(),
            ),
            GoRoute(
              path: 'foo',
              builder: (context, state) => const Page2Screen(),
              routes: <GoRoute>[
                GoRoute(
                  path: 'bar',
                  builder: (context, state) => const LoginScreen(),
                ),
              ],
            ),
          ],
        ),
      ];

      final router = await createRouter(routes, tester);
      router.go('/bar');
      await tester.pumpAndSettle();
      var matches = router.routerDelegate.currentConfiguration.matches;
      expect(matches, hasLength(2));
      expect(find.byType(Page1Screen), findsOneWidget);

      router.go('/foo/bar');
      await tester.pumpAndSettle();
      matches = router.routerDelegate.currentConfiguration.matches;
      expect(matches, hasLength(2));
      expect(find.byType(FamilyScreen), findsOneWidget);

      router.go('/foo');
      await tester.pumpAndSettle();
      matches = router.routerDelegate.currentConfiguration.matches;
      expect(matches, hasLength(2));
      expect(find.byType(Page2Screen), findsOneWidget);
    });

    testWidgets('router state', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          name: 'home',
          path: '/',
          builder: (context, state) {
            expect(state.uri.toString(), '/');
            expect(state.matchedLocation, '/');
            expect(state.name, 'home');
            expect(state.path, '/');
            expect(state.fullPath, '/');
            expect(state.pathParameters, <String, String>{});
            expect(state.error, null);
            if (state.extra != null) {
              expect(state.extra! as int, 1);
            }
            return const HomeScreen();
          },
          routes: <GoRoute>[
            GoRoute(
              name: 'login',
              path: 'login',
              builder: (context, state) {
                expect(state.uri.toString(), '/login');
                expect(state.matchedLocation, '/login');
                expect(state.name, 'login');
                expect(state.path, 'login');
                expect(state.fullPath, '/login');
                expect(state.pathParameters, <String, String>{});
                expect(state.error, null);
                expect(state.extra! as int, 2);
                return const LoginScreen();
              },
            ),
            GoRoute(
              name: 'family',
              path: 'family/:fid',
              builder: (context, state) {
                expect(state.uri.toString(), anyOf(<String>['/family/f2', '/family/f2/person/p1']));
                expect(state.matchedLocation, '/family/f2');
                expect(state.name, 'family');
                expect(state.path, 'family/:fid');
                expect(state.fullPath, '/family/:fid');
                expect(state.pathParameters, <String, String>{'fid': 'f2'});
                expect(state.error, null);
                expect(state.extra! as int, 3);
                return FamilyScreen(state.pathParameters['fid']!);
              },
              routes: <GoRoute>[
                GoRoute(
                  name: 'person',
                  path: 'person/:pid',
                  builder: (context, state) {
                    expect(state.uri.toString(), '/family/f2/person/p1');
                    expect(state.matchedLocation, '/family/f2/person/p1');
                    expect(state.name, 'person');
                    expect(state.path, 'person/:pid');
                    expect(state.fullPath, '/family/:fid/person/:pid');
                    expect(state.pathParameters, <String, String>{'fid': 'f2', 'pid': 'p1'});
                    expect(state.error, null);
                    expect(state.extra! as int, 4);
                    return PersonScreen(state.pathParameters['fid']!, state.pathParameters['pid']!);
                  },
                ),
              ],
            ),
          ],
        ),
      ];

      final router = await createRouter(routes, tester);
      router.go('/', extra: 1);
      await tester.pump();
      router.push('/login', extra: 2);
      await tester.pump();
      router.push('/family/f2', extra: 3);
      await tester.pump();
      router.push('/family/f2/person/p1', extra: 4);
      await tester.pump();
    });

    testWidgets('match path case insensitively', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/family/:fid',
          caseSensitive: false,
          builder: (context, state) => FamilyScreen(state.pathParameters['fid']!),
        ),
      ];

      final router = await createRouter(routes, tester);
      const loc = '/FaMiLy/f2';
      router.go(loc);
      await tester.pumpAndSettle();
      final matches = router.routerDelegate.currentConfiguration.matches;

      // NOTE: match the lower case, since location is canonicalized to match the
      // path case whereas the location can be any case; so long as the path
      // produces a match regardless of the location case, we win!
      expect(
        router.routerDelegate.currentConfiguration.uri.toString().toLowerCase(),
        loc.toLowerCase(),
      );

      expect(matches, hasLength(1));
      expect(find.byType(FamilyScreen), findsOneWidget);
    });

    testWidgets('match path case sensitively', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/family/:fid',
          builder: (context, state) => FamilyScreen(state.pathParameters['fid']!),
        ),
      ];

      final router = await createRouter(routes, tester);
      const wrongLoc = '/FaMiLy/f2';

      router.go(wrongLoc);
      await tester.pumpAndSettle();

      expect(find.byType(MaterialErrorScreen), findsOne);
      expect(find.text('Page Not Found'), findsOne);

      const loc = '/family/f2';
      router.go(loc);
      await tester.pumpAndSettle();
      final matches = router.routerDelegate.currentConfiguration.matches;

      expect(router.routerDelegate.currentConfiguration.uri.toString(), loc);

      expect(matches, hasLength(1));
      expect(find.byType(FamilyScreen), findsOne);
    });

    testWidgets('supports routes with a different case', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/abc',
          builder: (context, state) => const SizedBox(key: Key('abc')),
        ),
        GoRoute(
          path: '/ABC',
          builder: (context, state) => const SizedBox(key: Key('ABC')),
        ),
      ];

      final router = await createRouter(routes, tester);
      const loc1 = '/abc';

      router.go(loc1);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('abc')), findsOne);

      const loc = '/ABC';
      router.go(loc);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ABC')), findsOne);
    });

    testWidgets('If there is more than one route to match, use the first match.', (
      tester,
    ) async {
      final routes = <GoRoute>[
        GoRoute(path: '/', builder: dummy),
        GoRoute(path: '/page1', builder: dummy),
        GoRoute(path: '/page1', builder: dummy),
        GoRoute(path: '/:ok', builder: dummy),
      ];

      final router = await createRouter(routes, tester);
      router.go('/user');
      await tester.pumpAndSettle();
      final matches = router.routerDelegate.currentConfiguration.matches;
      expect(matches, hasLength(1));
      expect(find.byType(DummyScreen), findsOneWidget);
    });

    testWidgets('Handles the Android back button correctly', (tester) async {
      final routes = <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) {
            return const Scaffold(body: Text('Screen A'));
          },
          routes: <RouteBase>[
            GoRoute(
              path: 'b',
              builder: (context, state) {
                return const Scaffold(body: Text('Screen B'));
              },
            ),
          ],
        ),
      ];

      await createRouter(routes, tester, initialLocation: '/b');
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen B'), findsOneWidget);

      await simulateAndroidBackButton(tester);
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsOneWidget);
      expect(find.text('Screen B'), findsNothing);
    });

    testWidgets('Handles the Android back button correctly with ShellRoute', (
      tester,
    ) async {
      final rootNavigatorKey = GlobalKey<NavigatorState>();

      final routes = <RouteBase>[
        ShellRoute(
          builder: (context, state, child) {
            return Scaffold(
              appBar: AppBar(title: const Text('Shell')),
              body: child,
            );
          },
          routes: <GoRoute>[
            GoRoute(
              path: '/a',
              builder: (context, state) {
                return const Scaffold(body: Text('Screen A'));
              },
              routes: <GoRoute>[
                GoRoute(
                  path: 'b',
                  builder: (context, state) {
                    return const Scaffold(body: Text('Screen B'));
                  },
                  routes: <GoRoute>[
                    GoRoute(
                      path: 'c',
                      builder: (context, state) {
                        return const Scaffold(body: Text('Screen C'));
                      },
                      routes: <GoRoute>[
                        GoRoute(
                          path: 'd',
                          parentNavigatorKey: rootNavigatorKey,
                          builder: (context, state) {
                            return const Scaffold(body: Text('Screen D'));
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ];

      await createRouter(
        routes,
        tester,
        initialLocation: '/a/b/c/d',
        navigatorKey: rootNavigatorKey,
      );
      expect(find.text('Shell'), findsNothing);
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen B'), findsNothing);
      expect(find.text('Screen C'), findsNothing);
      expect(find.text('Screen D'), findsOneWidget);

      await simulateAndroidBackButton(tester);
      await tester.pumpAndSettle();
      expect(find.text('Shell'), findsOneWidget);
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen B'), findsNothing);
      expect(find.text('Screen C'), findsOneWidget);
      expect(find.text('Screen D'), findsNothing);

      await simulateAndroidBackButton(tester);
      await tester.pumpAndSettle();
      expect(find.text('Shell'), findsOneWidget);
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen B'), findsOneWidget);
      expect(find.text('Screen C'), findsNothing);
    });

    testWidgets(
      'Handles the Android back button when parentNavigatorKey is set to the root navigator',
      (tester) async {
        final log = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (methodCall) async {
            log.add(methodCall);
            return null;
          },
        );

        Future<void> verify(AsyncCallback test, List<Object> expectations) async {
          log.clear();
          await test();
          expect(log, expectations);
        }

        final rootNavigatorKey = GlobalKey<NavigatorState>();

        final routes = <RouteBase>[
          GoRoute(
            parentNavigatorKey: rootNavigatorKey,
            path: '/a',
            builder: (context, state) {
              return const Scaffold(body: Text('Screen A'));
            },
          ),
        ];

        await createRouter(routes, tester, initialLocation: '/a', navigatorKey: rootNavigatorKey);
        expect(find.text('Screen A'), findsOneWidget);

        await tester.runAsync(() async {
          await verify(() => simulateAndroidBackButton(tester), <Object>[
            isMethodCall('SystemNavigator.pop', arguments: null),
          ]);
        });
      },
    );

    testWidgets("Handles the Android back button when ShellRoute can't pop", (
      tester,
    ) async {
      final log = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (methodCall) async {
          log.add(methodCall);
          return null;
        },
      );

      Future<void> verify(AsyncCallback test, List<Object> expectations) async {
        log.clear();
        await test();
        expect(log, expectations);
      }

      final rootNavigatorKey = GlobalKey<NavigatorState>();

      final routes = <RouteBase>[
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/a',
          builder: (context, state) {
            return const Scaffold(body: Text('Screen A'));
          },
        ),
        ShellRoute(
          builder: (context, state, child) {
            return Scaffold(
              appBar: AppBar(title: const Text('Shell')),
              body: child,
            );
          },
          routes: <RouteBase>[
            GoRoute(
              path: '/b',
              builder: (context, state) {
                return const Scaffold(body: Text('Screen B'));
              },
            ),
          ],
        ),
      ];

      await createRouter(routes, tester, initialLocation: '/b', navigatorKey: rootNavigatorKey);
      expect(find.text('Screen B'), findsOneWidget);

      await tester.runAsync(() async {
        await verify(() => simulateAndroidBackButton(tester), <Object>[
          isMethodCall('SystemNavigator.pop', arguments: null),
        ]);
      });
    });
  });

  testWidgets('does not crash when inherited widget changes', (tester) async {
    final notifier = ValueNotifier<String>('initial');

    addTearDown(notifier.dispose);
    final routes = <GoRoute>[
      GoRoute(
        path: '/',
        pageBuilder: (context, state) {
          final value = context
              .dependOnInheritedWidgetOfExactType<TestInheritedNotifier>()!
              .notifier!
              .value;
          return MaterialPage<void>(key: state.pageKey, child: Text(value));
        },
      ),
    ];
    final router = GoRouter(routes: routes);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        builder: (context, child) {
          return TestInheritedNotifier(notifier: notifier, child: child!);
        },
      ),
    );

    expect(find.text(notifier.value), findsOneWidget);
    notifier.value = 'updated';
    await tester.pump();
    expect(find.text(notifier.value), findsOneWidget);
  });

  testWidgets(
    'Handles the Android back button when a second Shell has a GoRoute with parentNavigator key',
    (tester) async {
      final log = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (methodCall) async {
          log.add(methodCall);
          return null;
        },
      );

      Future<void> verify(AsyncCallback test, List<Object> expectations) async {
        log.clear();
        await test();
        expect(log, expectations);
      }

      final rootNavigatorKey = GlobalKey<NavigatorState>();
      final shellNavigatorKeyA = GlobalKey<NavigatorState>();
      final shellNavigatorKeyB = GlobalKey<NavigatorState>();

      final routes = <RouteBase>[
        ShellRoute(
          navigatorKey: shellNavigatorKeyA,
          builder: (context, state, child) {
            return Scaffold(
              appBar: AppBar(title: const Text('Shell')),
              body: child,
            );
          },
          routes: <RouteBase>[
            GoRoute(
              path: '/a',
              builder: (context, state) {
                return const Scaffold(body: Text('Screen A'));
              },
              routes: <RouteBase>[
                ShellRoute(
                  navigatorKey: shellNavigatorKeyB,
                  builder: (context, state, child) {
                    return Scaffold(
                      appBar: AppBar(title: const Text('Shell')),
                      body: child,
                    );
                  },
                  routes: <RouteBase>[
                    GoRoute(
                      path: 'b',
                      parentNavigatorKey: shellNavigatorKeyB,
                      builder: (context, state) {
                        return const Scaffold(body: Text('Screen B'));
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ];

      await createRouter(routes, tester, initialLocation: '/a/b', navigatorKey: rootNavigatorKey);
      expect(find.text('Screen B'), findsOneWidget);

      // The first pop should not exit the app.
      await tester.runAsync(() async {
        await verify(() => simulateAndroidBackButton(tester), <Object>[]);
      });

      // Pump one frame between back buttons to allow any PopScope widgets to
      // rebuild.
      await tester.pump();

      // The second pop should exit the app.
      await tester.runAsync(() async {
        await verify(() => simulateAndroidBackButton(tester), <Object>[
          isMethodCall('SystemNavigator.pop', arguments: null),
        ]);
      });
    },
  );

  group('report correct url', () {
    final log = <MethodCall>[];
    setUp(() {
      GoRouter.optionURLReflectsImperativeAPIs = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.navigation,
        (methodCall) async {
          log.add(methodCall);
          return null;
        },
      );
    });
    tearDown(() {
      GoRouter.optionURLReflectsImperativeAPIs = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.navigation,
        null,
      );
      log.clear();
    });

    testWidgets('on push shell route with optionURLReflectImperativeAPIs = true', (
      tester,
    ) async {
      GoRouter.optionURLReflectsImperativeAPIs = true;
      final routes = <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) => const DummyScreen(),
          routes: <RouteBase>[
            ShellRoute(
              builder: (context, state, child) => child,
              routes: <RouteBase>[
                GoRoute(
                  path: 'c',
                  builder: (context, state) => const DummyScreen(),
                ),
              ],
            ),
          ],
        ),
      ];

      final router = await createRouter(routes, tester);

      log.clear();
      router.push('/c?foo=bar');
      final codec = RouteMatchListCodec(router.configuration);
      await tester.pumpAndSettle();
      expect(log, <Object>[
        isMethodCall('selectMultiEntryHistory', arguments: null),
        IsRouteUpdateCall(
          '/c?foo=bar',
          false,
          codec.encode(router.routerDelegate.currentConfiguration),
        ),
      ]);
      GoRouter.optionURLReflectsImperativeAPIs = false;
    });

    testWidgets('on push with optionURLReflectImperativeAPIs = true', (tester) async {
      GoRouter.optionURLReflectsImperativeAPIs = true;
      final routes = <GoRoute>[
        GoRoute(path: '/', builder: (_, _) => const DummyScreen()),
        GoRoute(path: '/settings', builder: (_, _) => const DummyScreen()),
      ];

      final router = await createRouter(routes, tester);

      log.clear();
      router.push('/settings');
      final codec = RouteMatchListCodec(router.configuration);
      await tester.pumpAndSettle();
      expect(log, <Object>[
        isMethodCall('selectMultiEntryHistory', arguments: null),
        IsRouteUpdateCall(
          '/settings',
          false,
          codec.encode(router.routerDelegate.currentConfiguration),
        ),
      ]);
      GoRouter.optionURLReflectsImperativeAPIs = false;
    });

    testWidgets('on push', (tester) async {
      final routes = <GoRoute>[
        GoRoute(path: '/', builder: (_, _) => const DummyScreen()),
        GoRoute(path: '/settings', builder: (_, _) => const DummyScreen()),
      ];

      final router = await createRouter(routes, tester);

      log.clear();
      router.push('/settings');
      final codec = RouteMatchListCodec(router.configuration);
      await tester.pumpAndSettle();
      expect(log, <Object>[
        isMethodCall('selectMultiEntryHistory', arguments: null),
        IsRouteUpdateCall('/', false, codec.encode(router.routerDelegate.currentConfiguration)),
      ]);
    });

    testWidgets('on pop', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (_, _) => const DummyScreen(),
          routes: <RouteBase>[GoRoute(path: 'settings', builder: (_, _) => const DummyScreen())],
        ),
      ];

      final router = await createRouter(routes, tester, initialLocation: '/settings');
      final codec = RouteMatchListCodec(router.configuration);
      log.clear();
      router.pop();
      await tester.pumpAndSettle();
      expect(log, <Object>[
        isMethodCall('selectMultiEntryHistory', arguments: null),
        IsRouteUpdateCall('/', false, codec.encode(router.routerDelegate.currentConfiguration)),
      ]);
    });

    testWidgets('on pop twice', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (_, _) => const DummyScreen(),
          routes: <RouteBase>[
            GoRoute(
              path: 'settings',
              builder: (_, _) => const DummyScreen(),
              routes: <RouteBase>[GoRoute(path: 'profile', builder: (_, _) => const DummyScreen())],
            ),
          ],
        ),
      ];

      final router = await createRouter(
        routes,
        tester,
        initialLocation: '/settings/profile',
      );
      final codec = RouteMatchListCodec(router.configuration);
      log.clear();
      router.pop();
      router.pop();
      await tester.pumpAndSettle();
      expect(log, <Object>[
        isMethodCall('selectMultiEntryHistory', arguments: null),
        IsRouteUpdateCall('/', false, codec.encode(router.routerDelegate.currentConfiguration)),
      ]);
    });

    testWidgets('on pop with path parameters', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (_, _) => const DummyScreen(),
          routes: <RouteBase>[
            GoRoute(path: 'settings/:id', builder: (_, _) => const DummyScreen()),
          ],
        ),
      ];

      final router = await createRouter(routes, tester, initialLocation: '/settings/123');
      final codec = RouteMatchListCodec(router.configuration);
      log.clear();
      router.pop();
      await tester.pumpAndSettle();
      expect(log, <Object>[
        isMethodCall('selectMultiEntryHistory', arguments: null),
        IsRouteUpdateCall('/', false, codec.encode(router.routerDelegate.currentConfiguration)),
      ]);
    });

    testWidgets('on pop with path parameters case 2', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (_, _) => const DummyScreen(),
          routes: <RouteBase>[GoRoute(path: ':id', builder: (_, _) => const DummyScreen())],
        ),
      ];

      final router = await createRouter(routes, tester, initialLocation: '/123/');
      final codec = RouteMatchListCodec(router.configuration);
      log.clear();
      router.pop();
      await tester.pumpAndSettle();
      expect(log, <Object>[
        isMethodCall('selectMultiEntryHistory', arguments: null),
        IsRouteUpdateCall('/', false, codec.encode(router.routerDelegate.currentConfiguration)),
      ]);
    });

    testWidgets('Can manually pop root navigator and display correct url', (
      tester,
    ) async {
      final rootNavigatorKey = GlobalKey<NavigatorState>();

      final routes = <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) {
            return const Scaffold(body: Text('Home'));
          },
          routes: <RouteBase>[
            ShellRoute(
              builder: (context, state, child) {
                return Scaffold(appBar: AppBar(), body: child);
              },
              routes: <RouteBase>[
                GoRoute(
                  path: 'b',
                  builder: (context, state) {
                    return const Scaffold(body: Text('Screen B'));
                  },
                  routes: <RouteBase>[
                    GoRoute(
                      path: 'c',
                      builder: (context, state) {
                        return const Scaffold(body: Text('Screen C'));
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ];

      final router = await createRouter(
        routes,
        tester,
        initialLocation: '/b/c',
        navigatorKey: rootNavigatorKey,
      );
      final codec = RouteMatchListCodec(router.configuration);
      expect(find.text('Screen C'), findsOneWidget);
      expect(log, <Object>[
        isMethodCall('selectMultiEntryHistory', arguments: null),
        IsRouteUpdateCall('/b/c', true, codec.encode(router.routerDelegate.currentConfiguration)),
      ]);

      log.clear();
      rootNavigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(log, <Object>[
        isMethodCall('selectMultiEntryHistory', arguments: null),
        IsRouteUpdateCall('/', false, codec.encode(router.routerDelegate.currentConfiguration)),
      ]);
    });

    testWidgets('can handle route information update from browser', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (_, _) => const DummyScreen(key: ValueKey<String>('home')),
          routes: <RouteBase>[
            GoRoute(
              path: 'settings',
              builder: (_, state) => DummyScreen(key: ValueKey<String>('settings-${state.extra}')),
            ),
          ],
        ),
      ];

      final router = await createRouter(routes, tester);
      expect(find.byKey(const ValueKey<String>('home')), findsOneWidget);

      router.push('/settings', extra: 0);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('settings-0')), findsOneWidget);

      log.clear();
      router.push('/settings', extra: 1);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('settings-1')), findsOneWidget);

      final arguments = log.last.arguments as Map<Object?, Object?>;
      // Stores the state after the last push. This should contain the encoded
      // RouteMatchList.
      final state = (log.last.arguments as Map<Object?, Object?>)['state'];
      final location = (arguments['location'] ?? arguments['uri']!) as String;

      router.go('/');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('home')), findsOneWidget);

      router.routeInformationProvider.didPushRouteInformation(
        RouteInformation(uri: Uri.parse(location), state: state),
      );
      await tester.pumpAndSettle();
      // Make sure it has all the imperative routes.
      expect(find.byKey(const ValueKey<String>('settings-1')), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('settings-0')), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('home')), findsOneWidget);
    });

    testWidgets('works correctly with async redirect', (tester) async {
      final login = UniqueKey();
      final routes = <GoRoute>[
        GoRoute(path: '/', builder: (_, _) => const DummyScreen()),
        GoRoute(
          path: '/login',
          builder: (_, _) => DummyScreen(key: login),
        ),
      ];
      final completer = Completer<void>();
      final router = await createRouter(
        routes,
        tester,
        redirect: (_, _) async {
          await completer.future;
          return '/login';
        },
      );
      final codec = RouteMatchListCodec(router.configuration);
      await tester.pumpAndSettle();
      expect(find.byKey(login), findsNothing);
      expect(tester.takeException(), isNull);
      expect(log, <Object>[]);

      completer.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(login), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(log, <Object>[
        isMethodCall('selectMultiEntryHistory', arguments: null),
        IsRouteUpdateCall('/login', true, codec.encode(router.routerDelegate.currentConfiguration)),
      ]);
    });
  });

  group('named routes', () {
    testWidgets('match home route', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          name: 'home',
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
      ];

      final router = await createRouter(routes, tester);
      router.goNamed('home');
    });

    testWidgets('match too many routes', (tester) async {
      final routes = <GoRoute>[
        GoRoute(name: 'home', path: '/', builder: dummy),
        GoRoute(name: 'home', path: '/', builder: dummy),
      ];

      await expectLater(() async {
        await createRouter(routes, tester);
      }, throwsA(isAssertionError));
    });

    test('empty name', () {
      expect(() {
        GoRoute(name: '', path: '/');
      }, throwsA(isAssertionError));
    });

    testWidgets('match no routes', (tester) async {
      await expectLater(() async {
        final routes = <GoRoute>[GoRoute(name: 'home', path: '/', builder: dummy)];
        final router = await createRouter(routes, tester);
        router.goNamed('work');
      }, throwsA(isAssertionError));
    });

    testWidgets('match 2nd top level route', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          name: 'home',
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          name: 'login',
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
      ];

      final router = await createRouter(routes, tester);
      router.goNamed('login');
    });

    testWidgets('match sub-route', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          name: 'home',
          path: '/',
          builder: (context, state) => const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              name: 'login',
              path: 'login',
              builder: (context, state) => const LoginScreen(),
            ),
          ],
        ),
      ];

      final router = await createRouter(routes, tester);
      router.goNamed('login');
    });

    testWidgets('match w/ params', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          name: 'home',
          path: '/',
          builder: (context, state) => const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              name: 'family',
              path: 'family/:fid',
              builder: (context, state) => const FamilyScreen('dummy'),
              routes: <GoRoute>[
                GoRoute(
                  name: 'person',
                  path: 'person/:pid',
                  builder: (context, state) {
                    expect(state.pathParameters, <String, String>{'fid': 'f2', 'pid': 'p1'});
                    return const PersonScreen('dummy', 'dummy');
                  },
                ),
              ],
            ),
          ],
        ),
      ];

      final router = await createRouter(routes, tester);
      router.goNamed('person', pathParameters: <String, String>{'fid': 'f2', 'pid': 'p1'});
    });

    testWidgets('too few params', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          name: 'home',
          path: '/',
          builder: (context, state) => const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              name: 'family',
              path: 'family/:fid',
              builder: (context, state) => const FamilyScreen('dummy'),
              routes: <GoRoute>[
                GoRoute(
                  name: 'person',
                  path: 'person/:pid',
                  builder: (context, state) => const PersonScreen('dummy', 'dummy'),
                ),
              ],
            ),
          ],
        ),
      ];
      await expectLater(() async {
        final router = await createRouter(routes, tester);
        router.goNamed('person', pathParameters: <String, String>{'fid': 'f2'});
        await tester.pump();
      }, throwsA(isAssertionError));
    });

    testWidgets('cannot match case insensitive', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          name: 'home',
          path: '/',
          builder: (context, state) => const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              name: 'family',
              path: 'family/:fid',
              builder: (context, state) => const FamilyScreen('dummy'),
              routes: <GoRoute>[
                GoRoute(
                  name: 'PeRsOn',
                  path: 'person/:pid',
                  builder: (context, state) {
                    expect(state.pathParameters, <String, String>{'fid': 'f2', 'pid': 'p1'});
                    return const PersonScreen('dummy', 'dummy');
                  },
                ),
              ],
            ),
          ],
        ),
      ];

      final router = await createRouter(routes, tester);
      expect(() {
        router.goNamed('person', pathParameters: <String, String>{'fid': 'f2', 'pid': 'p1'});
      }, throwsAssertionError);
    });

    testWidgets('too few params', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          name: 'family',
          path: '/family/:fid',
          builder: (context, state) => const FamilyScreen('dummy'),
        ),
      ];
      await expectLater(() async {
        final router = await createRouter(routes, tester);
        router.goNamed('family');
      }, throwsA(isAssertionError));
    });

    testWidgets('too many params', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          name: 'family',
          path: '/family/:fid',
          builder: (context, state) => const FamilyScreen('dummy'),
        ),
      ];
      await expectLater(() async {
        final router = await createRouter(routes, tester);
        router.goNamed('family', pathParameters: <String, String>{'fid': 'f2', 'pid': 'p1'});
      }, throwsA(isAssertionError));
    });

    testWidgets('sparsely named routes', (tester) async {
      final routes = <GoRoute>[
        GoRoute(path: '/', builder: dummy, redirect: (_, _) => '/family/f2'),
        GoRoute(
          path: '/family/:fid',
          builder: (context, state) => FamilyScreen(state.pathParameters['fid']!),
          routes: <GoRoute>[
            GoRoute(
              name: 'person',
              path: 'person:pid',
              builder: (context, state) =>
                  PersonScreen(state.pathParameters['fid']!, state.pathParameters['pid']!),
            ),
          ],
        ),
      ];

      final router = await createRouter(routes, tester);
      router.goNamed('person', pathParameters: <String, String>{'fid': 'f2', 'pid': 'p1'});
      await tester.pumpAndSettle();
      expect(find.byType(PersonScreen), findsOneWidget);
    });

    testWidgets('preserve path param spaces and slashes', (tester) async {
      const param1 = 'param w/ spaces and slashes';
      final routes = <GoRoute>[
        GoRoute(
          name: 'page1',
          path: '/page1/:param1',
          builder: (c, s) {
            expect(s.pathParameters['param1'], param1);
            return const DummyScreen();
          },
        ),
      ];

      final router = await createRouter(routes, tester);
      final loc = router.namedLocation(
        'page1',
        pathParameters: <String, String>{'param1': param1},
      );
      router.go(loc);
      await tester.pumpAndSettle();

      final matches = router.routerDelegate.currentConfiguration;
      expect(find.byType(DummyScreen), findsOneWidget);
      expect(matches.pathParameters['param1'], param1);
    });

    testWidgets('preserve query param spaces and slashes', (tester) async {
      const param1 = 'param w/ spaces and slashes';
      final routes = <GoRoute>[
        GoRoute(
          name: 'page1',
          path: '/page1',
          builder: (c, s) {
            expect(s.uri.queryParameters['param1'], param1);
            return const DummyScreen();
          },
        ),
      ];

      final router = await createRouter(routes, tester);
      final loc = router.namedLocation(
        'page1',
        queryParameters: <String, String>{'param1': param1},
      );
      router.go(loc);
      await tester.pumpAndSettle();
      final matches = router.routerDelegate.currentConfiguration;
      expect(find.byType(DummyScreen), findsOneWidget);
      expect(matches.uri.queryParameters['param1'], param1);
    });
  });

  group('go relative', () {
    testWidgets('from default route', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'login',
              builder: (context, state) => const LoginScreen(),
            ),
          ],
        ),
      ];

      final router = await createRouter(routes, tester);
      router.go('./login');
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('from non-default route', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'login',
              builder: (context, state) => const LoginScreen(),
            ),
          ],
        ),
      ];

      final router = await createRouter(routes, tester);
      router.go('/home');
      router.go('./login');
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('match w/ path params', (tester) async {
      const fid = 'f2';
      const pid = 'p1';

      final routes = <GoRoute>[
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'family/:fid',
              builder: (context, state) => const FamilyScreen('dummy'),
              routes: <GoRoute>[
                GoRoute(
                  name: 'person',
                  path: 'person/:pid',
                  builder: (context, state) {
                    expect(state.pathParameters, <String, String>{'fid': fid, 'pid': pid});
                    return const PersonScreen('dummy', 'dummy');
                  },
                ),
              ],
            ),
          ],
        ),
      ];

      final router = await createRouter(routes, tester, initialLocation: '/home');

      router.go('./family/$fid');
      await tester.pumpAndSettle();
      expect(find.byType(FamilyScreen), findsOneWidget);

      router.go('./person/$pid');
      await tester.pumpAndSettle();
      expect(find.byType(PersonScreen), findsOneWidget);
    });

    testWidgets('match w/ query params', (tester) async {
      const fid = 'f2';
      const pid = 'p1';

      final routes = <GoRoute>[
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'family',
              builder: (context, state) => const FamilyScreen('dummy'),
              routes: <GoRoute>[
                GoRoute(
                  path: 'person',
                  builder: (context, state) {
                    expect(state.uri.queryParameters, <String, String>{'pid': pid});
                    return const PersonScreen('dummy', 'dummy');
                  },
                ),
              ],
            ),
          ],
        ),
      ];

      final router = await createRouter(routes, tester, initialLocation: '/home');

      router.go('./family?fid=$fid');
      await tester.pumpAndSettle();
      expect(find.byType(FamilyScreen), findsOneWidget);

      router.go('./person?pid=$pid');
      await tester.pumpAndSettle();
      expect(find.byType(PersonScreen), findsOneWidget);
    });

    testWidgets('too few params', (tester) async {
      const pid = 'p1';

      final routes = <GoRoute>[
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'family/:fid',
              builder: (context, state) => const FamilyScreen('dummy'),
              routes: <GoRoute>[
                GoRoute(
                  path: 'person/:pid',
                  builder: (context, state) => const PersonScreen('dummy', 'dummy'),
                ),
              ],
            ),
          ],
        ),
      ];
      // await expectLater(() async {
      final router = await createRouter(
        routes,
        tester,
        initialLocation: '/home',
        errorBuilder: (context, state) => TestErrorScreen(state.error!),
      );
      router.go('./family/person/$pid');
      await tester.pumpAndSettle();
      expect(find.byType(TestErrorScreen), findsOneWidget);

      final matches = router.routerDelegate.currentConfiguration.matches;
      expect(matches, hasLength(0));
    });

    testWidgets('match no route', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'family',
              builder: (context, state) => const FamilyScreen('dummy'),
              routes: <GoRoute>[
                GoRoute(
                  path: 'person',
                  builder: (context, state) => const PersonScreen('dummy', 'dummy'),
                ),
              ],
            ),
          ],
        ),
      ];

      final router = await createRouter(
        routes,
        tester,
        initialLocation: '/home',
        errorBuilder: (context, state) => TestErrorScreen(state.error!),
      );
      router.go('person');

      await tester.pumpAndSettle();
      expect(find.byType(TestErrorScreen), findsOneWidget);

      final matches = router.routerDelegate.currentConfiguration.matches;
      expect(matches, hasLength(0));
    });

    testWidgets('preserve path param spaces and slashes', (tester) async {
      const param1 = 'param w/ spaces and slashes';
      final routes = <GoRoute>[
        GoRoute(
          path: '/home',
          builder: dummy,
          routes: <RouteBase>[
            GoRoute(
              path: 'page1/:param1',
              builder: (c, s) {
                expect(s.pathParameters['param1'], param1);
                return const DummyScreen();
              },
            ),
          ],
        ),
      ];

      final router = await createRouter(routes, tester, initialLocation: '/home');
      final loc = 'page1/${Uri.encodeComponent(param1)}';
      router.go('./$loc');

      await tester.pumpAndSettle();
      expect(find.byType(DummyScreen), findsOneWidget);

      final matches = router.routerDelegate.currentConfiguration;
      expect(matches.pathParameters['param1'], param1);
    });

    testWidgets('preserve query param spaces and slashes', (tester) async {
      const param1 = 'param w/ spaces and slashes';
      final routes = <GoRoute>[
        GoRoute(
          path: '/home',
          builder: dummy,
          routes: <RouteBase>[
            GoRoute(
              path: 'page1',
              builder: (c, s) {
                expect(s.uri.queryParameters['param1'], param1);
                return const DummyScreen();
              },
            ),
          ],
        ),
      ];

      final router = await createRouter(routes, tester, initialLocation: '/home');

      final loc = Uri(
        path: 'page1',
        queryParameters: <String, dynamic>{'param1': param1},
      ).toString();
      router.go('./$loc');

      await tester.pumpAndSettle();
      expect(find.byType(DummyScreen), findsOneWidget);

      final matches = router.routerDelegate.currentConfiguration;
      expect(matches.uri.queryParameters['param1'], param1);
    });
  });

  group('redirects', () {
    testWidgets('top-level redirect', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'dummy',
              builder: (context, state) => const DummyScreen(),
            ),
            GoRoute(
              path: 'login',
              builder: (context, state) => const LoginScreen(),
            ),
          ],
        ),
      ];
      var redirected = false;

      final router = await createRouter(
        routes,
        tester,
        redirect: (context, state) {
          redirected = true;
          return state.matchedLocation == '/login' ? null : '/login';
        },
      );

      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/login');
      expect(redirected, isTrue);

      redirected = false;
      // Directly set the url through platform message.
      await sendPlatformUrl('/dummy', tester);

      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/login');
      expect(redirected, isTrue);
    });

    testWidgets('error thrown during redirect can be caught by onException', (
      tester,
    ) async {
      var exceptionCaught = false;
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/trigger-error',
          builder: (context, state) => const Text('should not reach here'),
        ),
      ];

      final router = await createRouter(
        routes,
        tester,
        redirect: (context, state) {
          if (state.matchedLocation == '/trigger-error') {
            throw Exception('Redirect error');
          }
          return null;
        },
        onException: (context, state, router) {
          exceptionCaught = true;
        },
      );

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(exceptionCaught, isFalse);

      // Navigate to a route that will trigger an error in the redirect callback
      router.go('/trigger-error');
      await tester.pumpAndSettle();

      // Verify the exception was caught
      expect(exceptionCaught, isTrue);
      // Should stay on the home screen since onException didn't navigate anywhere
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('should not reach here'), findsNothing);
    });

    testWidgets('context extension methods work in redirects', (tester) async {
      String? capturedNamedLocation;
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),
      ];

      await createRouter(
        routes,
        tester,
        redirect: (context, state) {
          capturedNamedLocation = context.namedLocation('login');
          return state.matchedLocation == '/login' ? null : '/login';
        },
      );

      expect(capturedNamedLocation, '/login');
    });

    testWidgets('redirect can redirect to same path', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'dummy',
              // Return same location.
              redirect: (_, state) => state.uri.toString(),
              builder: (context, state) => const DummyScreen(),
            ),
          ],
        ),
      ];

      final router = await createRouter(
        routes,
        tester,
        redirect: (context, state) {
          // Return same location.
          return state.uri.toString();
        },
      );

      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/');
      // Directly set the url through platform message.
      await sendPlatformUrl('/dummy', tester);
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/dummy');
    });

    testWidgets('top-level redirect w/ named routes', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          name: 'home',
          path: '/',
          builder: (context, state) => const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              name: 'dummy',
              path: 'dummy',
              builder: (context, state) => const DummyScreen(),
            ),
            GoRoute(
              name: 'login',
              path: 'login',
              builder: (context, state) => const LoginScreen(),
            ),
          ],
        ),
      ];

      final router = await createRouter(
        routes,
        tester,
        redirect: (context, state) =>
            state.matchedLocation == '/login' ? null : state.namedLocation('login'),
      );
      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/login');
    });

    testWidgets('route-level redirect', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'dummy',
              builder: (context, state) => const DummyScreen(),
              redirect: (context, state) => '/login',
            ),
            GoRoute(
              path: 'login',
              builder: (context, state) => const LoginScreen(),
            ),
          ],
        ),
      ];

      final router = await createRouter(routes, tester);
      router.go('/dummy');
      await tester.pump();
      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/login');
    });

    testWidgets('top-level redirect take priority over route level', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'dummy',
              builder: (context, state) => const DummyScreen(),
              redirect: (context, state) {
                // should never be reached.
                assert(false, 'The unexpected redirect callback was invoked.');
                return '/dummy2';
              },
            ),
            GoRoute(
              path: 'dummy2',
              builder: (context, state) => const DummyScreen(),
            ),
            GoRoute(
              path: 'login',
              builder: (context, state) => const LoginScreen(),
            ),
          ],
        ),
      ];
      var redirected = false;
      final router = await createRouter(
        routes,
        tester,
        redirect: (context, state) {
          redirected = true;
          return state.matchedLocation == '/login' ? null : '/login';
        },
      );
      redirected = false;
      // Directly set the url through platform message.
      await sendPlatformUrl('/dummy', tester);

      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/login');
      expect(redirected, isTrue);
    });

    testWidgets('route-level redirect w/ named routes', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          name: 'home',
          path: '/',
          builder: (context, state) => const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              name: 'dummy',
              path: 'dummy',
              builder: (context, state) => const DummyScreen(),
              redirect: (context, state) => state.namedLocation('login'),
            ),
            GoRoute(
              name: 'login',
              path: 'login',
              builder: (context, state) => const LoginScreen(),
            ),
          ],
        ),
      ];

      final router = await createRouter(routes, tester);
      router.go('/dummy');
      await tester.pump();
      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/login');
    });

    testWidgets('multiple mixed redirect', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'dummy1',
              builder: (context, state) => const DummyScreen(),
            ),
            GoRoute(
              path: 'dummy2',
              builder: (context, state) => const DummyScreen(),
              redirect: (context, state) => '/',
            ),
          ],
        ),
      ];

      final router = await createRouter(
        routes,
        tester,
        redirect: (context, state) => state.matchedLocation == '/dummy1' ? '/dummy2' : null,
      );
      router.go('/dummy1');
      await tester.pump();
      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/');
    });

    testWidgets('top-level redirect loop', (tester) async {
      final router = await createRouter(
        <GoRoute>[],
        tester,
        redirect: (context, state) => state.matchedLocation == '/'
            ? '/login'
            : state.matchedLocation == '/login'
            ? '/'
            : null,
        errorBuilder: (context, state) => TestErrorScreen(state.error!),
      );
      final matches = router.routerDelegate.currentConfiguration.matches;
      expect(matches, hasLength(0));
      expect(find.byType(TestErrorScreen), findsOneWidget);
      final screen = tester.widget<TestErrorScreen>(find.byType(TestErrorScreen));
      expect(screen.ex, isNotNull);
    });

    testWidgets('route-level redirect loop', (tester) async {
      final router = await createRouter(
        <GoRoute>[
          GoRoute(
            path: '/',
            builder: dummy,
            redirect: (context, state) => '/login',
          ),
          GoRoute(
            path: '/login',
            builder: dummy,
            redirect: (context, state) => '/',
          ),
        ],
        tester,
        errorBuilder: (context, state) => TestErrorScreen(state.error!),
      );

      final matches = router.routerDelegate.currentConfiguration.matches;
      expect(matches, hasLength(0));
      expect(find.byType(TestErrorScreen), findsOneWidget);
      final screen = tester.widget<TestErrorScreen>(find.byType(TestErrorScreen));
      expect(screen.ex, isNotNull);
    });

    testWidgets('mixed redirect loop', (tester) async {
      final router = await createRouter(
        <GoRoute>[
          GoRoute(
            path: '/login',
            builder: dummy,
            redirect: (context, state) => '/',
          ),
        ],
        tester,
        redirect: (context, state) => state.matchedLocation == '/' ? '/login' : null,
        errorBuilder: (context, state) => TestErrorScreen(state.error!),
      );

      final matches = router.routerDelegate.currentConfiguration.matches;
      expect(matches, hasLength(0));
      expect(find.byType(TestErrorScreen), findsOneWidget);
      final screen = tester.widget<TestErrorScreen>(find.byType(TestErrorScreen));
      expect(screen.ex, isNotNull);
    });

    testWidgets('top-level redirect loop w/ query params', (tester) async {
      final router = await createRouter(
        <GoRoute>[],
        tester,
        redirect: (context, state) => state.matchedLocation == '/'
            ? '/login?from=${state.uri}'
            : state.matchedLocation == '/login'
            ? '/'
            : null,
        errorBuilder: (context, state) => TestErrorScreen(state.error!),
      );

      final matches = router.routerDelegate.currentConfiguration.matches;
      expect(matches, hasLength(0));
      expect(find.byType(TestErrorScreen), findsOneWidget);
      final screen = tester.widget<TestErrorScreen>(find.byType(TestErrorScreen));
      expect(screen.ex, isNotNull);
    });

    testWidgets('expect null path/fullPath on top-level redirect', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/dummy',
          builder: dummy,
          redirect: (context, state) => '/',
        ),
      ];

      final router = await createRouter(routes, tester, initialLocation: '/dummy');
      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/');
    });

    testWidgets('top-level redirect state', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
      ];

      final router = await createRouter(
        routes,
        tester,
        initialLocation: '/login?from=/',
        redirect: (context, state) {
          expect(Uri.parse(state.uri.toString()).queryParameters, isNotEmpty);
          expect(Uri.parse(state.matchedLocation).queryParameters, isEmpty);
          expect(state.path, isNull);
          expect(state.fullPath, '/login');
          expect(state.pathParameters.length, 0);
          expect(state.uri.queryParameters.length, 1);
          expect(state.uri.queryParameters['from'], '/');
          return null;
        },
      );

      final matches = router.routerDelegate.currentConfiguration.matches;
      expect(matches, hasLength(1));
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('top-level redirect state contains path parameters', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (context, state) => const DummyScreen(),
          routes: <RouteBase>[
            GoRoute(
              path: ':id',
              builder: (context, state) => const DummyScreen(),
            ),
          ],
        ),
      ];

      final router = await createRouter(
        routes,
        tester,
        initialLocation: '/123',
        redirect: (context, state) {
          expect(state.path, isNull);
          expect(state.fullPath, '/:id');
          expect(state.pathParameters.length, 1);
          expect(state.pathParameters['id'], '123');
          return null;
        },
      );

      final matches = router.routerDelegate.currentConfiguration.matches;
      expect(matches, hasLength(2));
    });

    testWidgets('route-level redirect state', (tester) async {
      const loc = '/book/0';
      final routes = <GoRoute>[
        GoRoute(
          path: '/book/:bookId',
          redirect: (context, state) {
            expect(state.uri.toString(), loc);
            expect(state.matchedLocation, loc);
            expect(state.path, '/book/:bookId');
            expect(state.fullPath, '/book/:bookId');
            expect(state.pathParameters, <String, String>{'bookId': '0'});
            expect(state.uri.queryParameters.length, 0);
            return null;
          },
          builder: (c, s) => const HomeScreen(),
        ),
      ];

      final router = await createRouter(routes, tester, initialLocation: loc);

      final matches = router.routerDelegate.currentConfiguration.matches;
      expect(matches, hasLength(1));
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('sub-sub-route-level redirect params', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (c, s) => const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'family/:fid',
              builder: (c, s) => FamilyScreen(s.pathParameters['fid']!),
              routes: <GoRoute>[
                GoRoute(
                  path: 'person/:pid',
                  redirect: (context, s) {
                    expect(s.pathParameters['fid'], 'f2');
                    expect(s.pathParameters['pid'], 'p1');
                    return null;
                  },
                  builder: (c, s) =>
                      PersonScreen(s.pathParameters['fid']!, s.pathParameters['pid']!),
                ),
              ],
            ),
          ],
        ),
      ];

      final router = await createRouter(
        routes,
        tester,
        initialLocation: '/family/f2/person/p1',
      );

      final matches = router.routerDelegate.currentConfiguration.matches;
      expect(matches.length, 3);
      expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
      expect(find.byType(FamilyScreen, skipOffstage: false), findsOneWidget);
      final page = tester.widget<PersonScreen>(find.byType(PersonScreen));
      expect(page.fid, 'f2');
      expect(page.pid, 'p1');
    });

    testWidgets('redirect limit', (tester) async {
      final router = await createRouter(
        <GoRoute>[],
        tester,
        redirect: (context, state) => '/${state.uri}+',
        errorBuilder: (context, state) => TestErrorScreen(state.error!),
        redirectLimit: 10,
      );

      final matches = router.routerDelegate.currentConfiguration.matches;
      expect(matches, hasLength(0));
      expect(find.byType(TestErrorScreen), findsOneWidget);
      final screen = tester.widget<TestErrorScreen>(find.byType(TestErrorScreen));
      expect(screen.ex, isNotNull);
    });

    testWidgets('can push error page', (tester) async {
      final router = await createRouter(
        <GoRoute>[GoRoute(path: '/', builder: (_, _) => const Text('/'))],
        tester,
        errorBuilder: (_, state) {
          return Text(state.uri.toString());
        },
      );

      expect(find.text('/'), findsOneWidget);

      router.push('/error1');
      await tester.pumpAndSettle();

      expect(find.text('/'), findsNothing);
      expect(find.text('/error1'), findsOneWidget);

      router.push('/error2');
      await tester.pumpAndSettle();

      expect(find.text('/'), findsNothing);
      expect(find.text('/error1'), findsNothing);
      expect(find.text('/error2'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();

      expect(find.text('/'), findsNothing);
      expect(find.text('/error1'), findsOneWidget);
      expect(find.text('/error2'), findsNothing);

      router.pop();
      await tester.pumpAndSettle();

      expect(find.text('/'), findsOneWidget);
      expect(find.text('/error1'), findsNothing);
      expect(find.text('/error2'), findsNothing);
    });

    testWidgets('extra not null in redirect', (tester) async {
      var isCallTopRedirect = false;
      var isCallRouteRedirect = false;

      final routes = <GoRoute>[
        GoRoute(
          name: 'home',
          path: '/',
          builder: (context, state) => const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              name: 'login',
              path: 'login',
              builder: (context, state) {
                return const LoginScreen();
              },
              redirect: (context, state) {
                isCallRouteRedirect = true;
                expect(state.extra, isNotNull);
                return null;
              },
              routes: const <GoRoute>[],
            ),
          ],
        ),
      ];

      final router = await createRouter(
        routes,
        tester,
        redirect: (context, state) {
          if (state.uri.toString() == '/login') {
            isCallTopRedirect = true;
            expect(state.extra, isNotNull);
          }

          return null;
        },
      );

      router.go('/login', extra: 1);
      await tester.pump();

      expect(isCallTopRedirect, true);
      expect(isCallRouteRedirect, true);
    });

    testWidgets('parent route level redirect take priority over child', (
      tester,
    ) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'dummy',
              builder: (context, state) => const DummyScreen(),
              redirect: (context, state) => '/other',
              routes: <GoRoute>[
                GoRoute(
                  path: 'dummy2',
                  builder: (context, state) => const DummyScreen(),
                  redirect: (context, state) {
                    assert(false, 'The unexpected redirect callback was invoked.');
                    return '/other2';
                  },
                ),
              ],
            ),
            GoRoute(
              path: 'other',
              builder: (context, state) => const DummyScreen(),
            ),
            GoRoute(
              path: 'other2',
              builder: (context, state) => const DummyScreen(),
            ),
          ],
        ),
      ];

      final router = await createRouter(routes, tester);

      // Directly set the url through platform message.
      await sendPlatformUrl('/dummy/dummy2', tester);

      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/other');
    });

    testWidgets('redirect when go to a shell route', (tester) async {
      final routes = <RouteBase>[
        ShellRoute(
          redirect: (context, state) => '/dummy',
          builder: (context, state, child) => Scaffold(appBar: AppBar(), body: child),
          routes: <RouteBase>[
            GoRoute(
              path: '/other',
              builder: (context, state) => const DummyScreen(),
            ),
            GoRoute(
              path: '/other2',
              builder: (context, state) => const DummyScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/dummy',
          builder: (context, state) => const DummyScreen(),
        ),
      ];

      final router = await createRouter(routes, tester);

      for (final shellRoute in <String>['/other', '/other2']) {
        router.go(shellRoute);
        await tester.pump();
        expect(router.routerDelegate.currentConfiguration.uri.toString(), '/dummy');
      }
    });

    testWidgets('redirect when go to a stateful shell route', (tester) async {
      final routes = <RouteBase>[
        StatefulShellRoute.indexedStack(
          redirect: (context, state) => '/dummy',
          builder: (context, state, navigationShell) {
            return navigationShell;
          },
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: '/other',
                  builder: (context, state) => const DummyScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: '/other2',
                  builder: (context, state) => const DummyScreen(),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/dummy',
          builder: (context, state) => const DummyScreen(),
        ),
      ];

      final router = await createRouter(routes, tester);

      for (final shellRoute in <String>['/other', '/other2']) {
        router.go(shellRoute);
        await tester.pump();
        expect(router.routerDelegate.currentConfiguration.uri.toString(), '/dummy');
      }
    });
  });

  group('initial location', () {
    testWidgets('initial location', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'dummy',
              builder: (context, state) => const DummyScreen(),
            ),
          ],
        ),
      ];

      final router = await createRouter(routes, tester, initialLocation: '/dummy');
      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/dummy');
    });

    testWidgets('initial location with extra', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'dummy',
              builder: (context, state) {
                return DummyScreen(key: ValueKey<Object?>(state.extra));
              },
            ),
          ],
        ),
      ];

      final router = await createRouter(
        routes,
        tester,
        initialLocation: '/dummy',
        initialExtra: 'extra',
      );
      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/dummy');
      expect(find.byKey(const ValueKey<Object?>('extra')), findsOneWidget);
    });

    testWidgets('initial location w/ redirection', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/dummy',
          builder: dummy,
          redirect: (context, state) => '/',
        ),
      ];

      final router = await createRouter(routes, tester, initialLocation: '/dummy');
      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/');
    });

    testWidgets('does not take precedence over platformDispatcher.defaultRouteName', (
      tester,
    ) async {
      TestWidgetsFlutterBinding.instance.platformDispatcher.defaultRouteNameTestValue = '/dummy';

      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'dummy',
              builder: (context, state) => const DummyScreen(),
            ),
          ],
        ),
      ];

      final router = await createRouter(routes, tester);
      expect(router.routeInformationProvider.value.uri.path, '/dummy');
      TestWidgetsFlutterBinding.instance.platformDispatcher.clearDefaultRouteNameTestValue();
    });

    test('throws assertion if initialExtra is set w/o initialLocation', () {
      expect(
        () => GoRouter(routes: const <GoRoute>[], initialExtra: 1),
        throwsA(
          isA<AssertionError>().having(
            (e) => e.message,
            'error message',
            'initialLocation must be set in order to use initialExtra',
          ),
        ),
      );
    });
  });

  group('_effectiveInitialLocation()', () {
    final routes = <GoRoute>[
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
    ];

    testWidgets('When platformDispatcher.defaultRouteName is deep-link Uri with '
        'scheme, authority, no path', (tester) async {
      TestWidgetsFlutterBinding.instance.platformDispatcher.defaultRouteNameTestValue =
          'https://domain.com';
      final router = await createRouter(routes, tester);
      expect(router.routeInformationProvider.value.uri.path, '/');
      TestWidgetsFlutterBinding.instance.platformDispatcher.clearDefaultRouteNameTestValue();
    });

    testWidgets('When platformDispatcher.defaultRouteName is deep-link Uri with '
        'scheme, authority, no path, but trailing slash', (tester) async {
      TestWidgetsFlutterBinding.instance.platformDispatcher.defaultRouteNameTestValue =
          'https://domain.com/';
      final router = await createRouter(routes, tester);
      expect(router.routeInformationProvider.value.uri.path, '/');
      TestWidgetsFlutterBinding.instance.platformDispatcher.clearDefaultRouteNameTestValue();
    });

    testWidgets('When platformDispatcher.defaultRouteName is deep-link Uri with '
        'scheme, authority, no path, and query parameters', (tester) async {
      TestWidgetsFlutterBinding.instance.platformDispatcher.defaultRouteNameTestValue =
          'https://domain.com?param=1';
      final router = await createRouter(routes, tester);
      expect(router.routeInformationProvider.value.uri.toString(), 'https://domain.com/?param=1');
      TestWidgetsFlutterBinding.instance.platformDispatcher.clearDefaultRouteNameTestValue();
    });
  });

  group('params', () {
    testWidgets('preserve path param case', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/family/:fid',
          builder: (context, state) => FamilyScreen(state.pathParameters['fid']!),
        ),
      ];

      final router = await createRouter(routes, tester);
      for (final fid in <String>['f2', 'F2']) {
        final loc = '/family/$fid';
        router.go(loc);
        await tester.pumpAndSettle();
        final matches = router.routerDelegate.currentConfiguration;

        expect(router.routerDelegate.currentConfiguration.uri.toString(), loc);
        expect(matches.matches, hasLength(1));
        expect(find.byType(FamilyScreen), findsOneWidget);
        expect(matches.pathParameters['fid'], fid);
      }
    });

    testWidgets('preserve query param case', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/family',
          builder: (context, state) => FamilyScreen(state.uri.queryParameters['fid']!),
        ),
      ];

      final router = await createRouter(routes, tester);
      for (final fid in <String>['f2', 'F2']) {
        final loc = '/family?fid=$fid';
        router.go(loc);
        await tester.pumpAndSettle();
        final matches = router.routerDelegate.currentConfiguration;

        expect(router.routerDelegate.currentConfiguration.uri.toString(), loc);
        expect(matches.matches, hasLength(1));
        expect(find.byType(FamilyScreen), findsOneWidget);
        expect(matches.uri.queryParameters['fid'], fid);
      }
    });

    testWidgets('preserve path param spaces and slashes', (tester) async {
      const param1 = 'param w/ spaces and slashes';
      final routes = <GoRoute>[
        GoRoute(
          path: '/page1/:param1',
          builder: (c, s) {
            expect(s.pathParameters['param1'], param1);
            return const DummyScreen();
          },
        ),
      ];

      final router = await createRouter(routes, tester);
      final loc = '/page1/${Uri.encodeComponent(param1)}';
      router.go(loc);
      await tester.pumpAndSettle();

      final matches = router.routerDelegate.currentConfiguration;
      expect(find.byType(DummyScreen), findsOneWidget);
      expect(matches.pathParameters['param1'], param1);
    });

    testWidgets('preserve query param spaces and slashes', (tester) async {
      const param1 = 'param w/ spaces and slashes';
      final routes = <GoRoute>[
        GoRoute(
          path: '/page1',
          builder: (c, s) {
            expect(s.uri.queryParameters['param1'], param1);
            return const DummyScreen();
          },
        ),
      ];

      final router = await createRouter(routes, tester);
      router.go('/page1?param1=$param1');
      await tester.pumpAndSettle();

      final matches = router.routerDelegate.currentConfiguration;
      expect(find.byType(DummyScreen), findsOneWidget);
      expect(matches.uri.queryParameters['param1'], param1);

      final loc = '/page1?param1=${Uri.encodeQueryComponent(param1)}';
      router.go(loc);
      await tester.pumpAndSettle();

      final matches2 = router.routerDelegate.currentConfiguration;
      expect(find.byType(DummyScreen), findsOneWidget);
      expect(matches2.uri.queryParameters['param1'], param1);
    });

    test('error: duplicate path param', () {
      try {
        GoRouter(
          routes: <GoRoute>[GoRoute(path: '/:id/:blah/:bam/:id/:blah', builder: dummy)],
          errorBuilder: (context, state) => TestErrorScreen(state.error!),
          initialLocation: '/0/1/2/0/1',
        );
        expect(false, true);
      } on Exception catch (ex) {
        log.info(ex);
      }
    });

    testWidgets('duplicate query param', (tester) async {
      final router = await createRouter(
        <GoRoute>[
          GoRoute(
            path: '/',
            builder: (context, state) {
              log.info('id= ${state.pathParameters['id']}');
              expect(state.pathParameters.length, 0);
              expect(state.uri.queryParameters.length, 1);
              expect(state.uri.queryParameters['id'], anyOf('0', '1'));
              return const HomeScreen();
            },
          ),
        ],
        tester,
        initialLocation: '/?id=0&id=1',
      );
      final matches = router.routerDelegate.currentConfiguration;
      expect(matches.matches, hasLength(1));
      expect(matches.fullPath, '/');
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('duplicate path + query param', (tester) async {
      final router = await createRouter(<GoRoute>[
        GoRoute(
          path: '/:id',
          builder: (context, state) {
            expect(state.pathParameters, <String, String>{'id': '0'});
            expect(state.uri.queryParameters, <String, String>{'id': '1'});
            return const HomeScreen();
          },
        ),
      ], tester);

      router.go('/0?id=1');
      await tester.pumpAndSettle();
      final matches = router.routerDelegate.currentConfiguration;
      expect(matches.matches, hasLength(1));
      expect(matches.fullPath, '/:id');
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('push + query param', (tester) async {
      final router = await createRouter(<GoRoute>[
        GoRoute(path: '/', builder: dummy),
        GoRoute(
          path: '/family',
          builder: (context, state) => FamilyScreen(state.uri.queryParameters['fid']!),
        ),
        GoRoute(
          path: '/person',
          builder: (context, state) =>
              PersonScreen(state.uri.queryParameters['fid']!, state.uri.queryParameters['pid']!),
        ),
      ], tester);

      router.go('/family?fid=f2');
      await tester.pumpAndSettle();
      router.push('/person?fid=f2&pid=p1');
      await tester.pumpAndSettle();
      final page1 = tester.widget<FamilyScreen>(
        find.byType(FamilyScreen, skipOffstage: false),
      );
      expect(page1.fid, 'f2');

      final page2 = tester.widget<PersonScreen>(find.byType(PersonScreen));
      expect(page2.fid, 'f2');
      expect(page2.pid, 'p1');
    });

    testWidgets('push + extra param', (tester) async {
      final router = await createRouter(<GoRoute>[
        GoRoute(path: '/', builder: dummy),
        GoRoute(
          path: '/family',
          builder: (context, state) => FamilyScreen((state.extra! as Map<String, String>)['fid']!),
        ),
        GoRoute(
          path: '/person',
          builder: (context, state) => PersonScreen(
            (state.extra! as Map<String, String>)['fid']!,
            (state.extra! as Map<String, String>)['pid']!,
          ),
        ),
      ], tester);

      router.go('/family', extra: <String, String>{'fid': 'f2'});
      await tester.pumpAndSettle();
      router.push('/person', extra: <String, String>{'fid': 'f2', 'pid': 'p1'});
      await tester.pumpAndSettle();
      final page1 = tester.widget<FamilyScreen>(
        find.byType(FamilyScreen, skipOffstage: false),
      );
      expect(page1.fid, 'f2');

      final page2 = tester.widget<PersonScreen>(find.byType(PersonScreen));
      expect(page2.fid, 'f2');
      expect(page2.pid, 'p1');
    });

    testWidgets('keep param in nested route', (tester) async {
      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/family/:fid',
          builder: (context, state) => FamilyScreen(state.pathParameters['fid']!),
          routes: <GoRoute>[
            GoRoute(
              path: 'person/:pid',
              builder: (context, state) {
                final fid = state.pathParameters['fid']!;
                final pid = state.pathParameters['pid']!;

                return PersonScreen(fid, pid);
              },
            ),
          ],
        ),
      ];

      final router = await createRouter(routes, tester);
      const fid = 'f1';
      const pid = 'p2';
      const loc = '/family/$fid/person/$pid';

      router.push(loc);
      await tester.pumpAndSettle();
      final matches = router.routerDelegate.currentConfiguration;

      expect(matches.matches, hasLength(2));
      expect(find.byType(PersonScreen), findsOneWidget);
      final imperativeRouteMatch = matches.matches.last as ImperativeRouteMatch;
      expect(imperativeRouteMatch.matches.uri.toString(), loc);
      expect(imperativeRouteMatch.matches.pathParameters['fid'], fid);
      expect(imperativeRouteMatch.matches.pathParameters['pid'], pid);
    });

    testWidgets('StatefulShellRoute supports nested routes with params', (
      tester,
    ) async {
      StatefulNavigationShell? routeState;
      final routes = <RouteBase>[
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            routeState = navigationShell;
            return navigationShell;
          },
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: '/a',
                  builder: (context, state) => const Text('Screen A'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: '/family',
                  builder: (context, state) => const Text('Families'),
                  routes: <RouteBase>[
                    GoRoute(
                      path: ':fid',
                      builder: (context, state) => FamilyScreen(state.pathParameters['fid']!),
                      routes: <GoRoute>[
                        GoRoute(
                          path: 'person/:pid',
                          builder: (context, state) {
                            final fid = state.pathParameters['fid']!;
                            final pid = state.pathParameters['pid']!;

                            return PersonScreen(fid, pid);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ];

      final router = await createRouter(routes, tester, initialLocation: '/a');
      const fid = 'f1';
      const pid = 'p2';
      const loc = '/family/$fid/person/$pid';

      router.go(loc);
      await tester.pumpAndSettle();
      var matches = router.routerDelegate.currentConfiguration;

      expect(router.routerDelegate.currentConfiguration.uri.toString(), loc);
      expect(matches.matches, hasLength(1));
      final shellRouteMatch = matches.matches.first as ShellRouteMatch;
      expect(shellRouteMatch.matches, hasLength(3));
      expect(find.byType(PersonScreen), findsOneWidget);
      expect(matches.pathParameters['fid'], fid);
      expect(matches.pathParameters['pid'], pid);

      routeState?.goBranch(0);
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsOneWidget);
      expect(find.byType(PersonScreen), findsNothing);

      routeState?.goBranch(1);
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsNothing);
      expect(find.byType(PersonScreen), findsOneWidget);
      matches = router.routerDelegate.currentConfiguration;
      expect(matches.pathParameters['fid'], fid);
      expect(matches.pathParameters['pid'], pid);
    });

    testWidgets('StatefulShellRoute preserve extra when switching branch', (
      tester,
    ) async {
      StatefulNavigationShell? routeState;
      Object? latestExtra;
      final routes = <RouteBase>[
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            routeState = navigationShell;
            return navigationShell;
          },
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: '/a',
                  builder: (context, state) => const Text('Screen A'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: '/b',
                  builder: (context, state) {
                    latestExtra = state.extra;
                    return const DummyScreen();
                  },
                ),
              ],
            ),
          ],
        ),
      ];
      final expectedExtra = Object();

      await createRouter(routes, tester, initialLocation: '/b', initialExtra: expectedExtra);
      expect(latestExtra, expectedExtra);
      routeState!.goBranch(0);
      await tester.pumpAndSettle();
      routeState!.goBranch(1);
      await tester.pumpAndSettle();
      expect(latestExtra, expectedExtra);
    });

    testWidgets('goNames should allow dynamics values for queryParams', (
      tester,
    ) async {
      const Map<String, dynamic> queryParametersAll = <String, List<dynamic>>{
        'q1': <String>['v1'],
        'q2': <String>['v2', 'v3'],
      };
      void expectLocationWithQueryParams(String location) {
        final uri = Uri.parse(location);
        expect(uri.path, '/page');
        expect(uri.queryParametersAll, queryParametersAll);
      }

      final routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          name: 'page',
          path: '/page',
          builder: (context, state) {
            expect(state.uri.queryParametersAll, queryParametersAll);
            expectLocationWithQueryParams(state.uri.toString());
            return DummyScreen(queryParametersAll: state.uri.queryParametersAll);
          },
        ),
      ];

      final router = await createRouter(routes, tester);

      router.goNamed(
        'page',
        queryParameters: const <String, dynamic>{
          'q1': 'v1',
          'q2': <String>['v2', 'v3'],
        },
      );
      await tester.pumpAndSettle();
      final matches = router.routerDelegate.currentConfiguration.matches;

      expect(matches, hasLength(1));
      expectLocationWithQueryParams(router.routerDelegate.currentConfiguration.uri.toString());
      expect(
        tester.widget<DummyScreen>(find.byType(DummyScreen)),
        isA<DummyScreen>().having(
          (screen) => screen.queryParametersAll,
          'screen.queryParametersAll',
          queryParametersAll,
        ),
      );
    });
  });

  testWidgets('go should preserve the query parameters when navigating', (
    tester,
  ) async {
    const Map<String, dynamic> queryParametersAll = <String, List<dynamic>>{
      'q1': <String>['v1'],
      'q2': <String>['v2', 'v3'],
    };
    void expectLocationWithQueryParams(String location) {
      final uri = Uri.parse(location);
      expect(uri.path, '/page');
      expect(uri.queryParametersAll, queryParametersAll);
    }

    final routes = <GoRoute>[
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        name: 'page',
        path: '/page',
        builder: (context, state) {
          expect(state.uri.queryParametersAll, queryParametersAll);
          expectLocationWithQueryParams(state.uri.toString());
          return DummyScreen(queryParametersAll: state.uri.queryParametersAll);
        },
      ),
    ];

    final router = await createRouter(routes, tester);

    router.go('/page?q1=v1&q2=v2&q2=v3');
    await tester.pumpAndSettle();
    final matches = router.routerDelegate.currentConfiguration.matches;

    expect(matches, hasLength(1));
    expectLocationWithQueryParams(router.routerDelegate.currentConfiguration.uri.toString());
    expect(
      tester.widget<DummyScreen>(find.byType(DummyScreen)),
      isA<DummyScreen>().having(
        (screen) => screen.queryParametersAll,
        'screen.queryParametersAll',
        queryParametersAll,
      ),
    );
  });

  testWidgets('goRouter should rebuild widget if ', (tester) async {
    const Map<String, dynamic> queryParametersAll = <String, List<dynamic>>{
      'q1': <String>['v1'],
      'q2': <String>['v2', 'v3'],
    };
    void expectLocationWithQueryParams(String location) {
      final uri = Uri.parse(location);
      expect(uri.path, '/page');
      expect(uri.queryParametersAll, queryParametersAll);
    }

    final routes = <GoRoute>[
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        name: 'page',
        path: '/page',
        builder: (context, state) {
          expect(state.uri.queryParametersAll, queryParametersAll);
          expectLocationWithQueryParams(state.uri.toString());
          return DummyScreen(queryParametersAll: state.uri.queryParametersAll);
        },
      ),
    ];

    final router = await createRouter(routes, tester);

    router.go('/page?q1=v1&q2=v2&q2=v3');
    await tester.pumpAndSettle();
    final matches = router.routerDelegate.currentConfiguration.matches;

    expect(matches, hasLength(1));
    expectLocationWithQueryParams(router.routerDelegate.currentConfiguration.uri.toString());
    expect(
      tester.widget<DummyScreen>(find.byType(DummyScreen)),
      isA<DummyScreen>().having(
        (screen) => screen.queryParametersAll,
        'screen.queryParametersAll',
        queryParametersAll,
      ),
    );
  });

  group('GoRouterHelper extensions', () {
    final key = GlobalKey<DummyStatefulWidgetState>();
    final routes = <GoRoute>[
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => DummyStatefulWidget(key: key),
      ),
      GoRoute(
        path: '/page1',
        name: 'page1',
        builder: (context, state) => const Page1Screen(),
      ),
    ];

    const name = 'page1';
    final params = <String, String>{'a-param-key': 'a-param-value'};
    final queryParams = <String, String>{'a-query-key': 'a-query-value'};
    const location = '/page1';
    const extra = 'Hello';

    testWidgets('calls [namedLocation] on closest GoRouter', (tester) async {
      final router = GoRouterNamedLocationSpy(routes: routes);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router, title: 'GoRouter Example'));
      key.currentContext!.namedLocation(name, pathParameters: params, queryParameters: queryParams);
      expect(router.name, name);
      expect(router.pathParameters, params);
      expect(router.queryParameters, queryParams);
    });

    testWidgets('calls [go] on closest GoRouter', (tester) async {
      final router = GoRouterGoSpy(routes: routes);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router, title: 'GoRouter Example'));
      key.currentContext!.go(location, extra: extra);
      expect(router.myLocation, location);
      expect(router.extra, extra);
    });

    testWidgets('calls [goNamed] on closest GoRouter', (tester) async {
      final router = GoRouterGoNamedSpy(routes: routes);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router, title: 'GoRouter Example'));
      key.currentContext!.goNamed(
        name,
        pathParameters: params,
        queryParameters: queryParams,
        extra: extra,
      );
      expect(router.name, name);
      expect(router.pathParameters, params);
      expect(router.queryParameters, queryParams);
      expect(router.extra, extra);
    });

    testWidgets('calls [push] on closest GoRouter', (tester) async {
      final router = GoRouterPushSpy(routes: routes);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router, title: 'GoRouter Example'));
      key.currentContext!.push(location, extra: extra);
      expect(router.myLocation, location);
      expect(router.extra, extra);
    });

    testWidgets('calls [push] on closest GoRouter and waits for result', (
      tester,
    ) async {
      final router = GoRouterPushSpy(routes: routes);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routeInformationProvider: router.routeInformationProvider,
          routeInformationParser: router.routeInformationParser,
          routerDelegate: router.routerDelegate,
          title: 'GoRouter Example',
        ),
      );
      final result = await router.push<String>(location, extra: extra);
      expect(result, extra);
      expect(router.myLocation, location);
      expect(router.extra, extra);
    });

    testWidgets('calls [pushNamed] on closest GoRouter', (tester) async {
      final router = GoRouterPushNamedSpy(routes: routes);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router, title: 'GoRouter Example'));
      key.currentContext!.pushNamed(
        name,
        pathParameters: params,
        queryParameters: queryParams,
        extra: extra,
      );
      expect(router.name, name);
      expect(router.pathParameters, params);
      expect(router.queryParameters, queryParams);
      expect(router.extra, extra);
    });

    testWidgets('calls [pushNamed] on closest GoRouter and waits for result', (
      tester,
    ) async {
      final router = GoRouterPushNamedSpy(routes: routes);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routeInformationProvider: router.routeInformationProvider,
          routeInformationParser: router.routeInformationParser,
          routerDelegate: router.routerDelegate,
          title: 'GoRouter Example',
        ),
      );
      final result = await router.pushNamed<String>(
        name,
        pathParameters: params,
        queryParameters: queryParams,
        extra: extra,
      );
      expect(result, extra);
      expect(router.extra, extra);
      expect(router.name, name);
      expect(router.pathParameters, params);
      expect(router.queryParameters, queryParams);
    });

    testWidgets('calls [pop] on closest GoRouter', (tester) async {
      final router = GoRouterPopSpy(routes: routes);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router, title: 'GoRouter Example'));
      key.currentContext!.pop();
      expect(router.popped, true);
      expect(router.poppedResult, null);
    });

    testWidgets('calls [pop] on closest GoRouter with result', (tester) async {
      final router = GoRouterPopSpy(routes: routes);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router, title: 'GoRouter Example'));
      key.currentContext!.pop('result');
      expect(router.popped, true);
      expect(router.poppedResult, 'result');
    });
  });

  group('ShellRoute', () {
    testWidgets('defaultRoute', (tester) async {
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

      await createRouter(routes, tester, initialLocation: '/b');
      expect(find.text('Screen B'), findsOneWidget);
    });

    testWidgets('can complete leaf route', (tester) async {
      Future<bool?>? routeFuture;
      final routes = <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) {
            return Scaffold(
              body: TextButton(
                onPressed: () => Future.sync(() {
                  routeFuture = context.push<bool>('/a');
                }),
                child: const Text('press'),
              ),
            );
          },
        ),
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
          ],
        ),
      ];

      final router = await createRouter(routes, tester);
      expect(find.text('press'), findsOneWidget);

      await tester.tap(find.text('press'));
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsOneWidget);

      router.pop<bool>(true);
      final result = await routeFuture;
      expect(result, isTrue);
    });

    testWidgets('Pops from the correct Navigator when the Android back button is pressed', (
      tester,
    ) async {
      final routes = <RouteBase>[
        ShellRoute(
          builder: (context, state, child) {
            return Scaffold(
              body: Column(
                children: <Widget>[
                  const Text('Screen A'),
                  Expanded(child: child),
                ],
              ),
            );
          },
          routes: <RouteBase>[
            GoRoute(
              path: '/b',
              builder: (context, state) {
                return const Scaffold(body: Text('Screen B'));
              },
              routes: <RouteBase>[
                GoRoute(
                  path: 'c',
                  builder: (context, state) {
                    return const Scaffold(body: Text('Screen C'));
                  },
                ),
              ],
            ),
          ],
        ),
      ];

      await createRouter(routes, tester, initialLocation: '/b/c');
      expect(find.text('Screen A'), findsOneWidget);
      expect(find.text('Screen B'), findsNothing);
      expect(find.text('Screen C'), findsOneWidget);

      await simulateAndroidBackButton(tester);
      await tester.pumpAndSettle();

      expect(find.text('Screen A'), findsOneWidget);
      expect(find.text('Screen B'), findsOneWidget);
      expect(find.text('Screen C'), findsNothing);
    });

    testWidgets('Pops from the correct navigator when a sub-route is placed on '
        'the root Navigator', (tester) async {
      final rootNavigatorKey = GlobalKey<NavigatorState>();
      final shellNavigatorKey = GlobalKey<NavigatorState>();

      final routes = <RouteBase>[
        ShellRoute(
          navigatorKey: shellNavigatorKey,
          builder: (context, state, child) {
            return Scaffold(
              body: Column(
                children: <Widget>[
                  const Text('Screen A'),
                  Expanded(child: child),
                ],
              ),
            );
          },
          routes: <RouteBase>[
            GoRoute(
              path: '/b',
              builder: (context, state) {
                return const Scaffold(body: Text('Screen B'));
              },
              routes: <RouteBase>[
                GoRoute(
                  path: 'c',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) {
                    return const Scaffold(body: Text('Screen C'));
                  },
                ),
              ],
            ),
          ],
        ),
      ];

      await createRouter(routes, tester, initialLocation: '/b/c', navigatorKey: rootNavigatorKey);
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen B'), findsNothing);
      expect(find.text('Screen C'), findsOneWidget);

      await simulateAndroidBackButton(tester);
      await tester.pumpAndSettle();

      expect(find.text('Screen A'), findsOneWidget);
      expect(find.text('Screen B'), findsOneWidget);
      expect(find.text('Screen C'), findsNothing);
    });

    testWidgets('Builds StatefulShellRoute', (tester) async {
      final rootNavigatorKey = GlobalKey<NavigatorState>();

      final routes = <RouteBase>[
        StatefulShellRoute.indexedStack(
          builder:
              (
                context,
                state,
                navigationShell,
              ) => navigationShell,
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              routes: <GoRoute>[
                GoRoute(
                  path: '/a',
                  builder: (context, state) => const Text('Screen A'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <GoRoute>[
                GoRoute(
                  path: '/b',
                  builder: (context, state) => const Text('Screen B'),
                ),
              ],
            ),
          ],
        ),
      ];

      final router = await createRouter(
        routes,
        tester,
        initialLocation: '/a',
        navigatorKey: rootNavigatorKey,
      );
      expect(find.text('Screen A'), findsOneWidget);
      expect(find.text('Screen B'), findsNothing);

      router.go('/b');
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen B'), findsOneWidget);
    });

    testWidgets('Builds StatefulShellRoute as a sub-route', (tester) async {
      final rootNavigatorKey = GlobalKey<NavigatorState>();

      final routes = <RouteBase>[
        GoRoute(
          path: '/root',
          builder: (context, state) => const Text('Root'),
          routes: <RouteBase>[
            StatefulShellRoute.indexedStack(
              builder:
                  (
                    context,
                    state,
                    navigationShell,
                  ) => navigationShell,
              branches: <StatefulShellBranch>[
                StatefulShellBranch(
                  routes: <GoRoute>[
                    GoRoute(
                      path: 'a',
                      builder: (context, state) => const Text('Screen A'),
                    ),
                  ],
                ),
                StatefulShellBranch(
                  routes: <GoRoute>[
                    GoRoute(
                      path: 'b',
                      builder: (context, state) => const Text('Screen B'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ];

      final router = await createRouter(
        routes,
        tester,
        initialLocation: '/root/a',
        navigatorKey: rootNavigatorKey,
      );
      expect(find.text('Screen A'), findsOneWidget);
      expect(find.text('Screen B'), findsNothing);

      router.go('/root/b');
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen B'), findsOneWidget);
    });

    testWidgets('Navigation with goBranch is correctly handled in StatefulShellRoute', (
      tester,
    ) async {
      final rootNavigatorKey = GlobalKey<NavigatorState>();
      final statefulWidgetKey = GlobalKey<DummyStatefulWidgetState>();
      StatefulNavigationShell? routeState;

      final routes = <RouteBase>[
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            routeState = navigationShell;
            return navigationShell;
          },
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: '/a',
                  builder: (context, state) => const Text('Screen A'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: '/b',
                  builder: (context, state) => const Text('Screen B'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: '/c',
                  builder: (context, state) => const Text('Screen C'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: '/d',
                  builder: (context, state) => const Text('Screen D'),
                ),
              ],
            ),
          ],
        ),
      ];

      await createRouter(routes, tester, initialLocation: '/a', navigatorKey: rootNavigatorKey);
      statefulWidgetKey.currentState?.increment();
      expect(find.text('Screen A'), findsOneWidget);
      expect(find.text('Screen B'), findsNothing);
      expect(find.text('Screen C'), findsNothing);
      expect(find.text('Screen D'), findsNothing);

      routeState!.goBranch(1);
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen B'), findsOneWidget);
      expect(find.text('Screen C'), findsNothing);
      expect(find.text('Screen D'), findsNothing);

      routeState!.goBranch(2);
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen B'), findsNothing);
      expect(find.text('Screen C'), findsOneWidget);
      expect(find.text('Screen D'), findsNothing);

      routeState!.goBranch(3);
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen B'), findsNothing);
      expect(find.text('Screen C'), findsNothing);
      expect(find.text('Screen D'), findsOneWidget);

      expect(() {
        // Verify that navigation to unknown index fails
        routeState!.goBranch(4);
      }, throwsA(isA<Error>()));
    });

    testWidgets('Navigates to correct nested navigation tree in StatefulShellRoute '
        'and maintains state', (tester) async {
      final rootNavigatorKey = GlobalKey<NavigatorState>();
      final statefulWidgetKey = GlobalKey<DummyStatefulWidgetState>();
      StatefulNavigationShell? routeState;

      final routes = <RouteBase>[
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            routeState = navigationShell;
            return navigationShell;
          },
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              routes: <GoRoute>[
                GoRoute(
                  path: '/a',
                  builder: (context, state) => const Text('Screen A'),
                  routes: <RouteBase>[
                    GoRoute(
                      path: 'detailA',
                      builder: (context, state) => Column(
                        children: <Widget>[
                          const Text('Screen A Detail'),
                          DummyStatefulWidget(key: statefulWidgetKey),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <GoRoute>[
                GoRoute(
                  path: '/b',
                  builder: (context, state) => const Text('Screen B'),
                ),
              ],
            ),
          ],
        ),
      ];

      final router = await createRouter(
        routes,
        tester,
        initialLocation: '/a/detailA',
        navigatorKey: rootNavigatorKey,
      );
      statefulWidgetKey.currentState?.increment();
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen A Detail'), findsOneWidget);
      expect(find.text('Screen B'), findsNothing);

      routeState!.goBranch(1);
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen A Detail'), findsNothing);
      expect(find.text('Screen B'), findsOneWidget);

      routeState!.goBranch(0);
      await tester.pumpAndSettle();
      expect(statefulWidgetKey.currentState?.counter, equals(1));

      router.go('/a');
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsOneWidget);
      expect(find.text('Screen A Detail'), findsNothing);
      router.go('/a/detailA');
      await tester.pumpAndSettle();
      expect(statefulWidgetKey.currentState?.counter, equals(0));
    });

    testWidgets('Navigates to correct nested navigation tree in StatefulShellRoute '
        'and maintains path parameters', (tester) async {
      StatefulNavigationShell? routeState;

      final routes = <RouteBase>[
        GoRoute(
          path: '/:id',
          builder: (_, _) => const Placeholder(),
          routes: <RouteBase>[
            StatefulShellRoute.indexedStack(
              builder:
                  (
                    context,
                    state,
                    navigationShell,
                  ) {
                    routeState = navigationShell;
                    return navigationShell;
                  },
              branches: <StatefulShellBranch>[
                StatefulShellBranch(
                  routes: <GoRoute>[
                    GoRoute(
                      path: 'a',
                      builder: (context, state) => Text('a id is ${state.pathParameters['id']}'),
                    ),
                  ],
                ),
                StatefulShellBranch(
                  routes: <GoRoute>[
                    GoRoute(
                      path: 'b',
                      builder: (context, state) => Text('b id is ${state.pathParameters['id']}'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ];

      await createRouter(routes, tester, initialLocation: '/123/a');
      expect(find.text('a id is 123'), findsOneWidget);

      routeState!.goBranch(1);
      await tester.pumpAndSettle();
      expect(find.text('b id is 123'), findsOneWidget);
    });

    testWidgets('Maintains state for nested StatefulShellRoute', (tester) async {
      final rootNavigatorKey = GlobalKey<NavigatorState>();
      final statefulWidgetKey = GlobalKey<DummyStatefulWidgetState>();
      StatefulNavigationShell? routeState1;
      StatefulNavigationShell? routeState2;

      final routes = <RouteBase>[
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            routeState1 = navigationShell;
            return navigationShell;
          },
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              routes: <RouteBase>[
                StatefulShellRoute.indexedStack(
                  builder:
                      (
                        context,
                        state,
                        navigationShell,
                      ) {
                        routeState2 = navigationShell;
                        return navigationShell;
                      },
                  branches: <StatefulShellBranch>[
                    StatefulShellBranch(
                      routes: <RouteBase>[
                        GoRoute(
                          path: '/a',
                          builder: (context, state) => const Text('Screen A'),
                          routes: <RouteBase>[
                            GoRoute(
                              path: 'detailA',
                              builder: (context, state) => Column(
                                children: <Widget>[
                                  const Text('Screen A Detail'),
                                  DummyStatefulWidget(key: statefulWidgetKey),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    StatefulShellBranch(
                      routes: <RouteBase>[
                        GoRoute(
                          path: '/b',
                          builder: (context, state) => const Text('Screen B'),
                        ),
                      ],
                    ),
                    StatefulShellBranch(
                      routes: <RouteBase>[
                        GoRoute(
                          path: '/c',
                          builder: (context, state) => const Text('Screen C'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <GoRoute>[
                GoRoute(
                  path: '/d',
                  builder: (context, state) => const Text('Screen D'),
                ),
              ],
            ),
          ],
        ),
      ];

      await createRouter(
        routes,
        tester,
        initialLocation: '/a/detailA',
        navigatorKey: rootNavigatorKey,
      );
      statefulWidgetKey.currentState?.increment();
      expect(find.text('Screen A Detail'), findsOneWidget);
      routeState2!.goBranch(1);
      await tester.pumpAndSettle();
      expect(find.text('Screen B'), findsOneWidget);

      routeState1!.goBranch(1);
      await tester.pumpAndSettle();
      expect(find.text('Screen D'), findsOneWidget);

      routeState1!.goBranch(0);
      await tester.pumpAndSettle();
      expect(find.text('Screen B'), findsOneWidget);

      routeState2!.goBranch(2);
      await tester.pumpAndSettle();
      expect(find.text('Screen C'), findsOneWidget);

      routeState2!.goBranch(0);
      await tester.pumpAndSettle();
      expect(find.text('Screen A Detail'), findsOneWidget);
      expect(statefulWidgetKey.currentState?.counter, equals(1));
    });

    testWidgets('Pops from the correct Navigator in a StatefulShellRoute when the '
        'Android back button is pressed', (tester) async {
      final rootNavigatorKey = GlobalKey<NavigatorState>();
      final sectionANavigatorKey = GlobalKey<NavigatorState>();
      final sectionBNavigatorKey = GlobalKey<NavigatorState>();
      StatefulNavigationShell? routeState;

      final routes = <RouteBase>[
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            routeState = navigationShell;
            return navigationShell;
          },
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              navigatorKey: sectionANavigatorKey,
              routes: <GoRoute>[
                GoRoute(
                  path: '/a',
                  builder: (context, state) => const Text('Screen A'),
                  routes: <RouteBase>[
                    GoRoute(
                      path: 'detailA',
                      builder: (context, state) => const Text('Screen A Detail'),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              navigatorKey: sectionBNavigatorKey,
              routes: <GoRoute>[
                GoRoute(
                  path: '/b',
                  builder: (context, state) => const Text('Screen B'),
                  routes: <RouteBase>[
                    GoRoute(
                      path: 'detailB',
                      builder: (context, state) => const Text('Screen B Detail'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ];

      final router = await createRouter(
        routes,
        tester,
        initialLocation: '/a/detailA',
        navigatorKey: rootNavigatorKey,
      );
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen A Detail'), findsOneWidget);
      expect(find.text('Screen B'), findsNothing);
      expect(find.text('Screen B Detail'), findsNothing);

      router.go('/b/detailB');
      await tester.pumpAndSettle();

      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen A Detail'), findsNothing);
      expect(find.text('Screen B'), findsNothing);
      expect(find.text('Screen B Detail'), findsOneWidget);

      await simulateAndroidBackButton(tester);
      await tester.pumpAndSettle();

      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen A Detail'), findsNothing);
      expect(find.text('Screen B'), findsOneWidget);
      expect(find.text('Screen B Detail'), findsNothing);

      routeState!.goBranch(0);
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen A Detail'), findsOneWidget);

      await simulateAndroidBackButton(tester);
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsOneWidget);
      expect(find.text('Screen A Detail'), findsNothing);
    });

    testWidgets('Maintains extra navigation information when navigating '
        'between branches in StatefulShellRoute', (tester) async {
      final rootNavigatorKey = GlobalKey<NavigatorState>();
      StatefulNavigationShell? routeState;

      final routes = <RouteBase>[
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            routeState = navigationShell;
            return navigationShell;
          },
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              routes: <GoRoute>[
                GoRoute(
                  path: '/a',
                  builder: (context, state) => const Text('Screen A'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <GoRoute>[
                GoRoute(
                  path: '/b',
                  builder: (context, state) => Text('Screen B - ${state.extra}'),
                ),
              ],
            ),
          ],
        ),
      ];

      final router = await createRouter(
        routes,
        tester,
        initialLocation: '/a',
        navigatorKey: rootNavigatorKey,
      );
      expect(find.text('Screen A'), findsOneWidget);

      router.go('/b', extra: 'X');
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen B - X'), findsOneWidget);

      routeState!.goBranch(0);
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsOneWidget);
      expect(find.text('Screen B - X'), findsNothing);

      routeState!.goBranch(1);
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen B - X'), findsOneWidget);
    });

    testWidgets('Pushed non-descendant routes are correctly restored when '
        'navigating between branches in StatefulShellRoute', (tester) async {
      final rootNavigatorKey = GlobalKey<NavigatorState>();
      StatefulNavigationShell? routeState;

      final routes = <RouteBase>[
        GoRoute(
          path: '/common',
          builder: (context, state) => Text('Common - ${state.extra}'),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            routeState = navigationShell;
            return navigationShell;
          },
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              routes: <GoRoute>[
                GoRoute(
                  path: '/a',
                  builder: (context, state) => const Text('Screen A'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <GoRoute>[
                GoRoute(
                  path: '/b',
                  builder: (context, state) => const Text('Screen B'),
                ),
              ],
            ),
          ],
        ),
      ];

      final router = await createRouter(
        routes,
        tester,
        initialLocation: '/a',
        navigatorKey: rootNavigatorKey,
      );
      expect(find.text('Screen A'), findsOneWidget);

      router.go('/b');
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen B'), findsOneWidget);

      // This push '/common' on top of entire stateful shell route page.
      router.push('/common', extra: 'X');
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen B'), findsNothing);
      expect(find.text('Common - X'), findsOneWidget);

      routeState!.goBranch(0);
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsOneWidget);

      routeState!.goBranch(1);
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen B'), findsOneWidget);
    });

    testWidgets('Preloads routes correctly in a StatefulShellRoute', (tester) async {
      final rootNavigatorKey = GlobalKey<NavigatorState>();
      final statefulWidgetKeyA = GlobalKey<DummyStatefulWidgetState>(debugLabel: 'A');
      final statefulWidgetKeyB = GlobalKey<DummyStatefulWidgetState>(debugLabel: 'B');
      final statefulWidgetKeyC = GlobalKey<DummyStatefulWidgetState>(debugLabel: 'C');
      final statefulWidgetKeyD = GlobalKey<DummyStatefulWidgetState>(debugLabel: 'D');
      final statefulWidgetKeyE = GlobalKey<DummyStatefulWidgetState>(debugLabel: 'E');

      final routes = <RouteBase>[
        StatefulShellRoute.indexedStack(
          builder: mockStackedShellBuilder,
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: '/a',
                  builder: (context, state) => DummyStatefulWidget(key: statefulWidgetKeyA),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: '/b',
                  builder: (context, state) => DummyStatefulWidget(key: statefulWidgetKeyB),
                ),
              ],
            ),
          ],
        ),
        StatefulShellRoute.indexedStack(
          builder: mockStackedShellBuilder,
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              preload: true,
              routes: <RouteBase>[
                GoRoute(
                  path: '/c',
                  builder: (context, state) => DummyStatefulWidget(key: statefulWidgetKeyC),
                ),
              ],
            ),
            StatefulShellBranch(
              preload: true,
              routes: <RouteBase>[
                GoRoute(
                  path: '/d',
                  builder: (context, state) => DummyStatefulWidget(key: statefulWidgetKeyD),
                ),
              ],
            ),
            StatefulShellBranch(
              preload: true,
              initialLocation: '/e/details',
              routes: <RouteBase>[
                GoRoute(
                  path: '/e',
                  builder: (context, state) => const Text('E'),
                  routes: <RouteBase>[
                    GoRoute(
                      path: 'details',
                      builder: (context, state) => DummyStatefulWidget(key: statefulWidgetKeyE),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ];

      final router = await createRouter(
        routes,
        tester,
        initialLocation: '/a',
        navigatorKey: rootNavigatorKey,
      );
      expect(statefulWidgetKeyA.currentState?.counter, equals(0));
      expect(statefulWidgetKeyB.currentState?.counter, null);
      expect(statefulWidgetKeyC.currentState?.counter, null);
      expect(statefulWidgetKeyD.currentState?.counter, null);

      router.go('/c');
      await tester.pumpAndSettle();
      expect(statefulWidgetKeyC.currentState?.counter, equals(0));
      expect(statefulWidgetKeyD.currentState?.counter, equals(0));
      expect(statefulWidgetKeyE.currentState?.counter, equals(0));
    });

    testWidgets('Preloads nested routes correctly in a StatefulShellRoute', (
      tester,
    ) async {
      final rootNavigatorKey = GlobalKey<NavigatorState>();
      final statefulWidgetKeyA = GlobalKey<DummyStatefulWidgetState>(debugLabel: 'A');
      final statefulWidgetKeyB = GlobalKey<DummyStatefulWidgetState>(debugLabel: 'B');
      final statefulWidgetKeyC = GlobalKey<DummyStatefulWidgetState>(debugLabel: 'C');
      final statefulWidgetKeyD = GlobalKey<DummyStatefulWidgetState>(debugLabel: 'D');

      final routes = <RouteBase>[
        StatefulShellRoute.indexedStack(
          builder: mockStackedShellBuilder,
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              preload: true,
              routes: <RouteBase>[
                StatefulShellRoute.indexedStack(
                  builder: mockStackedShellBuilder,
                  branches: <StatefulShellBranch>[
                    StatefulShellBranch(
                      preload: true,
                      routes: <RouteBase>[
                        GoRoute(
                          path: '/a',
                          builder: (context, state) => DummyStatefulWidget(key: statefulWidgetKeyA),
                        ),
                      ],
                    ),
                    StatefulShellBranch(
                      preload: true,
                      routes: <RouteBase>[
                        GoRoute(
                          path: '/b',
                          builder: (context, state) => DummyStatefulWidget(key: statefulWidgetKeyB),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              preload: true,
              routes: <RouteBase>[
                GoRoute(
                  path: '/c',
                  builder: (context, state) => DummyStatefulWidget(key: statefulWidgetKeyC),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: '/d',
                  builder: (context, state) => DummyStatefulWidget(key: statefulWidgetKeyD),
                ),
              ],
            ),
          ],
        ),
      ];

      await createRouter(routes, tester, initialLocation: '/c', navigatorKey: rootNavigatorKey);
      expect(statefulWidgetKeyA.currentState?.counter, equals(0));
      expect(statefulWidgetKeyB.currentState?.counter, equals(0));
      expect(statefulWidgetKeyC.currentState?.counter, equals(0));
      expect(statefulWidgetKeyD.currentState?.counter, null);
    });

    testWidgets('Redirects are correctly handled when switching branch in a '
        'StatefulShellRoute', (tester) async {
      final rootNavigatorKey = GlobalKey<NavigatorState>();
      StatefulNavigationShell? routeState;

      final routes = <RouteBase>[
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            routeState = navigationShell;
            return navigationShell;
          },
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              routes: <GoRoute>[
                GoRoute(
                  path: '/a',
                  builder: (context, state) => const Text('Screen A'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <GoRoute>[
                GoRoute(
                  path: '/b',
                  builder: (context, state) => const Text('Screen B'),
                  routes: <RouteBase>[
                    GoRoute(
                      path: 'details1',
                      builder: (context, state) => const Text('Screen B Detail1'),
                    ),
                    GoRoute(
                      path: 'details2',
                      builder: (context, state) => const Text('Screen B Detail2'),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <GoRoute>[
                GoRoute(path: '/c', redirect: (_, _) => '/c/main2'),
                GoRoute(
                  path: '/c/main1',
                  builder: (context, state) => const Text('Screen C1'),
                ),
                GoRoute(
                  path: '/c/main2',
                  builder: (context, state) => const Text('Screen C2'),
                ),
              ],
            ),
          ],
        ),
      ];

      var redirectDestinationBranchB = '/b/details1';
      await createRouter(
        routes,
        tester,
        initialLocation: '/a',
        navigatorKey: rootNavigatorKey,
        redirect: (_, state) {
          if (state.uri.toString().startsWith('/b')) {
            return redirectDestinationBranchB;
          }
          return null;
        },
      );
      expect(find.text('Screen A'), findsOneWidget);
      expect(find.text('Screen B Detail'), findsNothing);

      routeState!.goBranch(1);
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen B Detail1'), findsOneWidget);

      routeState!.goBranch(2);
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen B Detail1'), findsNothing);
      expect(find.text('Screen C2'), findsOneWidget);

      redirectDestinationBranchB = '/b/details2';
      routeState!.goBranch(1);
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen B Detail2'), findsOneWidget);
      expect(find.text('Screen C2'), findsNothing);
    });

    testWidgets('Pushed top-level route is correctly handled by StatefulShellRoute', (
      tester,
    ) async {
      final rootNavigatorKey = GlobalKey<NavigatorState>();
      final nestedNavigatorKey = GlobalKey<NavigatorState>();
      StatefulNavigationShell? routeState;

      final routes = <RouteBase>[
        // First level shell
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            routeState = navigationShell;
            return navigationShell;
          },
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              routes: <GoRoute>[
                GoRoute(
                  path: '/a',
                  builder: (context, state) => const Text('Screen A'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                // Second level / nested shell
                StatefulShellRoute.indexedStack(
                  builder:
                      (
                        context,
                        state,
                        navigationShell,
                      ) => navigationShell,
                  branches: <StatefulShellBranch>[
                    StatefulShellBranch(
                      routes: <GoRoute>[
                        GoRoute(
                          path: '/b1',
                          builder: (context, state) => const Text('Screen B1'),
                        ),
                      ],
                    ),
                    StatefulShellBranch(
                      navigatorKey: nestedNavigatorKey,
                      routes: <GoRoute>[
                        GoRoute(
                          path: '/b2',
                          builder: (context, state) => const Text('Screen B2'),
                        ),
                        GoRoute(
                          path: '/b2-modal',
                          // We pass an explicit parentNavigatorKey here, to
                          // properly test the logic in RouteBuilder, i.e.
                          // routes with parentNavigatorKeys under the shell
                          // should not be stripped.
                          parentNavigatorKey: nestedNavigatorKey,
                          builder: (context, state) => const Text('Nested Modal'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/top-modal',
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const Text('Top Modal'),
        ),
      ];

      final router = await createRouter(
        routes,
        tester,
        initialLocation: '/a',
        navigatorKey: rootNavigatorKey,
      );
      expect(find.text('Screen A'), findsOneWidget);

      routeState!.goBranch(1);
      await tester.pumpAndSettle();
      expect(find.text('Screen B1'), findsOneWidget);

      // Navigate nested (second level) shell to second branch
      router.go('/b2');
      await tester.pumpAndSettle();
      expect(find.text('Screen B2'), findsOneWidget);

      // Push route over second branch of nested (second level) shell
      router.push('/b2-modal');
      await tester.pumpAndSettle();
      expect(find.text('Nested Modal'), findsOneWidget);

      // Push top-level route while on second branch
      router.push('/top-modal');
      await tester.pumpAndSettle();
      expect(find.text('Top Modal'), findsOneWidget);

      // Return to shell and first branch
      router.go('/a');
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsOneWidget);

      // Switch to second branch, which should only contain 'Nested Modal'
      // (in the nested shell)
      routeState!.goBranch(1);
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen B1'), findsNothing);
      expect(find.text('Screen B2'), findsNothing);
      expect(find.text('Top Modal'), findsNothing);
      expect(find.text('Nested Modal'), findsOneWidget);
    });

    testWidgets(
      'Obsolete branches in StatefulShellRoute are cleaned up after route '
      'configuration change',
      // TODO(tolo): Temporarily skipped due to a bug that causes test to faiL
      skip: true,
      (tester) async {
        final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
        final statefulShellKey = GlobalKey<StatefulNavigationShellState>(debugLabel: 'shell');
        StatefulNavigationShell? routeState;
        StatefulShellBranch makeBranch(String name) => StatefulShellBranch(
          navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'branch-$name'),
          preload: true,
          initialLocation: '/$name',
          routes: <GoRoute>[
            GoRoute(
              path: '/$name',
              builder: (context, state) => Text('Screen $name'),
            ),
          ],
        );

        List<RouteBase> createRoutes(bool includeCRoute) => <RouteBase>[
          StatefulShellRoute.indexedStack(
            key: statefulShellKey,
            builder:
                (
                  context,
                  state,
                  navigationShell,
                ) {
                  routeState = navigationShell;
                  return navigationShell;
                },
            branches: <StatefulShellBranch>[
              makeBranch('a'),
              makeBranch('b'),
              if (includeCRoute) makeBranch('c'),
            ],
          ),
        ];

        final config = ValueNotifier<RoutingConfig>(RoutingConfig(routes: createRoutes(true)));
        addTearDown(config.dispose);
        await createRouterWithRoutingConfig(
          navigatorKey: rootNavigatorKey,
          config,
          tester,
          initialLocation: '/a',
          errorBuilder: (_, _) => const Text('error'),
        );
        await tester.pumpAndSettle();

        bool hasLoadedBranch(String name) => routeState!.debugLoadedBranches.any(
          (e) => e.initialLocation == '/$name',
        );

        expect(hasLoadedBranch('a'), isTrue);
        expect(hasLoadedBranch('b'), isTrue);
        expect(hasLoadedBranch('c'), isTrue);

        // Unload branch 'c' by changing the route configuration
        config.value = RoutingConfig(routes: createRoutes(false));
        await tester.pumpAndSettle();

        expect(hasLoadedBranch('a'), isTrue);
        expect(hasLoadedBranch('b'), isTrue);
        expect(hasLoadedBranch('c'), isFalse);
      },
    );
  });

  group('Imperative navigation', () {
    group('canPop', () {
      testWidgets('It should return false if Navigator.canPop() returns false.', (
        tester,
      ) async {
        final navigatorKey = GlobalKey<NavigatorState>();
        final router = GoRouter(
          initialLocation: '/',
          navigatorKey: navigatorKey,
          routes: <GoRoute>[
            GoRoute(
              path: '/',
              builder: (context, _) {
                return Scaffold(
                  body: TextButton(
                    onPressed: () => Future.sync(() {
                      navigatorKey.currentState!.push(
                        MaterialPageRoute<void>(
                          builder: (context) {
                            return const Scaffold(body: Text('pageless route'));
                          },
                        ),
                      );
                    }),
                    child: const Text('Push'),
                  ),
                );
              },
            ),
            GoRoute(path: '/a', builder: (_, _) => const DummyScreen()),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          MaterialApp.router(
            routeInformationProvider: router.routeInformationProvider,
            routeInformationParser: router.routeInformationParser,
            routerDelegate: router.routerDelegate,
          ),
        );

        expect(router.canPop(), false);

        await tester.tap(find.text('Push'));
        await tester.pumpAndSettle();

        expect(find.text('pageless route', skipOffstage: false), findsOneWidget);
        expect(router.canPop(), true);
      });

      testWidgets('It checks if ShellRoute navigators can pop', (tester) async {
        final shellNavigatorKey = GlobalKey<NavigatorState>();
        final router = GoRouter(
          initialLocation: '/a',
          routes: <RouteBase>[
            ShellRoute(
              navigatorKey: shellNavigatorKey,
              builder: (context, state, child) {
                return Scaffold(
                  appBar: AppBar(title: const Text('Shell')),
                  body: child,
                );
              },
              routes: <GoRoute>[
                GoRoute(
                  path: '/a',
                  builder: (context, _) {
                    return Scaffold(
                      body: TextButton(
                        onPressed: () => Future.sync(() {
                          shellNavigatorKey.currentState!.push(
                            MaterialPageRoute<void>(
                              builder: (context) {
                                return const Scaffold(body: Text('pageless route'));
                              },
                            ),
                          );
                        }),
                        child: const Text('Push'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          MaterialApp.router(
            routeInformationProvider: router.routeInformationProvider,
            routeInformationParser: router.routeInformationParser,
            routerDelegate: router.routerDelegate,
          ),
        );

        expect(router.canPop(), false);
        expect(find.text('Push'), findsOneWidget);

        await tester.tap(find.text('Push'));
        await tester.pumpAndSettle();

        expect(find.text('pageless route', skipOffstage: false), findsOneWidget);
        expect(router.canPop(), true);
      });

      testWidgets('It checks if StatefulShellRoute navigators can pop', (
        tester,
      ) async {
        final rootNavigatorKey = GlobalKey<NavigatorState>();
        final router = GoRouter(
          navigatorKey: rootNavigatorKey,
          initialLocation: '/a',
          routes: <RouteBase>[
            StatefulShellRoute.indexedStack(
              builder: mockStackedShellBuilder,
              branches: <StatefulShellBranch>[
                StatefulShellBranch(
                  routes: <GoRoute>[
                    GoRoute(
                      path: '/a',
                      builder: (context, _) {
                        return const Scaffold(body: Text('Screen A'));
                      },
                    ),
                  ],
                ),
                StatefulShellBranch(
                  routes: <GoRoute>[
                    GoRoute(
                      path: '/b',
                      builder: (context, _) {
                        return const Scaffold(body: Text('Screen B'));
                      },
                      routes: <RouteBase>[
                        GoRoute(
                          path: 'detail',
                          builder: (context, _) {
                            return const Scaffold(body: Text('Screen B detail'));
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          MaterialApp.router(
            routeInformationProvider: router.routeInformationProvider,
            routeInformationParser: router.routeInformationParser,
            routerDelegate: router.routerDelegate,
          ),
        );

        expect(router.canPop(), false);

        router.go('/b/detail');
        await tester.pumpAndSettle();

        expect(find.text('Screen B detail', skipOffstage: false), findsOneWidget);
        expect(router.canPop(), true);
        // Verify that it is actually the StatefulShellRoute that reports
        // canPop = true
        expect(rootNavigatorKey.currentState?.canPop(), false);
      });

      testWidgets('Pageless route should include in can pop', (tester) async {
        final root = GlobalKey<NavigatorState>(debugLabel: 'root');
        final shell = GlobalKey<NavigatorState>(debugLabel: 'shell');

        final router = GoRouter(
          navigatorKey: root,
          routes: <RouteBase>[
            ShellRoute(
              navigatorKey: shell,
              builder: (context, state, child) {
                return Scaffold(
                  body: Center(
                    child: Column(
                      children: <Widget>[
                        const Text('Shell'),
                        Expanded(child: child),
                      ],
                    ),
                  ),
                );
              },
              routes: <RouteBase>[GoRoute(path: '/', builder: (_, _) => const Text('A Screen'))],
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));

        expect(router.canPop(), isFalse);
        expect(find.text('A Screen'), findsOneWidget);
        expect(find.text('Shell'), findsOneWidget);
        showDialog<void>(context: root.currentContext!, builder: (_) => const Text('A dialog'));
        await tester.pumpAndSettle();
        expect(find.text('A dialog'), findsOneWidget);
        expect(router.canPop(), isTrue);
      });
    });

    group('pop', () {
      testWidgets('Should pop from the correct navigator when parentNavigatorKey is set', (
        tester,
      ) async {
        final root = GlobalKey<NavigatorState>(debugLabel: 'root');
        final shell = GlobalKey<NavigatorState>(debugLabel: 'shell');

        final router = GoRouter(
          initialLocation: '/a/b',
          navigatorKey: root,
          routes: <GoRoute>[
            GoRoute(
              path: '/',
              builder: (context, _) {
                return const Scaffold(body: Text('Home'));
              },
              routes: <RouteBase>[
                ShellRoute(
                  navigatorKey: shell,
                  builder: (context, state, child) {
                    return Scaffold(
                      body: Center(
                        child: Column(
                          children: <Widget>[
                            const Text('Shell'),
                            Expanded(child: child),
                          ],
                        ),
                      ),
                    );
                  },
                  routes: <RouteBase>[
                    GoRoute(
                      path: 'a',
                      builder: (_, _) => const Text('A Screen'),
                      routes: <RouteBase>[
                        GoRoute(
                          parentNavigatorKey: root,
                          path: 'b',
                          builder: (_, _) => const Text('B Screen'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          MaterialApp.router(
            routeInformationProvider: router.routeInformationProvider,
            routeInformationParser: router.routeInformationParser,
            routerDelegate: router.routerDelegate,
          ),
        );

        expect(router.canPop(), isTrue);
        expect(find.text('B Screen'), findsOneWidget);
        expect(find.text('A Screen'), findsNothing);
        expect(find.text('Shell'), findsNothing);
        expect(find.text('Home'), findsNothing);
        router.pop();
        await tester.pumpAndSettle();
        expect(find.text('A Screen'), findsOneWidget);
        expect(find.text('Shell'), findsOneWidget);
        expect(router.canPop(), isTrue);
        router.pop();
        await tester.pumpAndSettle();
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Shell'), findsNothing);
      });

      testWidgets('Should pop dialog if it is present', (tester) async {
        final root = GlobalKey<NavigatorState>(debugLabel: 'root');
        final shell = GlobalKey<NavigatorState>(debugLabel: 'shell');

        final router = GoRouter(
          initialLocation: '/a',
          navigatorKey: root,
          routes: <GoRoute>[
            GoRoute(
              path: '/',
              builder: (context, _) {
                return const Scaffold(body: Text('Home'));
              },
              routes: <RouteBase>[
                ShellRoute(
                  navigatorKey: shell,
                  builder: (context, state, child) {
                    return Scaffold(
                      body: Center(
                        child: Column(
                          children: <Widget>[
                            const Text('Shell'),
                            Expanded(child: child),
                          ],
                        ),
                      ),
                    );
                  },
                  routes: <RouteBase>[
                    GoRoute(path: 'a', builder: (_, _) => const Text('A Screen')),
                  ],
                ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));

        expect(router.canPop(), isTrue);
        expect(find.text('A Screen'), findsOneWidget);
        expect(find.text('Shell'), findsOneWidget);
        expect(find.text('Home'), findsNothing);
        final resultFuture = showDialog<bool>(
          context: root.currentContext!,
          builder: (_) => const Text('A dialog'),
        );
        await tester.pumpAndSettle();
        expect(find.text('A dialog'), findsOneWidget);
        expect(router.canPop(), isTrue);

        router.pop<bool>(true);
        await tester.pumpAndSettle();
        expect(find.text('A Screen'), findsOneWidget);
        expect(find.text('Shell'), findsOneWidget);
        expect(find.text('A dialog'), findsNothing);
        final result = await resultFuture;
        expect(result, isTrue);
      });

      testWidgets('Triggers a Hero inside a ShellRoute', (tester) async {
        final heroKey = UniqueKey();
        const kHeroTag = 'hero';

        final routes = <RouteBase>[
          ShellRoute(
            builder: (context, state, child) {
              return child;
            },
            routes: <GoRoute>[
              GoRoute(
                path: '/a',
                builder: (context, _) {
                  return Hero(
                    tag: kHeroTag,
                    child: Container(),
                    flightShuttleBuilder: (_, _, _, _, _) {
                      return Container(key: heroKey);
                    },
                  );
                },
              ),
              GoRoute(
                path: '/b',
                builder: (context, _) {
                  return Hero(tag: kHeroTag, child: Container());
                },
              ),
            ],
          ),
        ];
        final router = await createRouter(routes, tester, initialLocation: '/a');

        // check that flightShuttleBuilder widget is not yet present
        expect(find.byKey(heroKey), findsNothing);

        // start navigation
        router.go('/b');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 10));
        // check that flightShuttleBuilder widget is visible
        expect(find.byKey(heroKey), isOnstage);
        // // Waits for the animation finishes.
        await tester.pumpAndSettle();
        expect(find.byKey(heroKey), findsNothing);
      });
    });
  });

  group('of', () {
    testWidgets('It should return the go router instance of the widget tree', (
      tester,
    ) async {
      const key = Key('key');
      final routes = <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, _) => const SizedBox(key: key),
        ),
      ];

      final router = await createRouter(routes, tester);
      final context = tester.element(find.byKey(key));
      final foundRouter = GoRouter.of(context);
      expect(foundRouter, router);
    });

    testWidgets('It should throw if there is no go router in the widget tree', (
      tester,
    ) async {
      const key = Key('key');
      await tester.pumpWidget(const SizedBox(key: key));

      final context = tester.element(find.byKey(key));
      expect(() => GoRouter.of(context), throwsA(anything));
    });
  });

  group('maybeOf', () {
    testWidgets('It should return the go router instance of the widget tree', (
      tester,
    ) async {
      const key = Key('key');
      final routes = <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, _) => const SizedBox(key: key),
        ),
      ];

      final router = await createRouter(routes, tester);
      final context = tester.element(find.byKey(key));
      final foundRouter = GoRouter.maybeOf(context);
      expect(foundRouter, router);
    });

    testWidgets('It should return null if there is no go router in the widget tree', (
      tester,
    ) async {
      const key = Key('key');
      await tester.pumpWidget(const SizedBox(key: key));

      final context = tester.element(find.byKey(key));
      expect(GoRouter.maybeOf(context), isNull);
    });
  });

  group('state restoration', () {
    testWidgets('Restores state correctly', (tester) async {
      final statefulWidgetKeyA = GlobalKey<DummyRestorableStatefulWidgetState>();

      final routes = <RouteBase>[
        GoRoute(
          path: '/a',
          pageBuilder: createPageBuilder(restorationId: 'screenA', child: const Text('Screen A')),
          routes: <RouteBase>[
            GoRoute(
              path: 'detail',
              pageBuilder: createPageBuilder(
                restorationId: 'screenADetail',
                child: Column(
                  children: <Widget>[
                    const Text('Screen A Detail'),
                    DummyRestorableStatefulWidget(
                      key: statefulWidgetKeyA,
                      restorationId: 'counterA',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ];

      await createRouter(routes, tester, initialLocation: '/a/detail', restorationScopeId: 'test');
      await tester.pumpAndSettle();
      statefulWidgetKeyA.currentState?.increment();
      expect(statefulWidgetKeyA.currentState?.counter, equals(1));
      await tester.pumpAndSettle(); // Give state change time to persist

      await tester.restartAndRestore();

      await tester.pumpAndSettle();
      expect(find.text('Screen A Detail'), findsOneWidget);
      expect(statefulWidgetKeyA.currentState?.counter, equals(1));
    });

    testWidgets('Restores state of branches in StatefulShellRoute correctly', (
      tester,
    ) async {
      final rootNavigatorKey = GlobalKey<NavigatorState>();
      final statefulWidgetKeyA = GlobalKey<DummyRestorableStatefulWidgetState>();
      final statefulWidgetKeyB = GlobalKey<DummyRestorableStatefulWidgetState>();
      final statefulWidgetKeyC = GlobalKey<DummyRestorableStatefulWidgetState>();
      StatefulNavigationShell? routeState;

      final routes = <RouteBase>[
        StatefulShellRoute.indexedStack(
          restorationScopeId: 'shell',
          pageBuilder: (context, state, navigationShell) {
            routeState = navigationShell;
            return MaterialPage<dynamic>(restorationId: 'shellWidget', child: navigationShell);
          },
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              restorationScopeId: 'branchA',
              routes: <GoRoute>[
                GoRoute(
                  path: '/a',
                  pageBuilder: createPageBuilder(
                    restorationId: 'screenA',
                    child: const Text('Screen A'),
                  ),
                  routes: <RouteBase>[
                    GoRoute(
                      path: 'detailA',
                      pageBuilder: createPageBuilder(
                        restorationId: 'screenADetail',
                        child: Column(
                          children: <Widget>[
                            const Text('Screen A Detail'),
                            DummyRestorableStatefulWidget(
                              key: statefulWidgetKeyA,
                              restorationId: 'counterA',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              restorationScopeId: 'branchB',
              routes: <GoRoute>[
                GoRoute(
                  path: '/b',
                  pageBuilder: createPageBuilder(
                    restorationId: 'screenB',
                    child: const Text('Screen B'),
                  ),
                  routes: <RouteBase>[
                    GoRoute(
                      path: 'detailB',
                      pageBuilder: createPageBuilder(
                        restorationId: 'screenBDetail',
                        child: Column(
                          children: <Widget>[
                            const Text('Screen B Detail'),
                            DummyRestorableStatefulWidget(
                              key: statefulWidgetKeyB,
                              restorationId: 'counterB',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <GoRoute>[
                GoRoute(
                  path: '/c',
                  pageBuilder: createPageBuilder(
                    restorationId: 'screenC',
                    child: const Text('Screen C'),
                  ),
                  routes: <RouteBase>[
                    GoRoute(
                      path: 'detailC',
                      pageBuilder: createPageBuilder(
                        restorationId: 'screenCDetail',
                        child: Column(
                          children: <Widget>[
                            const Text('Screen C Detail'),
                            DummyRestorableStatefulWidget(
                              key: statefulWidgetKeyC,
                              restorationId: 'counterC',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ];

      final router = await createRouter(
        routes,
        tester,
        initialLocation: '/a/detailA',
        navigatorKey: rootNavigatorKey,
        restorationScopeId: 'test',
      );
      await tester.pumpAndSettle();
      statefulWidgetKeyA.currentState?.increment();
      expect(statefulWidgetKeyA.currentState?.counter, equals(1));

      router.go('/b/detailB');
      await tester.pumpAndSettle();
      statefulWidgetKeyB.currentState?.increment();
      expect(statefulWidgetKeyB.currentState?.counter, equals(1));

      router.go('/c/detailC');
      await tester.pumpAndSettle();
      statefulWidgetKeyC.currentState?.increment();
      expect(statefulWidgetKeyC.currentState?.counter, equals(1));

      routeState!.goBranch(0);
      await tester.pumpAndSettle();
      expect(find.text('Screen A Detail'), findsOneWidget);

      await tester.restartAndRestore();

      await tester.pumpAndSettle();
      expect(find.text('Screen A Detail'), findsOneWidget);
      expect(statefulWidgetKeyA.currentState?.counter, equals(1));

      routeState!.goBranch(1);
      await tester.pumpAndSettle();
      expect(find.text('Screen B Detail'), findsOneWidget);
      expect(statefulWidgetKeyB.currentState?.counter, equals(1));

      routeState!.goBranch(2);
      await tester.pumpAndSettle();
      expect(find.text('Screen C Detail'), findsOneWidget);
      // State of branch C should not have been restored
      expect(statefulWidgetKeyC.currentState?.counter, equals(0));
    });

    testWidgets('Restores state of imperative routes in StatefulShellRoute correctly', (
      tester,
    ) async {
      final rootNavigatorKey = GlobalKey<NavigatorState>();
      final statefulWidgetKeyA = GlobalKey<DummyRestorableStatefulWidgetState>();
      final statefulWidgetKeyB = GlobalKey<DummyRestorableStatefulWidgetState>();
      StatefulNavigationShell? routeStateRoot;
      StatefulNavigationShell? routeStateNested;

      final routes = <RouteBase>[
        StatefulShellRoute.indexedStack(
          restorationScopeId: 'shell',
          pageBuilder: (context, state, navigationShell) {
            routeStateRoot = navigationShell;
            return MaterialPage<dynamic>(restorationId: 'shellWidget', child: navigationShell);
          },
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              restorationScopeId: 'branchA',
              routes: <GoRoute>[
                GoRoute(
                  path: '/a',
                  pageBuilder: createPageBuilder(
                    restorationId: 'screenA',
                    child: const Text('Screen A'),
                  ),
                  routes: <RouteBase>[
                    GoRoute(
                      path: 'detailA',
                      pageBuilder: createPageBuilder(
                        restorationId: 'screenADetail',
                        child: Column(
                          children: <Widget>[
                            const Text('Screen A Detail'),
                            DummyRestorableStatefulWidget(
                              key: statefulWidgetKeyA,
                              restorationId: 'counterA',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              restorationScopeId: 'branchB',
              routes: <RouteBase>[
                StatefulShellRoute.indexedStack(
                  restorationScopeId: 'branchB-nested-shell',
                  pageBuilder:
                      (
                        context,
                        state,
                        navigationShell,
                      ) {
                        routeStateNested = navigationShell;
                        return MaterialPage<dynamic>(
                          restorationId: 'shellWidget-nested',
                          child: navigationShell,
                        );
                      },
                  branches: <StatefulShellBranch>[
                    StatefulShellBranch(
                      restorationScopeId: 'branchB-nested',
                      routes: <GoRoute>[
                        GoRoute(
                          path: '/b',
                          pageBuilder: createPageBuilder(
                            restorationId: 'screenB',
                            child: const Text('Screen B'),
                          ),
                          routes: <RouteBase>[
                            GoRoute(
                              path: 'detailB',
                              pageBuilder: createPageBuilder(
                                restorationId: 'screenBDetail',
                                child: Column(
                                  children: <Widget>[
                                    const Text('Screen B Detail'),
                                    DummyRestorableStatefulWidget(
                                      key: statefulWidgetKeyB,
                                      restorationId: 'counterB',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    StatefulShellBranch(
                      restorationScopeId: 'branchC-nested',
                      routes: <GoRoute>[
                        GoRoute(
                          path: '/c',
                          pageBuilder: createPageBuilder(
                            restorationId: 'screenC',
                            child: const Text('Screen C'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ];

      final router = await createRouter(
        routes,
        tester,
        initialLocation: '/a/detailA',
        navigatorKey: rootNavigatorKey,
        restorationScopeId: 'test',
      );
      await tester.pumpAndSettle();
      statefulWidgetKeyA.currentState?.increment();
      expect(statefulWidgetKeyA.currentState?.counter, equals(1));

      routeStateRoot!.goBranch(1);
      await tester.pumpAndSettle();

      router.go('/b/detailB');
      await tester.pumpAndSettle();
      statefulWidgetKeyB.currentState?.increment();
      expect(statefulWidgetKeyB.currentState?.counter, equals(1));

      routeStateRoot!.goBranch(0);
      await tester.pumpAndSettle();
      expect(find.text('Screen A Detail'), findsOneWidget);
      expect(find.text('Screen B'), findsNothing);
      expect(find.text('Screen B Pushed Detail'), findsNothing);

      await tester.restartAndRestore();

      await tester.pumpAndSettle();
      expect(find.text('Screen A Detail'), findsOneWidget);
      expect(find.text('Screen B'), findsNothing);
      expect(find.text('Screen B Pushed Detail'), findsNothing);
      expect(statefulWidgetKeyA.currentState?.counter, equals(1));

      routeStateRoot!.goBranch(1);
      await tester.pumpAndSettle();
      expect(find.text('Screen A Detail'), findsNothing);
      expect(find.text('Screen B'), findsNothing);
      expect(find.text('Screen B Detail'), findsOneWidget);
      expect(statefulWidgetKeyB.currentState?.counter, equals(1));

      routeStateNested!.goBranch(1);
      await tester.pumpAndSettle();
      routeStateNested!.goBranch(0);
      await tester.pumpAndSettle();

      expect(find.text('Screen B Detail'), findsOneWidget);
      expect(statefulWidgetKeyB.currentState?.counter, equals(1));
    });
  });

  ///Regression tests for https://github.com/flutter/flutter/issues/132557
  group('overridePlatformDefaultLocation', () {
    test('No initial location provided', () {
      expect(
        () => GoRouter(
          overridePlatformDefaultLocation: true,
          routes: <RouteBase>[
            GoRoute(
              path: '/a',
              builder: (context, state) => const Placeholder(),
            ),
            GoRoute(
              path: '/b',
              builder: (context, state) => const Placeholder(),
            ),
          ],
        ),
        throwsA(const TypeMatcher<AssertionError>()),
      );
    });
    testWidgets('Test override using routeInformationProvider', (tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = '/some-route';
      final platformRoute = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
      const expectedInitialRoute = '/kyc';
      expect(platformRoute != expectedInitialRoute, isTrue);

      final routes = <RouteBase>[
        GoRoute(
          path: '/abc',
          builder: (context, state) => const Placeholder(),
        ),
        GoRoute(
          path: '/bcd',
          builder: (context, state) => const Placeholder(),
        ),
      ];

      final router = await createRouter(
        routes,
        tester,
        overridePlatformDefaultLocation: true,
        initialLocation: expectedInitialRoute,
      );
      expect(router.routeInformationProvider.value.uri.toString(), expectedInitialRoute);
    });
  });

  testWidgets('test the pathParameters in redirect when the Router is recreated', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/foo',
      routes: <RouteBase>[
        GoRoute(
          path: '/foo',
          builder: dummy,
          routes: <GoRoute>[
            GoRoute(
              path: ':id',
              redirect: (_, state) {
                expect(state.pathParameters['id'], isNotNull);
                return null;
              },
              builder: dummy,
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(key: UniqueKey(), routerConfig: router));
    router.push('/foo/123');
    await tester.pump(); // wait reportRouteInformation
    await tester.pumpWidget(MaterialApp.router(key: UniqueKey(), routerConfig: router));
  });

  testWidgets('should return the current GoRouterState when router.currentState is called', (
    tester,
  ) async {
    final routes = <RouteBase>[
      GoRoute(
        name: 'home',
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        name: 'books',
        path: '/books',
        builder: (context, state) => const Text('books'),
      ),
      GoRoute(
        name: 'boats',
        path: '/boats',
        builder: (context, state) => const Text('boats'),
      ),
      ShellRoute(
        builder: (context, state, child) => child,
        routes: <RouteBase>[
          GoRoute(
            name: 'tulips',
            path: '/tulips',
            builder: (context, state) => const Text('tulips'),
          ),
        ],
      ),
    ];

    final router = await createRouter(routes, tester);
    await tester.pumpAndSettle();

    GoRouterState? state = router.state;
    expect(state.name, 'home');
    expect(state.fullPath, '/');

    router.go('/books');
    await tester.pumpAndSettle();
    state = router.state;
    expect(state.name, 'books');
    expect(state.fullPath, '/books');

    router.push('/boats');
    await tester.pumpAndSettle();
    state = router.state;
    expect(state.name, 'boats');
    expect(state.fullPath, '/boats');

    router.pop();
    await tester.pumpAndSettle();
    state = router.state;
    expect(state.name, 'books');
    expect(state.fullPath, '/books');

    router.go('/tulips');
    await tester.pumpAndSettle();
    state = router.state;
    expect(state.name, 'tulips');
    expect(state.fullPath, '/tulips');

    router.go('/books');
    router.push('/tulips');
    await tester.pumpAndSettle();
    state = router.state;
    expect(state.name, 'tulips');
    expect(state.fullPath, '/tulips');
  });

  testWidgets('should allow route paths without leading /', (tester) async {
    final routes = <GoRoute>[
      GoRoute(
        path: '/', // root cannot be empty (existing assert)
        builder: (context, state) => const HomeScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'child-route',
            builder: (context, state) => const Text('/child-route'),
            routes: <RouteBase>[
              GoRoute(
                path: 'grand-child-route',
                builder: (context, state) => const Text('/grand-child-route'),
              ),
              GoRoute(
                path: 'redirected-grand-child-route',
                redirect: (context, state) => '/child-route',
              ),
            ],
          ),
        ],
      ),
    ];

    final router = await createRouter(
      routes,
      tester,
      initialLocation: '/child-route/grand-child-route',
    );
    var matches = router.routerDelegate.currentConfiguration;
    expect(matches.matches, hasLength(3));
    expect(matches.uri.toString(), '/child-route/grand-child-route');
    expect(find.text('/grand-child-route'), findsOneWidget);

    router.go('/child-route/redirected-grand-child-route');
    await tester.pumpAndSettle();
    matches = router.routerDelegate.currentConfiguration;
    expect(matches.matches, hasLength(2));
    expect(matches.uri.toString(), '/child-route');
    expect(find.text('/child-route'), findsOneWidget);
  });

  testWidgets('should allow route paths with leading /', (tester) async {
    final routes = <GoRoute>[
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: '/child-route',
            builder: (context, state) => const Text('/child-route'),
            routes: <RouteBase>[
              GoRoute(
                path: '/grand-child-route',
                builder: (context, state) => const Text('/grand-child-route'),
              ),
              GoRoute(
                path: '/redirected-grand-child-route',
                redirect: (context, state) => '/child-route',
              ),
            ],
          ),
        ],
      ),
    ];

    final router = await createRouter(
      routes,
      tester,
      initialLocation: '/child-route/grand-child-route',
    );
    var matches = router.routerDelegate.currentConfiguration;
    expect(matches.matches, hasLength(3));
    expect(matches.uri.toString(), '/child-route/grand-child-route');
    expect(find.text('/grand-child-route'), findsOneWidget);

    router.go('/child-route/redirected-grand-child-route');
    await tester.pumpAndSettle();
    matches = router.routerDelegate.currentConfiguration;
    expect(matches.matches, hasLength(2));
    expect(matches.uri.toString(), '/child-route');
    expect(find.text('/child-route'), findsOneWidget);
  });
}

class TestInheritedNotifier extends InheritedNotifier<ValueNotifier<String>> {
  const TestInheritedNotifier({super.key, required super.notifier, required super.child});
}

class IsRouteUpdateCall extends Matcher {
  const IsRouteUpdateCall(this.uri, this.replace, this.state);

  final String uri;
  final bool replace;
  final Object? state;

  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) {
    if (item is! MethodCall) {
      return false;
    }
    if (item.method != 'routeInformationUpdated') {
      return false;
    }
    if (item.arguments is! Map) {
      return false;
    }
    final arguments = item.arguments as Map<String, dynamic>;
    // TODO(chunhtai): update this when minimum flutter version includes
    // https://github.com/flutter/flutter/pull/119968.
    // https://github.com/flutter/flutter/issues/124045.
    if (arguments['uri'] != uri && arguments['location'] != uri) {
      return false;
    }

    if (!const DeepCollectionEquality().equals(arguments['state'], state)) {
      return false;
    }
    return arguments['replace'] == replace;
  }

  @override
  Description describe(Description description) {
    return description
        .add("has method name: 'routeInformationUpdated'")
        .add(' with uri: ')
        .addDescriptionOf(uri)
        .add(' with state: ')
        .addDescriptionOf(state)
        .add(' with replace: ')
        .addDescriptionOf(replace);
  }
}
