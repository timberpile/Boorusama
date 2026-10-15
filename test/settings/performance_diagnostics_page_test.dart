import 'dart:convert';
import 'dart:ui' as ui;

import 'package:boorusama/core/settings/src/pages/performance_diagnostics_page.dart';
import 'package:boorusama/foundation/info/package_info.dart';
import 'package:boorusama/foundation/performance/performance_diagnostics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';

void main() {
  setUpAll(() => ensureI18nInitialized('en-US'));

  testWidgets('production flavor refuses recording', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [currentEnvironmentProvider.overrideWithValue('prod')],
    );
    addTearDown(container.dispose);
    final diagnostics = container.read(performanceDiagnosticsProvider);
    diagnostics.start();
    expect(diagnostics.recorder.recording, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(diagnostics.recorder.recording, isFalse);
    expect(diagnostics.draining, isFalse);
  });

  testWidgets('narrow large-text controls record, mark, stop, copy and clear', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final recorder = PerformanceRecorder();
    final diagnostics = PerformanceDiagnostics(recorder);
    addTearDown(diagnostics.dispose);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments! as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          performanceDiagnosticsProvider.overrideWithValue(diagnostics),
        ],
        child: BooruLocalization(
          child: MaterialApp(
            builder: (context, child) => KurumiTheme(
              data: KurumiThemeData.fromMaterial(Theme.of(context)),
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                ),
                child: child!,
              ),
            ),
            home: const PerformanceDiagnosticsPage(),
          ),
        ),
      ),
    );
    Future<void> tap(String text) async {
      await tester.scrollUntilVisible(find.text(text), 150);
      await tester.pump();
      await tester.tap(find.text(text));
      await tester.pump();
    }

    expect(recorder.recording, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(recorder.recording, isFalse);
    await tap('Start new recording');
    expect(recorder.recording, isTrue);
    await tap('Add marker');
    expect(
      (recorder.snapshot()['events']! as List).where(
        (e) => e['type'] == 'marker',
      ),
      hasLength(1),
    );
    await tap('Stop recording');
    expect(diagnostics.draining, isTrue);
    await tester.pump(const Duration(milliseconds: 1400));
    expect(diagnostics.draining, isFalse);
    await tap('Start new recording');
    expect(recorder.recording, isTrue);
    await tap('Copy report');
    expect(recorder.recording, isFalse);
    await tester.pump(const Duration(milliseconds: 1400));
    // compute uses a real isolate; fake widget time cannot complete its work.
    await tester.runAsync(() async {
      for (var i = 0; copied == null && i < 100; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();
    expect(copied, isNotNull);
    expect((jsonDecode(copied!) as Map)['events'], isNotEmpty);
    expect(recorder.recording, isFalse);
    await tap('Clear report');
    expect(recorder.hasSession, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('adapter drains historical frames and excludes background work', (
    tester,
  ) async {
    var clock = 1000000;
    final recorder = PerformanceRecorder(clock: () => clock);
    final diagnostics = PerformanceDiagnostics(recorder);
    diagnostics.start();
    recorder.setContext(screen: PerfScreen.bookmarks);
    final frame = ui.FrameTiming(
      vsyncStart: clock,
      buildStart: clock + 1000,
      buildFinish: clock + 25000,
      rasterStart: clock + 26000,
      rasterFinish: clock + 30000,
      rasterFinishWallTime: clock + 30000,
    );
    clock += 40000;
    diagnostics.didChangeAppLifecycleState(AppLifecycleState.paused);
    clock += 1000000;
    diagnostics.didChangeAppLifecycleState(AppLifecycleState.resumed);
    recorder.setContext(screen: PerfScreen.postViewer);
    final stopped = diagnostics.stop();
    tester.binding.platformDispatcher.onReportTimings!([frame]);
    expect(recorder.frameCount, 1);
    final events = recorder.snapshot()['events']! as List;
    expect(
      events.singleWhere((e) => e['type'] == 'slow_frame')['screen'],
      'bookmarks',
    );
    await tester.pump(const Duration(milliseconds: 1400));
    await stopped;
    expect(diagnostics.draining, isFalse);
    diagnostics.dispose();
  });
}
