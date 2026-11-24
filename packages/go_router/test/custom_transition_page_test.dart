// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('CustomTransitionPage builds its child using transitionsBuilder', (
    tester,
  ) async {
    const child = HomeScreen();
    final transition = CustomTransitionPage<void>(
      transitionsBuilder: expectAsync4((_, _, _, child) => child),
      child: child,
    );
    final router = GoRouter(
      routes: <GoRoute>[GoRoute(path: '/', pageBuilder: (_, _) => transition)],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router, title: 'GoRouter Example'));
    expect(find.byWidget(child), findsOneWidget);
  });

  testWidgets('NoTransitionPage does not apply any transition', (tester) async {
    final showHomeValueNotifier = ValueNotifier<bool>(false);
    addTearDown(showHomeValueNotifier.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: showHomeValueNotifier,
          builder: (_, showHome, _) {
            return Navigator(
              pages: <Page<void>>[
                const NoTransitionPage<void>(child: LoginScreen()),
                if (showHome) const NoTransitionPage<void>(child: HomeScreen()),
              ],
              onDidRemovePage: (_) {},
            );
          },
        ),
      ),
    );

    final homeScreenFinder = find.byType(HomeScreen);

    expect(homeScreenFinder, findsNothing);

    showHomeValueNotifier.value = true;

    await tester.pump();

    expect(homeScreenFinder, findsOneWidget);

    await tester.pumpAndSettle();

    showHomeValueNotifier.value = false;

    await tester.pump();

    expect(homeScreenFinder, findsNothing);

    await tester.pumpAndSettle();
  });

  testWidgets('NoTransitionPage does not apply any reverse transition', (
    tester,
  ) async {
    final showHomeValueNotifier = ValueNotifier<bool>(true);
    addTearDown(showHomeValueNotifier.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: showHomeValueNotifier,
          builder: (_, showHome, _) {
            return Navigator(
              pages: <Page<void>>[
                const NoTransitionPage<void>(child: LoginScreen()),
                if (showHome) const NoTransitionPage<void>(child: HomeScreen()),
              ],
              onDidRemovePage: (_) {},
            );
          },
        ),
      ),
    );

    final homeScreenFinder = find.byType(HomeScreen);

    showHomeValueNotifier.value = false;

    await tester.pump();

    expect(homeScreenFinder, findsNothing);
  });

  testWidgets('Dismiss a screen by tapping a modal barrier', (tester) async {
    const homeKey = ValueKey<String>('home');
    const dismissibleModalKey = ValueKey<String>('dismissibleModal');

    final router = GoRouter(
      routes: <GoRoute>[
        GoRoute(
          path: '/',
          builder: (_, _) => const HomeScreen(key: homeKey),
        ),
        GoRoute(
          path: '/dismissible-modal',
          pageBuilder: (_, state) => CustomTransitionPage<void>(
            key: state.pageKey,
            barrierDismissible: true,
            transitionsBuilder: (_, _, _, child) => child,
            child: const DismissibleModal(key: dismissibleModalKey),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.byKey(homeKey), findsOneWidget);
    router.push('/dismissible-modal');
    await tester.pumpAndSettle();
    expect(find.byKey(dismissibleModalKey), findsOneWidget);
    await tester.tapAt(const Offset(50, 50));
    await tester.pumpAndSettle();
    expect(find.byKey(homeKey), findsOneWidget);
  });

  testWidgets('transitionDuration and reverseTransitionDuration is different', (
    tester,
  ) async {
    const homeKey = ValueKey<String>('home');
    const loginKey = ValueKey<String>('login');
    const transitionDuration = Duration(milliseconds: 50);
    const reverseTransitionDuration = Duration(milliseconds: 500);

    final router = GoRouter(
      routes: <GoRoute>[
        GoRoute(
          path: '/',
          builder: (_, _) => const HomeScreen(key: homeKey),
        ),
        GoRoute(
          path: '/login',
          pageBuilder: (_, state) => CustomTransitionPage<void>(
            key: state.pageKey,
            transitionDuration: transitionDuration,
            reverseTransitionDuration: reverseTransitionDuration,
            transitionsBuilder: (_, animation, _, child) =>
                FadeTransition(opacity: animation, child: child),
            child: const LoginScreen(key: loginKey),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.byKey(homeKey), findsOneWidget);

    router.push('/login');
    final pushingPumped = await tester.pumpAndSettle();
    expect(find.byKey(loginKey), findsOneWidget);

    router.pop();
    final poppingPumped = await tester.pumpAndSettle();
    expect(find.byKey(homeKey), findsOneWidget);

    expect(pushingPumped != poppingPumped, true);
  });
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('HomeScreen')));
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('LoginScreen')));
  }
}

class DismissibleModal extends StatelessWidget {
  const DismissibleModal({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: 200, height: 200, child: Center(child: Text('Dismissible Modal')));
  }
}
