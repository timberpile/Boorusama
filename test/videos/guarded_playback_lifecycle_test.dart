import 'dart:async';

import 'package:boorusama/core/videos/engines/types.dart';
import 'package:boorusama/core/videos/player/src/widgets/video_player.dart';
import 'package:boorusama/foundation/platform.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';
import 'package:mocktail/mocktail.dart';

import '../core/posts/details/progressive_image_test_utils.dart' show testApp;

class _Lease implements VideoCacheLease {
  @override
  final path = '/local/guarded.mp4';
  var releases = 0;
  final released = Completer<void>();
  @override
  Future<void> release() async {
    releases++;
    if (!released.isCompleted) released.complete();
  }
}

class _Player extends Fake implements BooruPlayer {
  _Player({this.initializeGate});
  final Future<void>? initializeGate;
  final initializeEntered = Completer<void>();
  VideoSource? source;
  VideoConfig? config;
  var disposed = false;
  var initializes = 0;
  var switches = 0;
  var looping = false;
  @override
  bool isPlatformSupported() => true;
  @override
  Future<void> initialize(VideoSource source, {VideoConfig? config}) async {
    initializes++;
    this.source = source;
    this.config = config;
    if (!initializeEntered.isCompleted) initializeEntered.complete();
    await initializeGate;
  }

  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> setPlaybackSpeed(double speed) async {}
  @override
  Future<void> setLooping(bool loop) async {
    looping = loop;
  }

  @override
  Future<void> switchUrl(VideoSource source, {VideoConfig? config}) async {
    switches++;
    this.source = source;
    looping = false;
  }

  @override
  bool get isPlaying => false;

  @override
  Future<void> pause() async {}
  @override
  double get aspectRatio => 1;
  @override
  Duration get duration => const Duration(seconds: 1);
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<bool> get bufferingStream => const Stream.empty();
  @override
  Widget buildPlayerWidget(BuildContext context) => const Text('local-player');
  @override
  void dispose() {
    disposed = true;
  }
}

Widget _app(Widget child) => ProviderScope(
  overrides: [appPlatformProvider.overrideWithValue(AppPlatform.android)],
  child: testApp(child),
);

