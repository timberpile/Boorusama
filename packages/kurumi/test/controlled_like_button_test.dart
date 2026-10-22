import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';

void main() {
  testWidgets('controlled taps survive pending writes and animation', (
    tester,
  ) async {
    final liked = ValueNotifier(false);
    addTearDown(liked.dispose);
    final pending = <Completer<bool?>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: liked,
            builder: (_, value, _) => KurumiLikeButton(
              isLiked: value,
              controlled: true,
              onTap: (_) {
                final operation = Completer<bool?>();
                pending.add(operation);
                return operation.future;
              },
              builder: (value) => Text(value ? 'on' : 'off'),
            ),
          ),
        ),
      ),
    );
    final button = find.byType(KurumiLikeButton);
    await tester.tap(button);
    liked.value = true;
    await tester.pump();
    // The first callback is still pending and the add animation is running.
    await tester.tap(button);
    expect(pending, hasLength(2));
    liked.value = false;
    await tester.pump();
    pending.last.complete(false);
    pending.first.complete(true);
    await tester.pump();
    expect(find.text('off'), findsOneWidget);
    expect(find.text('on'), findsNothing);
  });

  testWidgets('default mode retains pending and animation locks', (
    tester,
  ) async {
    final pending = <Completer<bool?>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KurumiLikeButton(
            isLiked: false,
            onTap: (_) {
              final operation = Completer<bool?>();
              pending.add(operation);
              return operation.future;
            },
            builder: (value) => Text(value ? 'on' : 'off'),
          ),
        ),
      ),
    );
    final button = find.byType(KurumiLikeButton);
    await tester.tap(button);
    await tester.tap(button);
    expect(pending, hasLength(1));
    pending.first.complete(true);
    await tester.pump();
    await tester.tap(button);
    expect(pending, hasLength(1));
    await tester.pumpAndSettle();
    await tester.tap(button);
    expect(pending, hasLength(2));
    pending.last.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('off'), findsOneWidget);
  });

  for (final controlled in [false, true]) {
    testWidgets('disabled button never toggles (controlled: $controlled)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KurumiLikeButton(
              isLiked: false,
              controlled: controlled,
              enabled: false,
              builder: (value) => Text(value ? 'on' : 'off'),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(KurumiLikeButton));
      await tester.pump();
      expect(find.text('off'), findsOneWidget);
      expect(find.text('on'), findsNothing);
    });
  }

  testWidgets('controlled button with no callback does not toggle locally', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KurumiLikeButton(
            isLiked: false,
            controlled: true,
            builder: (value) => Text(value ? 'on' : 'off'),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(KurumiLikeButton));
    await tester.pump();
    expect(find.text('off'), findsOneWidget);
  });

  testWidgets(
    'controlled callbacks cannot update a replacement target or a disposed button',
    (tester) async {
      final first = Completer<bool?>();
      final second = Completer<bool?>();
      Widget button(bool liked, Completer<bool?> response) => MaterialApp(
        home: Center(
          child: KurumiLikeButton(
            isLiked: liked,
            controlled: true,
            onTap: (_) => response.future,
            builder: (value) => Text(value ? 'on' : 'off'),
          ),
        ),
      );
      await tester.pumpWidget(button(false, first));
      await tester.tap(find.byType(KurumiLikeButton));
      await tester.pumpWidget(button(true, second));
      first.complete(false);
      await tester.pumpAndSettle();
      expect(find.text('on'), findsOneWidget);
      await tester.tap(find.byType(KurumiLikeButton));
      await tester.pumpWidget(const SizedBox.shrink());
      second.complete(false);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
