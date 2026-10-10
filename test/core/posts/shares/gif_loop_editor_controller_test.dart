import 'dart:async';

import 'package:boorusama/core/posts/shares/src/gif_conversion_service.dart';
import 'package:boorusama/core/posts/shares/src/gif_editor_controller.dart';
import 'package:boorusama/core/posts/shares/src/gif_editor_selection.dart';
import 'package:boorusama/core/posts/shares/src/gif_export_contract.dart';
import 'package:boorusama/core/posts/shares/src/gif_loop_editor_actions.dart';
import 'package:boorusama/core/posts/shares/src/gif_loop_refinement.dart';
import 'package:boorusama/core/posts/shares/src/gif_loop_refinement_service.dart';
import 'package:boorusama/core/posts/shares/src/share_media_preparation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  late GifEditorController controller;
  late _Refiner refiner;
  setUp(() {
    refiner = _Refiner();
    final lease = _Lease();
    when(() => lease.mimeType).thenReturn('video/mp4');
    controller = GifEditorController(
      source: GifPreparedSource(lease: lease, metadata: const GifSourceMetadata(
        duration: Duration(seconds: 5), complete: true, width: 640, height: 480,
        rotationDegrees: 0, sampleAspectRatio: 1, frameRate: 30,
      )),
      service: _Conversion(), loopRefiner: refiner,
    );
  });
  tearDown(() { if (!refiner.disposed) controller.dispose(); });

  void select() => controller.update(controller.selection.copyWith(
    start: const Duration(milliseconds: 100), end: const Duration(milliseconds: 1100),
  ));
  const match = GifLoopResult.match(GifLoopMatchKind.repeatedSequence, 0, 1000000);

  test('hidden on full source; successful refinement has trim-only Undo', () async {
    expect(controller.showRefineLoop, isFalse);
    select();
    final before = controller.selection;
    expect(controller.showRefineLoop, isTrue);
    final job = controller.refineLoop();
    refiner.result.complete(match);
    await job;
    expect(controller.selection.start, Duration.zero);
    expect(controller.selection.end, const Duration(seconds: 1));
    expect(controller.selection.resolution, before.resolution);
    controller.update(controller.selection.copyWith(sourceFrameRate: 1));
    controller.undoRefinement();
    expect(controller.selection.start, before.start);
    expect(controller.selection.end, before.end);
    expect(controller.selection.sourceFrameRate, 1);
    expect(controller.canUndoRefinement, isFalse);
  });

  test('no-match result leaves the selection object unchanged', () async {
    select();
    final before = controller.selection;
    final job = controller.refineLoop();
    refiner.result.complete(const GifLoopResult.noMatch());
    await job;
    expect(controller.selection, same(before));
    expect(controller.canUndoRefinement, isFalse);
  });

  test('manual changes cancel and suppress even a successful stale result', () async {
    select();
    final job = controller.refineLoop();
    final newer = controller.selection.copyWith(end: const Duration(seconds: 2));
    controller.update(newer);
    expect(refiner.token!.isCancelled, isTrue);
    refiner.result.complete(match);
    await job;
    expect(controller.selection, same(newer));
    expect(controller.loopResult, isNull);
  });

  test('explicit cancellation keeps the original selection', () async {
    select();
    final before = controller.selection;
    final job = controller.refineLoop();
    controller.cancelRefinement();
    refiner.result.complete(match);
    await job;
    expect(controller.selection, same(before));
    expect(controller.isRefining, isFalse);
  });

  test('closing route cancels outstanding work and suppresses notification', () async {
    select();
    final job = controller.refineLoop();
    controller.dispose();
    refiner.disposed = true;
    expect(refiner.token!.isCancelled, isTrue);
    refiner.result.complete(match);
    await job;
  });

  test('rejects backend boundaries outside the requested search radius', () async {
    select();
    final before = controller.selection;
    final job = controller.refineLoop();
    refiner.result.complete(const GifLoopResult.match(GifLoopMatchKind.seamOnly, 0, 2000000));
    await job;
    expect(controller.selection, same(before));
    expect(controller.loopResult!.matched, isFalse);
  });

  testWidgets('actions appear after trimming and fit narrow enlarged-text layout', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(TranslationProvider(child: MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: Scaffold(body: SingleChildScrollView(
          child: GifLoopEditorActions(controller: controller),
        )),
      ),
    )));
    expect(find.byKey(const ValueKey('gif-refine-loop')), findsNothing);
    select();
    await tester.pump();
    expect(find.byKey(const ValueKey('gif-refine-loop')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('gif-refine-loop')));
    await tester.pump();
    expect(find.byKey(const ValueKey('gif-refine-cancel')), findsOneWidget);
    refiner.result.complete(match);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('gif-refine-undo')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Lease extends Mock implements ShareMediaLease {}
class _Conversion extends Mock implements GifConversionService {}
class _Refiner implements GifLoopRefiner {
  final result = Completer<GifLoopResult>();
  CancelToken? token;
  var disposed = false;
  @override
  Future<GifLoopResult> refine({required GifPreparedSource source,
    required GifEditorSelection selection, required CancelToken cancelToken}) {
    token = cancelToken;
    return result.future;
  }
}
