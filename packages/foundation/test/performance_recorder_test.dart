import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/performance.dart';

class _Clock {
  int time = 1000000;
  int reads = 0;
  int call() { reads++; return time; }
  void advance(int us) { time += us; }
}

List<Map<String, Object?>> _events(PerformanceRecorder r, String type) =>
    (r.snapshot()['events'] as List).cast<Map<String, Object?>>()
        .where((e) => e['type'] == type).toList();

void main() {
  test('disabled recording does not read clocks, retain events or change results', () async {
    final clock = _Clock();
    final recorder = PerformanceRecorder(clock: clock.call);
    expect(recorder.measureSync(PerfOperation.gridFilter, () => 7), 7);
    expect(await recorder.measureAsync(PerfOperation.cacheRead, () async => 9), 9);
    recorder.begin(PerfOperation.gridFilter, PerfSpanKind.sync).finish();
    expect(clock.reads, 0);
    expect(recorder.retainedEvents, 0);
  });

  test('fast operations are aggregated without retaining a detail for every call', () {
    final clock = _Clock();
    final recorder = PerformanceRecorder(clock: clock.call)..start();
    for (var i = 0; i < 10; i++) {
      recorder.measureSync(PerfOperation.gridFilter, () => clock.advance(500));
    }
    expect(_events(recorder, 'span'), isEmpty);
    final summary = recorder.snapshot()['summary'] as Map;
    final operations = summary['operations'] as List;
    expect((operations.single as Map)['count'], 10);
    expect((operations.single as Map)['total_us'], 5000);
  });

  test('instrumentation preserves exceptions without recording their contents', () {
    final clock = _Clock();
    final recorder = PerformanceRecorder(clock: clock.call)..start();
    final error = StateError('private-url-secret');
    expect(() => recorder.measureSync(PerfOperation.exportEncode, () => throw error),
        throwsA(same(error)));
    expect(_events(recorder, 'span').single['failed'], true);
    expect(recorder.snapshot().toString(), isNot(contains('private-url-secret')));
  });

  test('async failures are preserved and explicitly measured as wall time', () async {
    final clock = _Clock();
    final recorder = PerformanceRecorder(clock: clock.call)..start();
    final error = StateError('secret');
    await expectLater(recorder.measureAsync<void>(PerfOperation.cacheRead, () async {
      clock.advance(50000);
      throw error;
    }), throwsA(same(error)));
    final event = _events(recorder, 'span').single;
    expect(event['kind'], 'asyncWall');
    expect(event['duration_us'], 50000);
    expect(event['failed'], true);
  });

  test('release callback arrival does not change a frame screen or refresh budget', () {
    final clock = _Clock();
    final recorder = PerformanceRecorder(clock: clock.call);
    recorder.setContext(screen: PerfScreen.bookmarks, refreshRateHz: 120);
    recorder.start();
    final frameStart = clock.time;
    clock.advance(30000);
    recorder.setContext(screen: PerfScreen.postViewer, refreshRateHz: 60);
    clock.advance(1000000);
    recorder.recordFrame(startUs: frameStart, finishUs: frameStart + 20000,
        buildUs: 9000, rasterUs: 4000, vsyncOverheadUs: 1000);
    final event = _events(recorder, 'slow_frame').single;
    expect(event['screen'], 'bookmarks');
    expect(event['budget_us'], 8333);
    expect(event['t_us'], 0);
    expect(event['over_budget'], true);
  });

  test('high pipeline latency is distinguished from a build or raster budget miss', () {
    final clock = _Clock();
    final recorder = PerformanceRecorder(clock: clock.call)..start();
    final start = clock.time;
    clock.advance(80000);
    recorder.recordFrame(startUs: start, finishUs: start + 70000,
        buildUs: 1000, rasterUs: 1000, vsyncOverheadUs: 50000);
    final event = _events(recorder, 'slow_frame').single;
    expect(event['over_budget'], false);
    expect(event['high_latency'], true);
    expect(recorder.overBudgetFrames, 0);
  });

  test('fast frames are counted but idle time is not treated as missing frames', () {
    final clock = _Clock();
    final recorder = PerformanceRecorder(clock: clock.call)..start();
    final start = clock.time;
    clock.advance(5000000);
    recorder.recordFrame(startUs: start, finishUs: start + 8000,
        buildUs: 1000, rasterUs: 2000, vsyncOverheadUs: 1000);
    expect(recorder.frameCount, 1);
    expect(_events(recorder, 'slow_frame'), isEmpty);
    expect(recorder.uiDelayCount, 0);
  });

  test('foreground scheduling delay is detected even when no frame is submitted', () {
    final clock = _Clock();
    final recorder = PerformanceRecorder(clock: clock.call)..start();
    clock.advance(180000);
    recorder.heartbeat();
    expect(_events(recorder, 'ui_delay').single['duration_us'], 80000);
    expect(recorder.frameCount, 0);
    clock.advance(100000);
    recorder.heartbeat();
    expect(recorder.uiDelayCount, 1);
  });

  test('background time and work crossing a lifecycle boundary are not called lag', () {
    final clock = _Clock();
    final recorder = PerformanceRecorder(clock: clock.call)..start();
    final span = recorder.begin(PerfOperation.cacheRead, PerfSpanKind.asyncWall);
    recorder.setForeground(false);
    clock.advance(20000000);
    recorder.setForeground(true);
    clock.advance(100000);
    recorder.heartbeat();
    span.finish();
    expect(recorder.uiDelayCount, 0);
    expect(_events(recorder, 'span'), isEmpty);
    expect((recorder.snapshot()['coverage'] as Map)['interrupted_spans'], 1);
  });

  test('the stop drain accepts earlier frames but excludes post-stop work', () {
    final clock = _Clock();
    final recorder = PerformanceRecorder(clock: clock.call)..start();
    final start = clock.time;
    clock.advance(50000);
    recorder.stop();
    clock.advance(1000000);
    recorder.recordFrame(startUs: start, finishUs: start + 40000,
        buildUs: 30000, rasterUs: 5000, vsyncOverheadUs: 1000);
    recorder.recordFrame(startUs: start + 60000, finishUs: start + 100000,
        buildUs: 30000, rasterUs: 5000, vsyncOverheadUs: 1000);
    expect(recorder.frameCount, 1);
    expect((recorder.snapshot()['coverage'] as Map)['rejected_frames'], 1);
  });

  test('finishing old work cannot contaminate a new session or double count', () {
    final clock = _Clock();
    final recorder = PerformanceRecorder(clock: clock.call)..start();
    final old = recorder.begin(PerfOperation.cacheRead, PerfSpanKind.asyncWall);
    recorder.stop();
    recorder.start();
    old.finish();
    final current = recorder.begin(PerfOperation.gridFilter, PerfSpanKind.sync);
    clock.advance(5000);
    current.finish();
    current.finish();
    expect(_events(recorder, 'span'), hasLength(1));
    expect(_events(recorder, 'span').single['op'], 'gridFilter');
  });

  test('detail retention is bounded while aggregate totals remain complete', () {
    final clock = _Clock();
    final recorder = PerformanceRecorder(clock: clock.call, eventCapacity: 3)..start();
    for (var i = 0; i < 10; i++) {
      recorder.measureSync(PerfOperation.gridFilter, () => clock.advance(5000));
    }
    expect(recorder.retainedEvents, 3);
    expect((recorder.snapshot()['coverage'] as Map)['evicted_events'], 8);
    final summary = recorder.snapshot()['summary'] as Map;
    expect(((summary['operations'] as List).single as Map)['count'], 10);
  });

  test('active operation retention is bounded and overflow is visible', () {
    final clock = _Clock();
    final recorder = PerformanceRecorder(clock: clock.call, activeSpanCapacity: 1)..start();
    final first = recorder.begin(PerfOperation.cacheRead, PerfSpanKind.asyncWall);
    final overflow = recorder.begin(PerfOperation.cacheRead, PerfSpanKind.asyncWall);
    clock.advance(5000);
    first.finish();
    overflow.finish();
    expect(_events(recorder, 'span'), hasLength(1));
    expect((recorder.snapshot()['coverage'] as Map)['unrecorded_spans'], 1);
  });

  test('unavailable historical context is reported instead of guessed', () {
    final clock = _Clock();
    final recorder = PerformanceRecorder(clock: clock.call, contextCapacity: 1)..start();
    final start = clock.time;
    clock.advance(50000);
    recorder.setContext(screen: PerfScreen.postViewer);
    recorder.recordFrame(startUs: start, finishUs: start + 30000,
        buildUs: 20000, rasterUs: 5000, vsyncOverheadUs: 1000);
    expect(recorder.frameCount, 0);
    expect((recorder.snapshot()['coverage'] as Map)['frames_without_context'], 1);
  });

  test('frames from other clock domains and earlier sessions are rejected', () {
    final clock = _Clock();
    final recorder = PerformanceRecorder(clock: clock.call)..start();
    for (final start in [0, 1000000000000000000]) {
      recorder.recordFrame(startUs: start, finishUs: start + 40000,
          buildUs: 30000, rasterUs: 5000, vsyncOverheadUs: 1000);
    }
    expect(recorder.frameCount, 0);
    expect((recorder.snapshot()['coverage'] as Map)['rejected_frames'], 2);
  });

  test('snapshots remain stable across further recording and clearing', () {
    final clock = _Clock();
    final recorder = PerformanceRecorder(clock: clock.call)..start();
    recorder.measureSync(PerfOperation.gridFilter, () => clock.advance(5000));
    final snapshot = recorder.snapshot();
    final saved = snapshot.toString();
    recorder.measureSync(PerfOperation.gridFilter, () => clock.advance(9000));
    recorder.clear();
    expect(snapshot.toString(), saved);
  });
}
