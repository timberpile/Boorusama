// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'test_helpers.dart';

// Tests for chained redirect behavior.
//
// These tests validate that top-level redirects are fully re-evaluated
// when they produce a new location, and that route-level redirects
// trigger top-level re-evaluation on the new location.
void main() {
  group('chained redirects', () {
    testWidgets('top-level redirect chain', (tester) async {
      // Regression test for https://github.com/flutter/flutter/issues/178984
      //
      // Top-level redirect: / -> /a -> /b
      // Expected: navigating to / should end up at /b
      final redirectLog = <String>[];
      final router = await createRouter(
        <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/a',
            builder: (context, state) => const Page1Screen(),
          ),
          GoRoute(
            path: '/b',
            builder: (context, state) => const Page2Screen(),
          ),
        ],
        tester,
        redirect: (context, state) {
          redirectLog.add(state.matchedLocation);
          if (state.matchedLocation == '/') {
            return '/a';
          }
          if (state.matchedLocation == '/a') {
            return '/b';
          }
          return null;
        },
      );

      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/b');
      expect(find.byType(Page2Screen), findsOneWidget);
      // Redirect evaluated for /, /a, and /b.
      expect(redirectLog, <String>['/', '/a', '/b']);
    });

    testWidgets('top-level redirect chain with three hops', (tester) async {
      final router = await createRouter(
        <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/step1',
            builder: (context, state) => const DummyScreen(),
          ),
          GoRoute(
            path: '/step2',
            builder: (context, state) => const DummyScreen(),
          ),
          GoRoute(
            path: '/step3',
            builder: (context, state) => const LoginScreen(),
          ),
        ],
        tester,
        redirect: (context, state) {
          return switch (state.matchedLocation) {
            '/' => '/step1',
            '/step1' => '/step2',
            '/step2' => '/step3',
            _ => null,
          };
        },
      );

      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/step3');
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('async top-level redirect chain', (tester) async {
      final router = await createRouter(
        <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/a',
            builder: (context, state) => const DummyScreen(),
          ),
          GoRoute(
            path: '/b',
            builder: (context, state) => const LoginScreen(),
          ),
        ],
        tester,
        redirect: (context, state) async {
          // Simulate an async operation (e.g., checking auth status).
          await Future<void>.delayed(Duration.zero);
          if (state.matchedLocation == '/') {
            return '/a';
          }
          if (state.matchedLocation == '/a') {
            return '/b';
          }
          return null;
        },
      );

      await tester.pumpAndSettle();

      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/b');
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('top-level redirect chain loop detection', (tester) async {
      // Redirect loop: / -> /a -> /b -> /a (loop)
      await createRouter(
        <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/a',
            builder: (context, state) => const DummyScreen(),
          ),
          GoRoute(
            path: '/b',
            builder: (context, state) => const DummyScreen(),
          ),
        ],
        tester,
        redirect: (context, state) {
          return switch (state.matchedLocation) {
            '/' => '/a',
            '/a' => '/b',
            '/b' => '/a', // Loop: /a -> /b -> /a
            _ => null,
          };
        },
        errorBuilder: (context, state) => TestErrorScreen(state.error!),
      );

      expect(find.byType(TestErrorScreen), findsOneWidget);
      final screen = tester.widget<TestErrorScreen>(find.byType(TestErrorScreen));
      expect((screen.ex as GoException).message, startsWith('redirect loop detected'));
    });

    testWidgets('top-level redirect chain loop to initial location', (tester) async {
      // Redirect loop returning to initial location: / -> /a -> /
      await createRouter(
        <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/a',
            builder: (context, state) => const DummyScreen(),
          ),
        ],
        tester,
        redirect: (context, state) {
          return switch (state.matchedLocation) {
            '/' => '/a',
            '/a' => '/', // Loop back to initial.
            _ => null,
          };
        },
        errorBuilder: (context, state) => TestErrorScreen(state.error!),
      );

      expect(find.byType(TestErrorScreen), findsOneWidget);
      final screen = tester.widget<TestErrorScreen>(find.byType(TestErrorScreen));
      expect((screen.ex as GoException).message, startsWith('redirect loop detected'));
    });

    testWidgets('top-level redirect chain into route-level redirect', (tester) async {
      // Top-level: / -> /intermediate
      // Route-level on /intermediate: /intermediate -> /final
      final router = await createRouter(
        <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/intermediate',
            builder: (context, state) => const DummyScreen(),
            redirect: (context, state) => '/final',
          ),
          GoRoute(
            path: '/final',
            builder: (context, state) => const LoginScreen(),
          ),
        ],
        tester,
        redirect: (context, state) {
          if (state.matchedLocation == '/') {
            return '/intermediate';
          }
          return null;
        },
      );

      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/final');
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('route-level redirect triggers top-level redirect', (tester) async {
      // Route-level on /src: /src -> /dst
      // Top-level: /dst -> /final
      final topRedirectLog = <String>[];
      final router = await createRouter(
        <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
            routes: <RouteBase>[
              GoRoute(
                path: 'src',
                builder: (context, state) => const DummyScreen(),
                redirect: (context, state) => '/dst',
              ),
            ],
          ),
          GoRoute(
            path: '/dst',
            builder: (context, state) => const DummyScreen(),
          ),
          GoRoute(
            path: '/final',
            builder: (context, state) => const LoginScreen(),
          ),
        ],
        tester,
        initialLocation: '/src',
        redirect: (context, state) {
          topRedirectLog.add(state.matchedLocation);
          if (state.matchedLocation == '/dst') {
            return '/final';
          }
          return null;
        },
      );

      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/final');
      expect(find.byType(LoginScreen), findsOneWidget);
      // Top-level redirect was evaluated on /dst (after route-level redirect).
      expect(topRedirectLog, contains('/dst'));
    });

    testWidgets('top-level redirect returns null after first redirect', (
      tester,
    ) async {
      // The most common pattern: single redirect, then null on re-evaluation.
      var callCount = 0;
      final router = await createRouter(
        <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) => const LoginScreen(),
          ),
        ],
        tester,
        redirect: (context, state) {
          callCount++;
          if (state.matchedLocation == '/') {
            return '/login';
          }
          return null;
        },
      );

      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/login');
      expect(find.byType(LoginScreen), findsOneWidget);
      // Redirect is called twice: once for /, once for /login.
      expect(callCount, 2);
    });

    testWidgets('top-level redirect chain respects redirect limit', (tester) async {
      // Endless chain: /0 -> /1 -> /2 -> ... with a low limit.
      await createRouter(
        <RouteBase>[
          for (int i = 0; i <= 20; i++)
            GoRoute(
              path: '/$i',
              builder: (context, state) => const DummyScreen(),
            ),
        ],
        tester,
        initialLocation: '/0',
        redirect: (context, state) {
          final match = RegExp(r'^/(\d+)$').firstMatch(state.matchedLocation);
          if (match != null) {
            final current = int.parse(match.group(1)!);
            return '/${current + 1}';
          }
          return null;
        },
        errorBuilder: (context, state) => TestErrorScreen(state.error!),
      );

      expect(find.byType(TestErrorScreen), findsOneWidget);
    });

    testWidgets('top-level redirect chain succeeds at exact redirect limit', (
      tester,
    ) async {
      // Chain of 2 redirects: / -> /a -> /b. With limit=2, this is exactly
      // at the boundary (2 entries added to redirectHistory).
      final router = await createRouter(
        <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/a',
            builder: (context, state) => const DummyScreen(),
          ),
          GoRoute(
            path: '/b',
            builder: (context, state) => const LoginScreen(),
          ),
        ],
        tester,
        redirect: (context, state) {
          return switch (state.matchedLocation) {
            '/' => '/a',
            '/a' => '/b',
            _ => null,
          };
        },
        redirectLimit: 2,
      );

      // Exactly 2 redirects with limit=2 should succeed.
      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/b');
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('top-level redirect chain fails when exceeding redirect limit', (
      tester,
    ) async {
      // Chain of 2 redirects: / -> /a -> /b. With limit=1, the second
      // redirect exceeds the limit and should error.
      await createRouter(
        <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/a',
            builder: (context, state) => const DummyScreen(),
          ),
          GoRoute(
            path: '/b',
            builder: (context, state) => const LoginScreen(),
          ),
        ],
        tester,
        redirect: (context, state) {
          return switch (state.matchedLocation) {
            '/' => '/a',
            '/a' => '/b',
            _ => null,
          };
        },
        redirectLimit: 1,
        errorBuilder: (context, state) => TestErrorScreen(state.error!),
      );

      // 2 redirects with limit=1 should error.
      expect(find.byType(TestErrorScreen), findsOneWidget);
      final screen = tester.widget<TestErrorScreen>(find.byType(TestErrorScreen));
      expect((screen.ex as GoException).message, startsWith('too many redirects'));
    });

    testWidgets('top-level and route-level redirects share redirect limit', (
      tester,
    ) async {
      // Top-level: / -> /a (1 redirect)
      // Route-level on /a: /a -> /b (1 redirect)
      // Route-level on /b: /b -> /c (1 redirect)
      // Total: 3 redirects, limit=2 → should error.
      await createRouter(
        <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/a',
            builder: (context, state) => const DummyScreen(),
            redirect: (context, state) => '/b',
          ),
          GoRoute(
            path: '/b',
            builder: (context, state) => const DummyScreen(),
            redirect: (context, state) => '/c',
          ),
          GoRoute(
            path: '/c',
            builder: (context, state) => const LoginScreen(),
          ),
        ],
        tester,
        redirect: (context, state) {
          if (state.matchedLocation == '/') {
            return '/a';
          }
          return null;
        },
        redirectLimit: 2,
        errorBuilder: (context, state) => TestErrorScreen(state.error!),
      );

      // Combined chain of 3 redirects exceeds the shared limit of 2.
      expect(find.byType(TestErrorScreen), findsOneWidget);
      final screen = tester.widget<TestErrorScreen>(find.byType(TestErrorScreen));
      expect((screen.ex as GoException).message, startsWith('too many redirects'));
    });

    testWidgets('async top-level redirect chain loop detection', (tester) async {
      // Async redirect loop: / -> /a -> /b -> /a (loop)
      await createRouter(
        <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/a',
            builder: (context, state) => const DummyScreen(),
          ),
          GoRoute(
            path: '/b',
            builder: (context, state) => const DummyScreen(),
          ),
        ],
        tester,
        redirect: (context, state) async {
          await Future<void>.delayed(Duration.zero);
          return switch (state.matchedLocation) {
            '/' => '/a',
            '/a' => '/b',
            '/b' => '/a', // Loop
            _ => null,
          };
        },
        errorBuilder: (context, state) => TestErrorScreen(state.error!),
      );

      await tester.pumpAndSettle();

      expect(find.byType(TestErrorScreen), findsOneWidget);
      final screen = tester.widget<TestErrorScreen>(find.byType(TestErrorScreen));
      expect((screen.ex as GoException).message, startsWith('redirect loop detected'));
    });

    testWidgets('async top-level redirect into route-level redirect', (tester) async {
      // Async top-level: / -> /mid (async)
      // Route-level on /mid: /mid -> /final (sync)
      // Exercises the async boundary between top-level and route-level
      // processing, and verifies route-level uses the post-top-level match.
      final router = await createRouter(
        <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/mid',
            builder: (context, state) => const DummyScreen(),
            redirect: (context, state) => '/final',
          ),
          GoRoute(
            path: '/final',
            builder: (context, state) => const LoginScreen(),
          ),
        ],
        tester,
        redirect: (context, state) async {
          await Future<void>.delayed(Duration.zero);
          if (state.matchedLocation == '/') {
            return '/mid';
          }
          return null;
        },
      );

      await tester.pumpAndSettle();

      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/final');
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('async route-level redirect into sync top-level chain', (
      tester,
    ) async {
      // Route-level on /src: /src -> /dst (async)
      // Top-level: /dst -> /final (sync)
      final router = await createRouter(
        <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
            routes: <RouteBase>[
              GoRoute(
                path: 'src',
                builder: (context, state) => const DummyScreen(),
                redirect: (context, state) async {
                  await Future<void>.delayed(Duration.zero);
                  return '/dst';
                },
              ),
            ],
          ),
          GoRoute(
            path: '/dst',
            builder: (context, state) => const DummyScreen(),
          ),
          GoRoute(
            path: '/final',
            builder: (context, state) => const LoginScreen(),
          ),
        ],
        tester,
        initialLocation: '/src',
        redirect: (context, state) {
          if (state.matchedLocation == '/dst') {
            return '/final';
          }
          return null;
        },
      );

      await tester.pumpAndSettle();

      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/final');
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('sync route-level redirect into async top-level chain', (
      tester,
    ) async {
      // Route-level on /src: /src -> /dst (sync)
      // Top-level: /dst -> /final (async)
      final router = await createRouter(
        <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
            routes: <RouteBase>[
              GoRoute(
                path: 'src',
                builder: (context, state) => const DummyScreen(),
                redirect: (context, state) => '/dst',
              ),
            ],
          ),
          GoRoute(
            path: '/dst',
            builder: (context, state) => const DummyScreen(),
          ),
          GoRoute(
            path: '/final',
            builder: (context, state) => const LoginScreen(),
          ),
        ],
        tester,
        initialLocation: '/src',
        redirect: (context, state) async {
          await Future<void>.delayed(Duration.zero);
          if (state.matchedLocation == '/dst') {
            return '/final';
          }
          return null;
        },
      );

      await tester.pumpAndSettle();

      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/final');
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('context disposal during async top-level redirect does not crash', (
      tester,
    ) async {
      // Simulate context disposal while an async top-level redirect is
      // in flight. The router should handle this gracefully — not navigate
      // to /target after the context is unmounted.
      final redirectStarted = Completer<void>();
      final proceedRedirect = Completer<void>();

      final router = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/target',
            builder: (context, state) => const LoginScreen(),
          ),
        ],
        redirect: (context, state) async {
          if (state.matchedLocation == '/') {
            redirectStarted.complete();
            await proceedRedirect.future;
            return '/target';
          }
          return null;
        },
        errorBuilder: (context, state) => TestErrorScreen(state.error!),
      );
      addTearDown(router.dispose);

      // Mount the router.
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();

      // Wait for the redirect to start.
      await redirectStarted.future;

      // Unmount the MaterialApp.router, which disposes the router context.
      await tester.pumpWidget(const SizedBox.shrink());

      // Let the redirect complete after context is unmounted.
      proceedRedirect.complete();
      await tester.pumpAndSettle();

      // The router should NOT have navigated to /target.
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('context disposal during async route-level redirect does not crash', (
      tester,
    ) async {
      // Same as above but for route-level async redirects.
      final redirectStarted = Completer<void>();
      final proceedRedirect = Completer<void>();

      final router = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
            redirect: (context, state) async {
              redirectStarted.complete();
              await proceedRedirect.future;
              return '/target';
            },
          ),
          GoRoute(
            path: '/target',
            builder: (context, state) => const LoginScreen(),
          ),
        ],
        errorBuilder: (context, state) => TestErrorScreen(state.error!),
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();

      await redirectStarted.future;

      // Unmount the MaterialApp.router.
      await tester.pumpWidget(const SizedBox.shrink());

      // Let the redirect complete after context is unmounted.
      proceedRedirect.complete();
      await tester.pumpAndSettle();

      // The router should NOT have navigated to /target.
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('top-level redirect chain works with router.go()', (tester) async {
      // Start at /, no redirect from /. Navigate to /a which chains to /c.
      final router = await createRouter(
        <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/a',
            builder: (context, state) => const DummyScreen(),
          ),
          GoRoute(
            path: '/b',
            builder: (context, state) => const Page1Screen(),
          ),
          GoRoute(
            path: '/c',
            builder: (context, state) => const LoginScreen(),
          ),
        ],
        tester,
        redirect: (context, state) {
          if (state.matchedLocation == '/a') {
            return '/b';
          }
          if (state.matchedLocation == '/b') {
            return '/c';
          }
          return null;
        },
      );

      // Initial location is / (no redirect for /).
      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/');
      expect(find.byType(HomeScreen), findsOneWidget);

      // Navigate to /a — should chain /a -> /b -> /c.
      router.go('/a');
      await tester.pumpAndSettle();

      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/c');
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });
}