void main() {
  testWidgets(
    'reactivating a retained video preserves its initialized looping player',
    (tester) async {
      final player = _Player();
      Widget video(bool active) => _app(
        BooruVideo(
          url: 'https://example.test/video.mp4',
          aspectRatio: 1,
          shouldInitialize: active,
          playerFactory: (_) => player,
        ),
      );
      await tester.pumpWidget(video(true));
      await tester.pumpAndSettle();
      expect(player.initializes, 1);
      expect(player.looping, isTrue);
      await tester.pumpWidget(video(false));
      await tester.pumpAndSettle();
      await tester.pumpWidget(video(true));
      await tester.pumpAndSettle();
      expect(player.initializes, 1);
      expect(player.switches, 0);
      expect(player.looping, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'reactivating a changed inactive source still loads its new URL',
    (tester) async {
      final player = _Player();
      Widget video(int id, bool active) => _app(
        BooruVideo(
          url: 'https://example.test/video-$id.mp4',
          aspectRatio: 1,
          shouldInitialize: active,
          playerFactory: (_) => player,
        ),
      );
      await tester.pumpWidget(video(1, true));
      await tester.pumpAndSettle();
      await tester.pumpWidget(video(1, false));
      await tester.pumpAndSettle();
      await tester.pumpWidget(video(2, false));
      await tester.pumpAndSettle();
      expect(player.switches, 0);
      await tester.pumpWidget(video(2, true));
      await tester.pumpAndSettle();
      expect(player.switches, 1);
      expect(player.source?.url, 'https://example.test/video-2.mp4');
      expect(player.looping, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'inactive source replacement cannot register a late initialized player',
    (tester) async {
      final gate = Completer<void>();
      final previous = _Player(initializeGate: gate.future);
      final replacement = _Player();
      final created = <BooruPlayer>[];
      var factories = 0;
      Widget video(int id, bool active) => _app(
        BooruVideo(
          url: 'https://example.test/video-$id.mp4',
          aspectRatio: 1,
          shouldInitialize: active,
          playerFactory: (_) => factories++ == 0 ? previous : replacement,
          onVideoPlayerCreated: created.add,
        ),
      );
      await tester.pumpWidget(video(1, true));
      await tester.pump();
      expect(previous.initializeEntered.isCompleted, isTrue);
      await tester.pumpWidget(video(2, false));
      gate.complete();
      // The inactive view intentionally keeps its loading indicator; drain the
      // controlled initialization completion without waiting for it to animate.
      await tester.pump();
      expect(previous.disposed, isTrue);
      expect(created, isEmpty);
      await tester.pumpWidget(video(2, true));
      await tester.pumpAndSettle();
      expect(created, [replacement]);
      expect(replacement.source?.url, 'https://example.test/video-2.mp4');
      expect(replacement.looping, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'changing video URL reapplies looping to the replacement source',
    (tester) async {
      final player = _Player();
      Widget video(int id) => _app(
        BooruVideo(
          url: 'https://example.test/video-$id.mp4',
          aspectRatio: 1,
          playerFactory: (_) => player,
        ),
      );
      await tester.pumpWidget(video(1));
      await tester.pumpAndSettle();
      await tester.pumpWidget(video(2));
      await tester.pumpAndSettle();
      expect(player.switches, 1);
      expect(player.looping, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  const remote = 'https://safebooru.donmai.us/video.mp4';
  for (final pendingInitialization in [false, true]) {
    testWidgets(
      'guarded stream failure reaches UI during initialization=$pendingInitialization',
      (tester) async {
        final failures = StreamController<void>();
        final gate = Completer<void>();
        final player = _Player(
          initializeGate: pendingInitialization ? gate.future : null,
        );
        var releases = 0;
        await tester.pumpWidget(
          _app(
            BooruVideo(
              url: remote,
              aspectRatio: 1,
              sourceLoader: (_) async => (
                source: GuardedStreamingVideoSource(
                  playbackUrl: 'http://127.0.0.1:12345/video',
                  originalUrl: remote,
                  failures: failures.stream,
                ),
                release: () async {
                  releases++;
                },
              ),
              playerFactory: (_) => player,
            ),
          ),
        );
        await tester.pump();
        expect(player.initializeEntered.isCompleted, isTrue);
        if (!pendingInitialization) await tester.pumpAndSettle();
        failures.add(null);
        await tester.pump();
        if (pendingInitialization) gate.complete();
        await tester.pumpAndSettle();
        expect(
          find.text('The original media file is unavailable. Retry.'),
          findsOneWidget,
        );
        expect(find.text('local-player'), findsNothing);
        expect(player.disposed, isTrue);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(releases, 1);
        await tester.runAsync(failures.close);
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('guarded stream gives native player no upstream headers', (
    tester,
  ) async {
    final player = _Player();
    var releases = 0;
    await tester.pumpWidget(
      _app(
        BooruVideo(
          url: remote,
          aspectRatio: 1,
          headers: const {'Authorization': 'upstream-secret'},
          sourceLoader: (_) async => (
            source: const GuardedStreamingVideoSource(
              playbackUrl: 'http://127.0.0.1:12345/capability/video',
              originalUrl: remote,
            ),
            release: () async {
              releases++;
            },
          ),
          playerFactory: (_) => player,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(player.source, isA<GuardedStreamingVideoSource>());
    expect(player.config?.headers, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(releases, 1);
    expect(player.disposed, isTrue);
  });
  testWidgets(
    'guarded loader supplies only its local source and retains its lease',
    (tester) async {
      final lease = _Lease();
      final player = _Player();
      await tester.pumpWidget(
        _app(
          BooruVideo(
            url: remote,
            aspectRatio: 1,
            sourceLoader: (_) async => (
              source: CachedVideoSource(
                filePath: lease.path,
                originalUrl: remote,
              ),
              release: lease.release,
            ),
            playerFactory: (_) => player,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(player.source, isA<CachedVideoSource>());
      expect(player.source!.url, 'file://${lease.path}');
      expect(find.text('local-player'), findsOneWidget);
      expect(lease.releases, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => lease.released.future.timeout(const Duration(seconds: 10)),
      );
      expect(player.disposed, isTrue);
      expect(lease.releases, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'disposing during preparation cancels and releases a late source without creating a player',
    (tester) async {
      final pending =
          Completer<({VideoSource source, Future<void> Function()? release})>();
      CancelToken? cancellation;
      final lease = _Lease();
      var creates = 0;
      await tester.pumpWidget(
        _app(
          BooruVideo(
            url: remote,
            aspectRatio: 1,
            sourceLoader: (token) {
              cancellation = token;
              return pending.future;
            },
            playerFactory: (_) {
              creates++;
              return _Player();
            },
          ),
        ),
      );
      expect(cancellation, isNotNull);
      await tester.pumpWidget(const SizedBox());
      expect(cancellation!.isCancelled, isTrue);
      pending.complete((
        source: CachedVideoSource(filePath: lease.path, originalUrl: remote),
        release: lease.release,
      ));
      await tester.pump();
      expect(creates, 0);
      expect(lease.releases, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a rejected guarded source never falls back to native streaming',
    (tester) async {
      var creates = 0;
      await tester.pumpWidget(
        _app(
          BooruVideo(
            url: remote,
            aspectRatio: 1,
            sourceLoader: (_) async => throw StateError('Public read revoked'),
            playerFactory: (_) {
              creates++;
              return _Player();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(creates, 0);
      expect(find.textContaining('Public read revoked'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
