import 'package:boorusama/foundation/performance/performance_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/performance.dart';

void main() {
  testWidgets('screen categories survive navigation without copying route secrets', (tester) async {
    var clock = 1000000;
    final recorder = PerformanceRecorder(clock: () => clock)..start();
    final observer = PerformanceNavigationObserver(recorder: recorder);
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: key,
      navigatorObservers: [observer],
      home: const PerformanceScreenScope(
        screen: PerfScreen.searchGrid, priority: 0,
        child: Scaffold(body: SizedBox()),
      ),
    ));
    clock += 1000;
    key.currentState!.push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/secret-query?api_key=secret'),
      builder: (_) => const PerformanceScreenScope(
        screen: PerfScreen.bookmarks, priority: 2,
        child: PerformanceScreenScope(
          screen: PerfScreen.searchGrid, priority: 0,
          child: Scaffold(body: SizedBox()),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    recorder.mark();
    final report = recorder.snapshot();
    expect(report.toString(), isNot(contains('secret')));
    final marks = (report['events'] as List).where((e) => e['type'] == 'marker');
    expect(marks.last['screen'], 'bookmarks');
    clock += 1000;
    key.currentState!.pop();
    await tester.pumpAndSettle();
    recorder.mark();
    final restored = (recorder.snapshot()['events'] as List).where((e) => e['type'] == 'marker');
    expect(restored.last['screen'], 'searchGrid');
    await tester.pumpWidget(const SizedBox());
  });
}
