import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:boorusama/boorus/pixiv/ugoira/ugoira_archive.dart';
import 'package:boorusama/boorus/pixiv/ugoira/ugoira_frames.dart';
import 'package:boorusama/boorus/pixiv/ugoira/ugoira_player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/material.dart';

void main() {
  testWidgets(
    'poster survives settlement and a ready animation paints immediately',
    (
      tester,
    ) async {
      final ready = PreparedPixivUgoira(
        PixivUgoiraAnimation(
          [
            Uint8List.fromList([0]),
            Uint8List.fromList([1]),
          ],
          [120, 160],
        ),
        [_frame(1), _frame(2)],
      );
      addTearDown(ready.release);
      const poster = _PosterProbe();
      final posterFinder = find.byType(_PosterProbe);
      final visibleImage = find.byType(RawImage);
      int width() => tester.widget<RawImage>(visibleImage).image!.width;

      await tester.pumpWidget(_app(active: false, poster: poster));
      final state = tester.state(posterFinder);
      expect(visibleImage, findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pumpWidget(
        _app(active: true, loading: true, poster: poster),
      );
      expect(tester.state(posterFinder), same(state));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading animation…'), findsNothing);

      await tester.pumpWidget(
        _app(active: true, prepared: ready, poster: poster),
      );
      expect(tester.state(posterFinder), same(state));
      expect(width(), 1);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
      expect(find.byIcon(Icons.pause), findsNothing);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(width(), 2);
      await tester.pump(const Duration(milliseconds: 40));
      expect(width(), 1);

      await tester.pumpWidget(_app(active: false, poster: poster));
      expect(tester.state(posterFinder), same(state));
      expect(visibleImage, findsNothing);
    },
  );

  testWidgets('failed animation keeps its poster and shows a retry', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      _app(
        active: true,
        failed: true,
        onRetry: () => retries++,
        poster: const _PosterProbe(),
      ),
    );
    expect(find.byType(_PosterProbe), findsOneWidget);
    expect(find.byType(RawImage), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Animation could not be played.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });
}

ui.Image _frame(int width) {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder);
  final picture = recorder.endRecording();
  try {
    return picture.toImageSync(width, 1);
  } finally {
    picture.dispose();
  }
}

Widget _app({
  required bool active,
  required Widget poster,
  bool failed = false,
  bool loading = false,
  PreparedPixivUgoira? prepared,
  VoidCallback? onRetry,
}) => TranslationProvider(
  child: MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: const TextScaler.linear(1.8)),
      child: child!,
    ),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 180,
          height: 120,
          child: PixivUgoiraPlayer(
            active: active,
            prepared: prepared,
            downloadProgress: loading
                ? const AlwaysStoppedAnimation<double?>(null)
                : null,
            failed: failed,
            onRetry: onRetry,
            poster: poster,
            decodeFrame: (bytes) => Future.value(_frame(bytes.single + 1)),
          ),
        ),
      ),
    ),
  ),
);

class _PosterProbe extends StatefulWidget {
  const _PosterProbe();

  @override
  State<_PosterProbe> createState() => _PosterProbeState();
}

class _PosterProbeState extends State<_PosterProbe> {
  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.blue);
}
