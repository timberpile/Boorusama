import 'package:boorusama/core/posts/shares/src/gif_conversion_service.dart';
import 'package:boorusama/core/posts/shares/src/gif_editor_selection.dart';
import 'package:boorusama/core/posts/shares/src/gif_export_contract.dart';
import 'package:boorusama/core/posts/shares/src/gif_loop_video_preview.dart';
import 'package:boorusama/core/posts/shares/src/gif_loop_refinement_service.dart';
import 'package:boorusama/core/posts/shares/src/gif_trim_editor.dart';
import 'package:boorusama/core/posts/shares/src/gif_trim_boundary_controls.dart';
import 'package:boorusama/core/posts/shares/src/gif_trim_navigation.dart';
import 'package:boorusama/core/posts/shares/src/share_media_preparation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart'
    show TranslationProvider, LocaleSettings, AppLocale;
import 'package:kurumi/material.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  late GifPreparedSource source;
  late GifEditorSelection selection;
  late GifTrimNavigation navigation;
  Future<(Duration, Duration)?>? result;

  setUp(() {
    final lease = _Lease();
    when(() => lease.mimeType).thenReturn('video/mp4');
    when(() => lease.release()).thenAnswer((_) async {});
    source = GifPreparedSource(
      lease: lease,
      metadata: const GifSourceMetadata(
        duration: Duration(minutes: 2),
        complete: true,
        width: 640,
        height: 480,
        rotationDegrees: 0,
        sampleAspectRatio: 1,
        frameRate: 30,
      ),
    );
    selection = GifEditorSelection.initial(
      source.metadata,
      'video/mp4',
    ).copyWith(speedPreset: 2);
    navigation = GifTrimNavigation(selection.sourceDuration);
    result = null;
  });
  tearDown(() => navigation.dispose());

  Future<void> open(WidgetTester tester, {double textScale = 1}) async {
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                key: const ValueKey('open'),
                child: const Text('Open'),
                onPressed: () {
                  result = Navigator.of(context).push<(Duration, Duration)>(
                    MaterialPageRoute(
                      builder: (_) => GifTrimEditor(
                        source: source,
                        service: _Conversion(),
                        selection: selection,
                        navigation: navigation,
                        refiner: _Refiner(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
  }

  Future<void> browse(WidgetTester tester, double fraction) async {
    final overview = find.byKey(const ValueKey('gif-trim-overview'));
    await tester.ensureVisible(overview);
    await tester.pumpAndSettle();
    final rect = tester.getRect(overview);
    await tester.tapAt(
      Offset(rect.left + rect.width * fraction, rect.center.dy),
    );
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, String key) async {
    if (key.startsWith('gif-trim-speed-')) {
      await press(tester, 'gif-trim-speed');
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
      return;
    }
    final target = find.byKey(ValueKey(key));
    await tester.scrollUntilVisible(
      target,
      key == 'gif-trim-speed' ? -100 : 100,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .last,
    );
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  for (final locale in [AppLocale.enUs, AppLocale.deDe]) {
    testWidgets(
      '1152x720 preview and main actions fit without scrolling (${locale.languageCode})',
      (tester) async {
        await tester.runAsync(() => LocaleSettings.setLocale(locale));
        addTearDown(() => LocaleSettings.setLocale(AppLocale.enUs));
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        source = GifPreparedSource(
          lease: source.lease,
          metadata: const GifSourceMetadata(
            duration: Duration(seconds: 2),
            complete: true,
            width: 1152,
            height: 720,
            rotationDegrees: 0,
            sampleAspectRatio: 1,
            frameRate: 30,
          ),
        );
        selection = GifEditorSelection.initial(
          source.metadata,
          'video/mp4',
        ).copyWith(end: const Duration(seconds: 1));
        navigation.dispose();
        navigation = GifTrimNavigation(selection.sourceDuration);
        await open(tester);
        final size = tester.getSize(find.byType(GifLoopVideoPreview));
        expect(size.width / size.height, closeTo(1.6, .0001));
        expect(size.width, greaterThan(300));
        expect(
          tester
              .getRect(find.byKey(const ValueKey('gif-trim-source')))
              .center
              .dy,
          closeTo(
            tester
                .getRect(find.byKey(const ValueKey('gif-trim-speed')))
                .center
                .dy,
            4,
          ),
        );
        for (final key in [
          'gif-trim-overview',
          'gif-trim-start-here',
          'gif-trim-end-here',
          'gif-refine-loop',
          'gif-trim-speed',
          'gif-trim-apply',
        ]) {
          expect(
            find.byKey(ValueKey(key)).hitTestable(),
            findsOneWidget,
            reason:
                '$key: ${find.byKey(ValueKey(key)).evaluate().isEmpty ? "absent" : tester.getRect(find.byKey(ValueKey(key)))}',
          );
        }
        expect(tester.takeException(), isNull);
        await press(tester, 'gif-trim-cancel');
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final locale in [AppLocale.enUs, AppLocale.deDe]) {
    testWidgets(
      'six boundary buttons keep one row and step only their edge (${locale.languageCode})',
      (tester) async {
        await tester.runAsync(() => LocaleSettings.setLocale(locale));
        addTearDown(() => LocaleSettings.setLocale(AppLocale.enUs));
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        selection = selection.copyWith(
          start: const Duration(seconds: 1),
          end: const Duration(seconds: 2),
          sourceFrameRate: 5,
        );
        await open(tester, textScale: 2);
        await tester.scrollUntilVisible(
          find.byType(GifTrimBoundaryControls),
          100,
          scrollable: find
              .byWidgetPredicate(
                (widget) =>
                    widget is Scrollable &&
                    widget.axisDirection == AxisDirection.down,
              )
              .last,
        );
        await tester.ensureVisible(find.byType(GifTrimBoundaryControls));
        await tester.pumpAndSettle();
        final keys = [
          'start-back',
          'start-forward',
          'start-here',
          'end-back',
          'end-forward',
          'end-here',
        ];
        final rowY = tester
            .getCenter(find.byKey(ValueKey('gif-trim-${keys.first}')))
            .dy;
        for (final key in keys) {
          final target = find.byKey(ValueKey('gif-trim-$key'));
          expect(target.hitTestable(), findsOneWidget);
          expect(tester.getCenter(target).dy, closeTo(rowY, .01));
          expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
          expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
          expect(tester.widget<IconButton>(target).tooltip, isNotEmpty);
        }
        await press(tester, 'gif-trim-start-back');
        final changed = tester
            .widget<GifLoopVideoPreview>(find.byType(GifLoopVideoPreview))
            .selection;
        expect(changed.start.inMicroseconds, 1000000 - 33333);
        expect(changed.end, selection.end);
        await press(tester, 'gif-trim-start-forward');
        await press(tester, 'gif-trim-end-back');
        final movedEnd = tester
            .widget<GifLoopVideoPreview>(find.byType(GifLoopVideoPreview))
            .selection;
        expect(movedEnd.start, selection.start);
        expect(movedEnd.end.inMicroseconds, 2000000 - 33333);
        await press(tester, 'gif-trim-end-forward');
        await press(tester, 'gif-trim-apply');
        expect(await result, (selection.start, selection.end));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final startHere in [true, false]) {
    testWidgets(
      'setting ${startHere ? "start after" : "end before"} the selection opens the remaining source',
      (tester) async {
        selection = selection.copyWith(
          start: const Duration(seconds: 40),
          end: const Duration(seconds: 60),
        );
        await open(tester);
        await browse(tester, startHere ? 5 / 6 : 1 / 6);
        await press(
          tester,
          startHere ? 'gif-trim-start-here' : 'gif-trim-end-here',
        );
        await press(tester, 'gif-trim-apply');
        final range = await result;
        expect(range!.$1.inMicroseconds, closeTo(startHere ? 100000000 : 0, 1));
        expect(
          range.$2.inMicroseconds,
          closeTo(startHere ? 120000000 : 20000000, 1),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('Start/End here edit a draft; Apply returns only its boundaries', (
    tester,
  ) async {
    await open(tester);
    await browse(tester, 1 / 3);
    await press(tester, 'gif-trim-start-here');
    await browse(tester, .5);
    await press(tester, 'gif-trim-end-here');
    // The export selection is immutable and has not been replaced by the dialog.
    expect(selection.start, Duration.zero);
    expect(selection.end, const Duration(minutes: 2));
    await press(tester, 'gif-trim-apply');
    final trimmed = await result;
    expect(trimmed!.$1.inMicroseconds, closeTo(40000000, 1));
    expect(trimmed.$2.inMicroseconds, closeTo(60000000, 1));
    expect(selection.speedPreset, 2);
    expect(navigation.visibleDuration.inMicroseconds, closeTo(40000000, 2));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Cancel discards trim; preview slowdown does not change GIF speed',
    (tester) async {
      await open(tester);
      await browse(tester, .25);
      await press(tester, 'gif-trim-start-here');
      await press(tester, 'gif-trim-speed-0.25');
      expect(navigation.previewSpeed, .25);
      expect(selection.speedPreset, 2);
      await press(tester, 'gif-trim-cancel');
      expect(await result!, isNull);
      expect(selection.start, Duration.zero);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'both navigation levels and actions fit narrow enlarged-text layouts',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester, textScale: 2);
      await browse(tester, .4);
      await press(tester, 'gif-trim-start-here');
      await press(tester, 'gif-trim-speed-0.5');
      expect(tester.takeException(), isNull);
      await press(tester, 'gif-trim-cancel');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _Lease extends Mock implements ShareMediaLease {}

class _Conversion extends Mock implements GifConversionService {}

class _Refiner extends Mock implements GifLoopRefiner {}
