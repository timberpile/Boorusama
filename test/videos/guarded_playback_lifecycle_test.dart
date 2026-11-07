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
  VideoSource? source;
  var disposed = false;
  @override
  bool isPlatformSupported() => true;
  @override
  Future<void> initialize(VideoSource source, {VideoConfig? config}) async {
    this.source = source;
  }

  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> setPlaybackSpeed(double speed) async {}
  @override
  Future<void> setLooping(bool loop) async {}
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
  const remote = 'https://safebooru.donmai.us/video.mp4';
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
              lease: lease,
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
          Completer<({VideoSource source, VideoCacheLease? lease})>();
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
        lease: lease,
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
