import 'package:boorusama/core/posts/shares/src/gif_conversion_service.dart';
import 'package:boorusama/core/posts/shares/src/gif_editor_selection.dart';
import 'package:boorusama/core/posts/shares/src/gif_export_contract.dart';
import 'package:boorusama/core/posts/shares/src/gif_trim_timeline.dart';
import 'package:boorusama/core/posts/shares/src/gif_timeline_viewport.dart';
import 'package:boorusama/core/posts/shares/src/share_media_preparation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/material.dart';

void main() {
  test(
    'viewport preserves the pinch anchor and clamps scrolling at source bounds',
    () {
      final zoom = const GifTimelineViewport().zoom(
        scale: 5,
        anchor: .7,
        anchorX: .5,
        minimumSpan: .001,
      );
      expect(zoom.fractionAt(.5), closeTo(.7, .00001));
      expect(zoom.span, closeTo(.2, .00001));
      final next = zoom.zoom(
        scale: 2,
        anchor: zoom.fractionAt(.2),
        anchorX: .2,
        minimumSpan: .001,
      );
      expect(next.fractionAt(.2), closeTo(zoom.fractionAt(.2), .00001));
      expect(next.pan(-10).start, 0);
      expect(next.pan(10).end, closeTo(1, .00001));
      expect(
        next
            .zoom(scale: 10000, anchor: .7, anchorX: .5, minimumSpan: .001)
            .span,
        .001,
      );
    },
  );

  testWidgets(
    'first pinch centers selection, ruler pans, cursor follows and handles trim at zoomed scale',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const metadata = GifSourceMetadata(
        duration: Duration(seconds: 100),
        complete: true,
        width: 640,
        height: 480,
        rotationDegrees: 0,
        sampleAspectRatio: 1,
        frameRate: 30,
      );
      final source = GifPreparedSource(
        lease: ShareMediaLease(
          path: '/not-read.mp4',
          mimeType: 'video/mp4',
          deleteOnRelease: false,
        ),
        metadata: metadata,
      );
      var selection = GifEditorSelection.initial(metadata, 'video/mp4')
          .copyWith(
            start: const Duration(seconds: 48),
            end: const Duration(seconds: 52),
          );
      final position = ValueNotifier(const Duration(seconds: 50));
      var edits = 0;
      late StateSetter rebuild;
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(2),
                viewInsets: EdgeInsets.only(bottom: 200),
              ),
              child: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    rebuild = setState;
                    return GifTrimTimeline(
                      source: source,
                      selection: selection,
                      position: position,
                      onChanged: (value) => setState(() {
                        selection = value;
                        edits++;
                      }),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      final timeline = find.byKey(const ValueKey('gif-timeline'));
      final rect = tester.getRect(timeline);
      final originalWidth = tester
          .getSize(find.byKey(const ValueKey('gif-trim-window')))
          .width;
      Future<void> pinch(Offset center) async {
        final first = await tester.startGesture(
          center - const Offset(20, 0),
          pointer: 1,
        );
        final second = await tester.startGesture(
          center + const Offset(20, 0),
          pointer: 2,
        );
        await tester.pump();
        await first.moveTo(center - const Offset(35, 0));
        await second.moveTo(center + const Offset(35, 0));
        await tester.pump();
        await first.moveTo(center - const Offset(65, 0));
        await second.moveTo(center + const Offset(65, 0));
        await tester.pump();
        await first.up();
        await second.up();
        await tester.pump();
      }

      await pinch(rect.topLeft + const Offset(80, 50));
      expect(edits, 0);
      final window = find.byKey(const ValueKey('gif-trim-window'));
      expect(tester.getSize(window).width, greaterThan(originalWidth));
      expect(tester.getCenter(window).dx, closeTo(rect.center.dx, 1));
      final centered = tester.getCenter(window).dx;
      await tester.dragFrom(
        rect.topLeft + const Offset(150, 10),
        const Offset(35, 0),
      );
      await tester.pump();
      expect(edits, 0);
      expect(tester.getCenter(window).dx, greaterThan(centered));
      final beforeSecond = tester.getCenter(window).dx;
      await pinch(rect.topLeft + const Offset(150, 50));
      expect(edits, 0);
      expect(tester.getCenter(window).dx, greaterThan(beforeSecond));
      // Keep a short selection visible for cursor and trim checks.
      rebuild(
        () => selection = selection.copyWith(
          start: const Duration(seconds: 50),
          end: const Duration(seconds: 51),
        ),
      );
      await tester.pump();
      position.value = const Duration(seconds: 50);
      await tester.pump();
      final playhead = find.byKey(const ValueKey('gif-playhead'));
      expect(playhead, findsOneWidget);
      {
        final before = tester.getCenter(playhead).dx;
        position.value = const Duration(milliseconds: 50500);
        await tester.pump();
        expect(tester.getCenter(playhead).dx, greaterThan(before));
      }
      final previousEnd = selection.end;
      final previousStart = selection.start;
      await tester.drag(
        find.byKey(const ValueKey('gif-trim-1')),
        const Offset(-25, 0),
      );
      await tester.pump();
      expect(edits, greaterThan(0));
      expect(selection.end, lessThan(previousEnd));
      expect(selection.start, previousStart);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      position.dispose();
      await source.release();
    },
  );
}
