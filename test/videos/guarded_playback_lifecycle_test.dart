import 'dart:async';
import 'dart:io';

import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/videos/engines/types.dart';
import 'package:boorusama/core/videos/player/src/types/local_mp4_playback_compatibility.dart';
import 'package:boorusama/core/videos/player/src/types/video_playback_manager.dart';
import 'package:boorusama/core/videos/player/src/widgets/video_player.dart';
import 'package:boorusama/foundation/info/device_info.dart';
import 'package:boorusama/foundation/platform.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/src/image/raw_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../core/posts/details/progressive_image_test_utils.dart'
    show TestImageCache, portraitPng, pumpUntil, testApp;

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
  _Player({
    this.initializeGate,
    this.disposeGate,
    this.aspectRatio = 1,
    this.width,
    this.height,
    this.duration = const Duration(seconds: 1),
  });
  final Future<void>? initializeGate;
  final Future<void>? disposeGate;
  final initializeEntered = Completer<void>();
  final disposeEntered = Completer<void>();
  final _positions = StreamController<Duration>(
    onCancel: () => Future<void>.value(),
  );
  final _buffering = StreamController<bool>(
    onCancel: () => Future<void>.value(),
  );
  final _durations = StreamController<Duration>(
    onCancel: () => Future<void>.value(),
  );
  VideoSource? source;
  VideoConfig? config;
  var volume = 1.0;
  var speed = 1.0;
  var disposed = false;
  var initializes = 0;
  var switches = 0;
  var looping = false;
  @override
  final ValueNotifier<bool> firstFrameRendered = ValueNotifier(false);
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
  Future<void> setVolume(double volume) async => this.volume = volume;
  @override
  Future<void> setPlaybackSpeed(double speed) async => this.speed = speed;
  @override
  Future<void> setLooping(bool loop) async {
    looping = loop;
  }

  @override
  Future<void> switchUrl(VideoSource source, {VideoConfig? config}) async {
    switches++;
    firstFrameRendered.value = false;
    this.source = source;
    looping = false;
  }

  @override
  var isPlaying = false;

  @override
  Future<void> play() async => isPlaying = true;
  @override
  Future<void> pause() async => isPlaying = false;
  @override
  var position = Duration.zero;
  @override
  Future<void> seek(Duration position) async {
    this.position = position;
    _positions.add(position);
  }

  @override
  final double aspectRatio;
  @override
  final int? width;
  @override
  final int? height;
  @override
  final Duration duration;
  @override
  Stream<Duration> get positionStream => _positions.stream;
  @override
  Stream<Duration> get durationStream => _durations.stream;
  @override
  Stream<bool> get bufferingStream => _buffering.stream;
  @override
  Widget buildPlayerWidget(BuildContext context) => const Text('local-player');
  @override
  Future<void> dispose() async {
    if (!disposeEntered.isCompleted) disposeEntered.complete();
    await disposeGate;
    disposed = true;
    _durations.close().ignore();
    _positions.close().ignore();
    _buffering.close().ignore();
  }
}

Widget _app(
  Widget child, {
  AppPlatform platform = AppPlatform.android,
  Future<RestartedLocalMp4Timeline?> Function(File)? mp4Probe,
}) => ProviderScope(
  overrides: [
    appPlatformProvider.overrideWithValue(platform),
    if (mp4Probe != null)
      localMp4RestartedTimelineProvider.overrideWithValue(mp4Probe),
  ],
  child: testApp(child),
);

