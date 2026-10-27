import 'dart:async';

import 'package:boorusama/boorus/danbooru/posts/uploads/src/widgets/upload_to_danbooru.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/types.dart';
import 'package:boorusama/core/posts/shares/src/incoming_shared_text_source.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/foundation/platform.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:boorusama/core/debug/src/logging/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

class _Shares implements IncomingSharedTextSource {
  final initial = Completer<String?>();
  final events = StreamController<String>.broadcast();
  var initialCalls = 0;
  var resumeCalls = 0;
  var pauseCalls = 0;
  final pending = <String>[];
  @override
  Future<String?> initialText() {
    initialCalls++;
    return initial.future;
  }

  @override
  Stream<String> get texts => events.stream;

  @override
  Future<void> resumeWarmDelivery() async {
    resumeCalls++;
    pending.forEach(events.add);
    pending.clear();
  }

  @override
  Future<void> pauseWarmDelivery() async {
    pauseCalls++;
  }

  Future<void> close() => events.close();
}

Future<GoRouter> _pumpReceiver(
  WidgetTester tester,
  _Shares source, {
  AppPlatform platform = AppPlatform.android,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Home')),
        routes: [
          GoRoute(
            path: 'cross-profile-lookup',
            builder: (_, state) {
              final artwork = state.extra! as PixivArtworkReference;
              return Scaffold(body: Text('Artwork ${artwork.id}'));
            },
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(source.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        routerProvider.overrideWithValue(router),
        appPlatformProvider.overrideWithValue(platform),
        incomingSharedTextSourceProvider.overrideWithValue(source),
        loggerProvider.overrideWithValue(AppLogger()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (_, child) => UploadToDanbooru(child: child!),
      ),
    ),
  );
  return router;
}

void main() {
  testWidgets('a share buffered during startup opens after initial delivery', (
    tester,
  ) async {
    final source = _Shares();
    await _pumpReceiver(tester, source);
    source.pending.add(
      'QA artwork | QA artist #pixiv https://www.pixiv.net/en/artworks/151301916',
    );
    expect(source.resumeCalls, 0);
    source.initial.complete(null);
    await tester.pumpAndSettle();
    expect(source.resumeCalls, 1);
    expect(find.text('Artwork 151301916'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a buffered duplicate of the launch share opens only one page', (
    tester,
  ) async {
    final source = _Shares();
    final router = await _pumpReceiver(tester, source);
    const text = 'https://www.pixiv.net/en/artworks/12345';
    source.pending.add(text);
    source.initial.complete(text);
    await tester.pumpAndSettle();
    expect(find.text('Artwork 12345'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(router.canPop(), isFalse);
  });

  testWidgets('an initial read failure still releases buffered warm shares', (
    tester,
  ) async {
    final source = _Shares();
    await _pumpReceiver(tester, source);
    source.pending.add('https://www.pixiv.net/artworks/12345');
    source.initial.completeError(StateError('initial platform failure'));
    await tester.pumpAndSettle();
    expect(source.resumeCalls, 1);
    expect(find.text('Artwork 12345'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cold start extracts a captioned artwork without requiring an active Danbooru profile',
    (tester) async {
      final source = _Shares();
      await _pumpReceiver(tester, source);
      source.initial.complete(
        'Artwork title\nhttps://www.pixiv.net/artworks/12345?utm_source=share',
      );
      await tester.pumpAndSettle();
      expect(find.text('Artwork 12345'), findsOneWidget);
      expect(source.initialCalls, 1);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'warm and initial duplicate deliveries open once; a later share can reopen',
    (tester) async {
      final source = _Shares();
      final router = await _pumpReceiver(tester, source);
      const text = 'https://www.pixiv.net/en/artworks/12345';
      source.events.add(text);
      await tester.pumpAndSettle();
      source.initial.complete(text);
      await tester.pumpAndSettle();
      expect(find.text('Artwork 12345'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      source.events.add(text);
      await tester.pumpAndSettle();
      expect(find.text('Artwork 12345'), findsOneWidget);
    },
  );

  testWidgets('an initial platform failure leaves warm shares usable', (
    tester,
  ) async {
    final source = _Shares();
    await _pumpReceiver(tester, source);
    source.initial.completeError(StateError('private delivery detail'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    source.events.addError(StateError('private stream detail'));
    await tester.pumpAndSettle();
    source.events.add('https://www.pixiv.net/artworks/12345');
    await tester.pumpAndSettle();
    expect(find.text('Artwork 12345'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing before initial delivery prevents a late navigation', (
    tester,
  ) async {
    final source = _Shares();
    await _pumpReceiver(tester, source);
    await tester.pumpWidget(const SizedBox.shrink());
    source.initial.complete('https://www.pixiv.net/artworks/12345');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(source.events.hasListener, isFalse);
    expect(source.resumeCalls, 0);
    expect(source.pauseCalls, 1);
  });

  testWidgets(
    'non-Android runtimes do not subscribe to the platform receiver',
    (tester) async {
      final source = _Shares();
      await _pumpReceiver(tester, source, platform: AppPlatform.linux);
      expect(source.initialCalls, 0);
      expect(source.events.hasListener, isFalse);
    },
  );
}
