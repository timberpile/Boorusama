import 'package:boorusama/core/posts/shares/src/gif_loop_preview_controller.dart';
import 'package:boorusama/core/posts/shares/src/gif_preview_controls.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/material.dart';

void main() {
  testWidgets('ready controls keep the available preview width in a Column', (
    tester,
  ) async {
    final controller = GifLoopPreviewController(
      backend: _Backend(),
      start: Duration.zero,
      end: const Duration(seconds: 5),
      speed: 1,
      enabled: true,
    );
    await controller.initialize();
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: Column(
                children: [
                  SizedBox(
                    height: 225,
                    child: GifPreviewControls(
                      controller: controller,
                      enabled: true,
                      child: const ColoredBox(color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('gif-preview-surface'))),
      const Size(360, 225),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await controller.close();
  });

  for (final accessible in [false, true]) {
    testWidgets(
      'controls hide during playback and remain usable (accessible=$accessible)',
      (tester) async {
        final controller = GifLoopPreviewController(
          backend: _Backend(),
          start: Duration.zero,
          end: const Duration(seconds: 5),
          speed: 1,
          enabled: true,
        );
        await controller.initialize();
        await tester.pumpWidget(
          TranslationProvider(
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  accessibleNavigation: accessible,
                  textScaler: const TextScaler.linear(2),
                ),
                child: Scaffold(
                  body: SizedBox(
                    width: 280,
                    height: 150,
                    child: GifPreviewControls(
                      controller: controller,
                      enabled: true,
                      child: const ColoredBox(color: Colors.black),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 3));
        final opacity = find.ancestor(
          of: find.byKey(const ValueKey('gif-preview-play-pause')),
          matching: find.byType(AnimatedOpacity),
        );
        expect(
          tester.widget<AnimatedOpacity>(opacity).opacity,
          accessible ? 1 : 0,
        );
        await tester.tapAt(const Offset(15, 30));
        await tester.pump();
        expect(tester.widget<AnimatedOpacity>(opacity).opacity, 1);
        expect(controller.playing, isTrue);
        await tester.tap(find.byKey(const ValueKey('gif-preview-play-pause')));
        await tester.pump();
        await tester.pump(const Duration(seconds: 4));
        expect(controller.playing, isFalse);
        expect(tester.widget<AnimatedOpacity>(opacity).opacity, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await controller.close();
      },
    );
  }
}

class _Backend implements GifLoopPreviewBackend {
  @override
  Duration position = Duration.zero;
  @override
  Future<void> open() async {}
  @override
  Future<void> setRange(Duration start, Duration end) async {}
  @override
  Future<void> setSpeed(double speed) async {}
  @override
  Future<void> seek(Duration position) async {
    this.position = position;
  }

  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> close() async {}
}