void main() {
  final compatibilityCases = [
    (
      name: 'healthy local MP4 in Auto',
      source: LocalFileVideoSource(File('/test/healthy.mp4')),
      preference: VideoPlayerEngine.auto,
      platform: AppPlatform.android,
      detected: false,
      probes: 1,
      expected: VideoPlayerEngine.videoPlayerPlugin,
    ),
    (
      name: 'explicit ExoPlayer',
      source: LocalFileVideoSource(File('/test/faulty.mp4')),
      preference: VideoPlayerEngine.videoPlayerPlugin,
      platform: AppPlatform.android,
      detected: true,
      probes: 0,
      expected: VideoPlayerEngine.videoPlayerPlugin,
    ),
    (
      name: 'explicit MPV',
      source: LocalFileVideoSource(File('/test/faulty.mp4')),
      preference: VideoPlayerEngine.mpv,
      platform: AppPlatform.android,
      detected: true,
      probes: 0,
      expected: VideoPlayerEngine.mpv,
    ),
    (
      name: 'remote MP4 cached locally',
      source: const CachedVideoSource(
        filePath: '/test/cached.mp4',
        originalUrl: 'https://example.test/video.mp4',
      ),
      preference: VideoPlayerEngine.auto,
      platform: AppPlatform.android,
      detected: true,
      probes: 0,
      expected: VideoPlayerEngine.videoPlayerPlugin,
    ),
    (
      name: 'local WebM in Auto',
      source: LocalFileVideoSource(File('/test/healthy.webm')),
      preference: VideoPlayerEngine.auto,
      platform: AppPlatform.android,
      detected: true,
      probes: 0,
      expected: VideoPlayerEngine.webview,
    ),
    (
      name: 'local MP4 in Auto on iOS',
      source: LocalFileVideoSource(File('/test/faulty.mp4')),
      preference: VideoPlayerEngine.auto,
      platform: AppPlatform.ios,
      detected: true,
      probes: 0,
      expected: VideoPlayerEngine.videoPlayerPlugin,
    ),
  ];
  for (final c in compatibilityCases) {
    testWidgets('preserves engine selection for ${c.name}', (tester) async {
      final player = _Player();
      final engines = <VideoPlayerEngine>[];
      var probes = 0;
      await tester.pumpWidget(
        _app(
          BooruVideo(
            url: c.source.originalUrl,
            aspectRatio: 1,
            sourceLoader: (_) async => (source: c.source, release: null),
            videoPlayerEngine: c.preference,
            playerFactory: (engine) {
              engines.add(engine);
              return player;
            },
          ),
          platform: c.platform,
          mp4Probe: (_) async {
            probes++;
            return c.detected ? const RestartedLocalMp4Timeline() : null;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(engines, [c.expected]);
      expect(probes, c.probes);
      expect(player.looping, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(player.disposed, isTrue);
    });
  }

  testWidgets('MPV plays the verified byte range from the original file', (
    tester,
  ) async {
    final file = File('/managed/media/test.mp4');
    final source = LocalFileVideoSource(file);
    final player = _Player();
    await tester.pumpWidget(
      _app(
        BooruVideo(
          url: source.url,
          aspectRatio: 1,
          sourceLoader: (_) async => (source: source, release: null),
          playerFactory: (engine) {
            expect(engine, VideoPlayerEngine.mpv);
            return player;
          },
        ),
        mp4Probe: (_) async =>
            const RestartedLocalMp4Timeline(firstStreamLength: 108997),
      ),
    );
    await tester.pumpAndSettle();
    final playback = player.source! as LocalFileVideoSource;
    expect(playback.file, same(file));
    expect(playback.mpvUrl, 'slice://0-108997@/managed/media/test.mp4');
    expect(player.looping, isTrue);
  });

  testWidgets('MPV owns the timeline, seek, looping and current play intent', (
    tester,
  ) async {
    final source = LocalFileVideoSource(File('/test/faulty.MP4'));
    final gate = Completer<void>();
    final player = _Player(
      initializeGate: gate.future,
      duration: const Duration(seconds: 6),
    );
    final manager = VideoPlaybackManager();
    addTearDown(manager.dispose);
    final engines = <VideoPlayerEngine>[];
    await manager.playVideo('video');
    await tester.pumpWidget(
      _app(
        BooruVideo(
          url: source.url,
          aspectRatio: 1,
          sourceLoader: (_) async => (source: source, release: null),
          videoPlayerEngine: VideoPlayerEngine.auto,
          sound: false,
          speed: 1.5,
          playerFactory: (engine) {
            engines.add(engine);
            return player;
          },
          onVideoPlayerCreated: (player) =>
              manager.registerPlayer(player, 'video'),
          onVideoPlayerDisposed: () => manager.unregisterPlayer('video'),
          onCurrentPositionChanged: (position, total) =>
              manager.updateProgress(position, total, 'video'),
        ),
        mp4Probe: (_) async => const RestartedLocalMp4Timeline(),
      ),
    );
    await tester.pump();
    expect(engines, [VideoPlayerEngine.mpv]);
    expect(player.source, same(source));
    await manager.pauseVideo('video');
    gate.complete();
    await tester.pumpAndSettle();
    expect(player.isPlaying, isFalse);
    expect(player.looping, isTrue);
    expect(player.volume, 0);
    expect(player.speed, 1.5);
    expect(manager.videoProgress.value.duration, const Duration(seconds: 6));
    const position = Duration(seconds: 4);
    await manager.playVideo('video');
    manager.seekVideo(position, 'video');
    await tester.pump();
    expect(player.isPlaying, isTrue);
    expect(player.position, position);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(player.disposed, isTrue);
    expect(engines, [VideoPlayerEngine.mpv]);
    expect(manager.getPlayer('video'), isNull);
  });

  testWidgets(
    'closing during the probe discards the old compatibility result',
    (
      tester,
    ) async {
      final source = LocalFileVideoSource(File('/test/faulty.mp4'));
      final probe = Completer<RestartedLocalMp4Timeline?>();
      final entered = Completer<void>();
      var releases = 0;
      await tester.pumpWidget(
        _app(
          BooruVideo(
            url: source.url,
            aspectRatio: 1,
            sourceLoader: (_) async => (
              source: source,
              release: () => Future.sync(() {
                releases++;
              }),
            ),
            playerFactory: (_) => throw StateError('Created after navigation'),
          ),
          mp4Probe: (_) {
            entered.complete();
            return probe.future;
          },
        ),
      );
      await tester.pump();
      expect(entered.isCompleted, isTrue);
      await tester.pumpWidget(const SizedBox());
      probe.complete(const RestartedLocalMp4Timeline());
      await tester.pumpAndSettle();
      expect(releases, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a remote MP4 following a local fallback uses its own engine', (
    tester,
  ) async {
    final mpv = _Player();
    final exo = _Player();
    final engines = <VideoPlayerEngine>[];
    Widget video(VideoSource source) => _app(
      BooruVideo(
        url: source.url,
        aspectRatio: 1,
        sourceLoader: (_) async => (source: source, release: null),
        playerFactory: (engine) {
          engines.add(engine);
          return engine == VideoPlayerEngine.mpv ? mpv : exo;
        },
      ),
      mp4Probe: (_) async => const RestartedLocalMp4Timeline(),
    );
    await tester.pumpWidget(video(LocalFileVideoSource(File('/test/a.mp4'))));
    await tester.pumpAndSettle();
    const remote = StreamingVideoSource('https://example.test/b.mp4');
    await tester.pumpWidget(video(remote));
    await tester.pumpAndSettle();
    expect(engines, [
      VideoPlayerEngine.mpv,
      VideoPlayerEngine.videoPlayerPlugin,
    ]);
    expect(mpv.disposed, isTrue);
    expect(exo.source, same(remote));
  });

  testWidgets('an MPV startup error disposes the player and stops fallback', (
    tester,
  ) async {
    final source = LocalFileVideoSource(File('/test/faulty.mp4'));
    final error = Completer<void>();
    final player = _Player(initializeGate: error.future);
    final engines = <VideoPlayerEngine>[];
    final registered = <BooruPlayer>[];
    await tester.pumpWidget(
      _app(
        BooruVideo(
          url: source.url,
          aspectRatio: 1,
          sourceLoader: (_) async => (source: source, release: null),
          playerFactory: (engine) {
            engines.add(engine);
            return player;
          },
          onVideoPlayerCreated: registered.add,
        ),
        mp4Probe: (_) async => const RestartedLocalMp4Timeline(),
      ),
    );
    await tester.pump();
    expect(player.initializeEntered.isCompleted, isTrue);
    error.completeError(StateError('MPV could not open the video'));
    await tester.pumpAndSettle();
    expect(find.textContaining('MPV could not open the video'), findsOneWidget);
    expect(engines, [VideoPlayerEngine.mpv]);
    expect(registered, isEmpty);
    expect(player.disposed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an engine change awaits teardown and discards stale startups', (
    tester,
  ) async {
    final source = LocalFileVideoSource(File('/test/faulty.mp4'));
    final disposal = Completer<void>();
    final first = _Player(disposeGate: disposal.future);
    final startup = Completer<void>();
    final mpv = _Player(initializeGate: startup.future);
    final replacement = _Player();
    final players = [first, mpv, replacement].iterator;
    final engines = <VideoPlayerEngine>[];
    final registered = <BooruPlayer>[];
    late StateSetter update;
    var preference = VideoPlayerEngine.videoPlayerPlugin;
    var probes = 0;
    final video = _app(
      StatefulBuilder(
        builder: (_, setState) {
          update = setState;
          return BooruVideo(
            url: source.url,
            aspectRatio: 1,
            videoPlayerEngine: preference,
            sourceLoader: (_) async => (source: source, release: null),
            playerFactory: (engine) {
              engines.add(engine);
              expect(players.moveNext(), isTrue);
              return players.current;
            },
            onVideoPlayerCreated: registered.add,
          );
        },
      ),
      mp4Probe: (_) async {
        probes++;
        return const RestartedLocalMp4Timeline();
      },
    );

    await tester.pumpWidget(video);
    await tester.pumpAndSettle();
    update(() => preference = VideoPlayerEngine.auto);
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(probes, 1);
    expect(first.disposeEntered.isCompleted, isTrue);
    expect(engines, [VideoPlayerEngine.videoPlayerPlugin]);
    disposal.complete();
    await tester.pump();
    expect(first.disposed, isTrue);
    expect(mpv.initializeEntered.isCompleted, isTrue);
    var cancelled = false;
    unawaited(
      mpv.config!.localFallbackCancelled!.then((_) => cancelled = true),
    );

    update(() => preference = VideoPlayerEngine.videoPlayerPlugin);
    await tester.pump();
    expect(cancelled, isTrue);
    expect(replacement.initializeEntered.isCompleted, isFalse);
    startup.complete();
    await tester.pumpAndSettle();
    expect(mpv.disposed, isTrue);
    expect(registered, [first, replacement]);
    expect(engines, [
      VideoPlayerEngine.videoPlayerPlugin,
      VideoPlayerEngine.mpv,
      VideoPlayerEngine.videoPlayerPlugin,
    ]);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(replacement.disposed, isTrue);
  });

  const wideRatio = 16 / 9;
  for (final (viewport, metadata, nativeDimensions) in [
    (const Size(390, 800), null, false),
    (const Size(800, 390), null, false),
    (const Size(800, 390), wideRatio, false),
    (const Size(800, 390), null, true),
  ]) {
    testWidgets(
      'fits the video poster ($viewport, metadata=$metadata, native=$nativeDimensions)',
      (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = viewport;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final gate = Completer<void>();
        final player = _Player(
          initializeGate: gate.future,
          aspectRatio: wideRatio,
          width: nativeDimensions ? 160 : null,
          height: nativeDimensions ? 90 : null,
        );
        addTearDown(player.firstFrameRendered.dispose);
        final dio = Dio();
        addTearDown(() => dio.close(force: true));
        final portrait = viewport.width < viewport.height;
        final poster = portrait
            ? portraitPng
            : image.encodePng(
                image.copyRotate(image.decodePng(portraitPng)!, angle: 90),
              );
        final posterUrl =
            'https://example.test/poster-${portrait ? 'portrait' : 'landscape'}.png';
        var frames = 0;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appPlatformProvider.overrideWithValue(AppPlatform.android),
              automaticMediaLoadingEnabledProvider.overrideWithValue(true),
              currentReadOnlyBooruConfigAuthProvider.overrideWithValue(
                BooruConfig.empty.auth,
              ),
              defaultImageCacheManagerProvider.overrideWithValue(
                TestImageCache({posterUrl: poster}),
              ),
              deviceInfoProvider.overrideWithValue(DeviceInfo.empty()),
              imageListingSettingsProvider.overrideWithValue(
                Settings.defaultSettings.listing,
              ),
              dioForWidgetProvider.overrideWith((_, _) => dio),
              httpHeadersProvider.overrideWith((_, _) => const {}),
            ],
            child: MaterialApp(
              builder: (context, child) => KurumiTheme(
                data: KurumiThemeData.fromMaterial(Theme.of(context)),
                child: child!,
              ),
              home: Scaffold(
                body: BooruVideo(
                  url: 'https://example.test/video.mp4',
                  thumbnailUrl: posterUrl,
                  aspectRatio: metadata,
                  playerFactory: (_) => player,
                  onFrameRendered: () => frames++,
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        final raw = find.byType(ExtendedRawImage);
        await tester.runAsync(
          () => pumpUntil(
            tester,
            () => raw.evaluate().any(
              (element) => (element.widget as ExtendedRawImage).image != null,
            ),
            reason: 'video poster decode',
          ),
        );

        Size paintedPoster() {
          final widget = tester.widget<ExtendedRawImage>(raw);
          expect(widget.fit, BoxFit.contain);
          final decoded = widget.image!;
          return applyBoxFit(
            widget.fit!,
            Size(decoded.width.toDouble(), decoded.height.toDouble()),
            tester.getSize(raw),
          ).destination;
        }

        final fullFit = portrait ? const Size(200, 800) : const Size(800, 200);
        const videoFit = Size(390 * wideRatio, 390 * wideRatio / 4);
        void expectPoster(Size expected) {
          final painted = paintedPoster();
          expect(painted.width, closeTo(expected.width, 1));
          expect(painted.height, closeTo(expected.height, 1));
        }

        expectPoster(metadata != null ? videoFit : fullFit);
        expect(frames, 0);

        gate.complete();
        await tester.pumpAndSettle();
        expect(find.text('local-player'), findsOneWidget);
        expectPoster(metadata != null || nativeDimensions ? videoFit : fullFit);
        expect(frames, 0);

        player.firstFrameRendered.value = true;
        await tester.pumpAndSettle();
        final opacity = find.ancestor(of: raw, matching: find.byType(Opacity));
        expect(tester.widget<Opacity>(opacity.first).opacity, 0);
        expect(frames, 1);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('display waits for a current rendered frame and active surface', (
    tester,
  ) async {
    final player = _Player();
    var displayed = 0;
    Widget video(int source, bool active) => _app(
      BooruVideo(
        url: 'https://example.test/video-$source.mp4',
        aspectRatio: 1,
        shouldInitialize: active,
        playerFactory: (_) => player,
        onFrameRendered: () => displayed++,
      ),
    );
    await tester.pumpWidget(video(1, true));
    await tester.pumpAndSettle();
    expect(player.initializes, 1);
    expect(displayed, 0, reason: 'Initialization is not a displayed frame');

    await tester.pumpWidget(video(1, false));
    player.firstFrameRendered.value = true;
    await tester.pumpAndSettle();
    expect(displayed, 0, reason: 'A hidden/preloaded surface is not read');
    await tester.pumpWidget(video(1, true));
    await tester.pumpAndSettle();
    expect(displayed, 1);
    await tester.pumpWidget(video(1, true));
    await tester.pumpAndSettle();
    expect(displayed, 1, reason: 'One display signal per source generation');

    await tester.pumpWidget(video(2, true));
    await tester.pumpAndSettle();
    expect(player.switches, 1);
    expect(
      displayed,
      1,
      reason: 'An old source frame cannot read its replacement',
    );
    player.firstFrameRendered.value = true;
    await tester.pumpAndSettle();
    expect(displayed, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    player.firstFrameRendered.dispose();
  });

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
                release: () => Future.sync(() {
                  releases++;
                }),
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
            release: () => Future.sync(() {
              releases++;
            }),
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
