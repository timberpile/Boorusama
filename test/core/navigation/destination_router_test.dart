import 'dart:async';

import 'package:boorusama/core/navigation/destination_id.dart';
import 'package:boorusama/core/navigation/destination_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const a = DestinationId.tool('a', 'danbooru.pools');
const b = DestinationId.tool('b', 'pixiv.explore');
const c = DestinationId.browse('c');
const recovery = DestinationId.app(AppDestination.browseRecovery);

DestinationRouteDefinition definition(DestinationId id) =>
    DestinationRouteDefinition(
      id: id,
      builder: (_, _) => Scaffold(body: Text(id.toStorageKey())),
      children: [
        GoRoute(
          path: 'detail',
          builder: (_, _) => const Scaffold(body: TextField(key: Key('draft'))),
        ),
      ],
    );

void main() {
  testWidgets(
    'ordinary switching preserves independent Favorites histories and pop futures',
    (tester) async {
      const first = DestinationId.favorites('a');
      const second = DestinationId.favorites('b');
      final binding = DestinationRouterBinding(
        definitions: [
          definition(recovery),
          definition(first),
          definition(second),
        ],
        shellBuilder: (_, _, shell) => shell,
      );
      final router = GoRouter.routingConfig(
        routingConfig: binding.routingConfig,
        initialLocation: first.location,
      );
      binding.attach(router);
      addTearDown(router.dispose);
      addTearDown(binding.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      final returned = router.push<String>('${first.location}/detail');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('draft')), 'first');
      binding.select(second);
      await tester.pumpAndSettle();
      unawaited(router.push('${second.location}/detail'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('draft')), 'second');
      binding.select(first);
      await tester.pumpAndSettle();
      expect(find.text('first'), findsOneWidget);
      router.pop('done');
      await tester.pumpAndSettle();
      expect(await returned, 'done');
      binding.select(second);
      await tester.pumpAndSettle();
      expect(find.text('second'), findsOneWidget);
      expect(
        binding.observerFor(first),
        isNot(same(binding.observerFor(second))),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('new branches remain reachable after restoring a cached branch', (
    tester,
  ) async {
    final binding = DestinationRouterBinding(
      definitions: [definition(recovery), definition(a), definition(b)],
      shellBuilder: (_, _, shell) => shell,
    );
    final router = GoRouter.routingConfig(
      routingConfig: binding.routingConfig,
      initialLocation: a.location,
    );
    binding.attach(router);
    addTearDown(router.dispose);
    addTearDown(binding.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    binding.select(b);
    await tester.pumpAndSettle();
    await binding.reconcile([
      definition(recovery),
      definition(a),
      definition(b),
      definition(c),
    ]);
    await tester.pumpAndSettle();
    binding.select(a);
    await tester.pumpAndSettle();
    expect(binding.select(c), isTrue);
    await tester.pumpAndSettle();
    expect(binding.currentDestination, c);
    expect(find.text(c.toStorageKey()), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('credential replacement resets only its own branch generation', (
    tester,
  ) async {
    final binding = DestinationRouterBinding(
      definitions: [definition(recovery), definition(a), definition(b)],
      shellBuilder: (_, _, shell) => shell,
    );
    final router = GoRouter.routingConfig(
      routingConfig: binding.routingConfig,
      initialLocation: a.location,
    );
    binding.attach(router);
    addTearDown(router.dispose);
    addTearDown(binding.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    unawaited(router.push('${a.location}/detail'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('draft')), 'revoked');
    final oldBranch = binding.branchFor(a);
    binding.select(b);
    await tester.pumpAndSettle();
    unawaited(router.push('${b.location}/detail'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('draft')), 'survivor');
    final survivor = tester.state(find.byKey(const Key('draft')));
    await binding.reconcile(
      [definition(recovery), definition(a), definition(b)],
      resetProfileIds: {'a'},
    );
    await tester.pumpAndSettle();
    expect(tester.state(find.byKey(const Key('draft'))), same(survivor));
    expect(binding.branchFor(a), isNot(same(oldBranch)));
    binding.select(a);
    await tester.pumpAndSettle();
    expect(find.text('revoked'), findsNothing);
    expect(find.byKey(const Key('draft')), findsNothing);
    binding.select(b);
    await tester.pumpAndSettle();
    expect(find.text('survivor'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'retains child drafts across switches and structural reconfiguration',
    (tester) async {
      final binding = DestinationRouterBinding(
        definitions: [definition(recovery), definition(a), definition(b)],
        shellBuilder: (_, _, shell) => shell,
      );
      final router = GoRouter.routingConfig(
        routingConfig: binding.routingConfig,
        initialLocation: a.location,
      );
      binding.attach(router);
      addTearDown(router.dispose);
      addTearDown(binding.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      unawaited(router.push('${a.location}/detail'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('draft')), 'unfinished A');
      final draftState = tester.state(find.byKey(const Key('draft')));
      final branch = binding.branchFor(a);
      expect(binding.select(b), isTrue);
      await tester.pumpAndSettle();
      await binding.reconcile([
        definition(b),
        definition(c),
        definition(a),
        definition(recovery),
      ]);
      await tester.pumpAndSettle();
      expect(binding.branchFor(a), same(branch));
      expect(binding.select(a), isTrue);
      await tester.pumpAndSettle();
      expect(tester.state(find.byKey(const Key('draft'))), same(draftState));
      expect(find.text('unfinished A'), findsOneWidget);
      expect(binding.select(a), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('unfinished A'), findsOneWidget);
      // Delete inactive C, then active B. Recovery is reached before removal.
      await binding.reconcile([
        definition(recovery),
        definition(a),
        definition(b),
      ]);
      await tester.pumpAndSettle();
      binding.select(b);
      await tester.pumpAndSettle();
      final removal = binding.reconcile([definition(recovery), definition(a)]);
      await tester.pumpAndSettle();
      await removal;
      await tester.pumpAndSettle();
      expect(binding.currentDestination, recovery);
      binding.select(a);
      await tester.pumpAndSettle();
      expect(find.text('unfinished A'), findsOneWidget);
      expect(tester.takeException(), isNull);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('draft')), findsNothing);
      expect(binding.select(c), isFalse);
      await tester.pumpAndSettle();
      expect(binding.currentDestination, recovery);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
