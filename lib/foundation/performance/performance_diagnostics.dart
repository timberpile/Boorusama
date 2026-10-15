import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/performance.dart';

import '../info/package_info.dart';

export 'package:foundation/performance.dart';

const _revision = String.fromEnvironment('BOORUSAMA_REVISION');
const _configuredVariant = String.fromEnvironment('BOORUSAMA_PERF_VARIANT');

String get performanceDiagnosticsBuildMode => kReleaseMode
    ? 'release'
    : kProfileMode
    ? 'profile'
    : 'debug';

String get performanceDiagnosticsVariant =>
    const {'baseline', 'fixed'}.contains(_configuredVariant)
    ? _configuredVariant
    : 'unspecified';

String performanceDiagnosticsFileName(DateTime time) {
  final utc = time.toUtc();
  String digits(int value, int width) => value.toString().padLeft(width, '0');
  final timestamp =
      '${digits(utc.year, 4)}${digits(utc.month, 2)}'
      '${digits(utc.day, 2)}T${digits(utc.hour, 2)}${digits(utc.minute, 2)}'
      '${digits(utc.second, 2)}${digits(utc.millisecond, 3)}Z';
  final revision = RegExp(r'^[a-fA-F0-9]{7,40}$').hasMatch(_revision)
      ? _revision.substring(0, 8)
      : 'unknown';
  return 'boorusama-performance-$performanceDiagnosticsBuildMode-'
      '$timestamp-$revision.json';
}

final performanceDiagnosticsProvider = Provider<PerformanceDiagnostics>((ref) {
  final service = PerformanceDiagnostics(
    performanceRecorder,
    available: ref.watch(isDevEnvironmentProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

class PerformanceDiagnostics extends ChangeNotifier
    with WidgetsBindingObserver {
  PerformanceDiagnostics(
    this.recorder, {
    this.available = kEnvironment == 'dev',
  });
  final bool available;
  final PerformanceRecorder recorder;
  Timer? _heartbeat;
  Timer? _limit;
  Timer? _drain;
  Completer<void>? _drained;
  var _attached = false;
  var _disposed = false;
  var _beats = 0;

  bool get draining => _drained != null;

  void start() {
    if (!available || _disposed || recorder.recording || draining || kIsWeb) {
      return;
    }
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final foreground =
        lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _updateRefreshRate();
    recorder.start(foreground: foreground);
    WidgetsBinding.instance.addObserver(this);
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _attached = true;
    if (foreground) _startHeartbeat();
    _limit = Timer(const Duration(minutes: 5), () => unawaited(stop()));
    notifyListeners();
  }

  /// Release timings are batched. Keep listening briefly but only accept frames
  /// whose actual timestamps fall inside the closed recording windows.
  Future<void> stop() {
    if (draining) return _drained!.future;
    if (!recorder.recording) return Future.value();
    recorder.stop();
    _heartbeat?.cancel();
    _heartbeat = null;
    _limit?.cancel();
    _limit = null;
    final done = _drained = Completer<void>();
    _drain = Timer(const Duration(milliseconds: 1300), () {
      _detach();
      _drained = null;
      done.complete();
      if (!_disposed) notifyListeners();
    });
    notifyListeners();
    return done.future;
  }

  void clear() {
    if (recorder.recording || draining) return;
    recorder.clear();
    notifyListeners();
  }

  void mark() => recorder.mark();

  Map<String, Object?> report() => {
    ...recorder.snapshot(),
    'diagnostic_tool': 'viewerSwipeV1',
    'diagnostic_features': ['viewerSwipeV1', 'cacheV1'],
    'environment': {
      'build_mode': performanceDiagnosticsBuildMode,
      'platform': defaultTargetPlatform.name,
      'flavor': kEnvironment,
      'variant': performanceDiagnosticsVariant,
      'revision': RegExp(r'^[a-fA-F0-9]{7,40}$').hasMatch(_revision)
          ? _revision
          : 'unspecified',
      'native_frame_timings': !kIsWeb,
    },
    'interpretation': {
      'async_spans_are_wall_time': true,
      'overlap_is_not_causation': true,
      'ui_delay_may_include_os_scheduling_or_debugger': true,
      'native_or_gpu_stacks_are_not_collected': true,
    },
  };

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _beats = 0;
    _heartbeat = Timer.periodic(const Duration(milliseconds: 100), (_) {
      recorder.heartbeat();
      if (++_beats % 10 != 0) return;
      final cache = PaintingBinding.instance.imageCache;
      recorder.recordImageCache(
        bytes: cache.currentSizeBytes,
        live: cache.liveImageCount,
        pending: cache.pendingImageCount,
      );
      // Only the diagnostics page listens, never the whole application shell.
      if (hasListeners) notifyListeners();
    });
  }

  void _onTimings(List<ui.FrameTiming> timings) {
    for (final timing in timings) {
      recorder.recordFrame(
        startUs: timing.timestampInMicroseconds(ui.FramePhase.vsyncStart),
        finishUs: timing.timestampInMicroseconds(ui.FramePhase.rasterFinish),
        buildUs: timing.buildDuration.inMicroseconds,
        rasterUs: timing.rasterDuration.inMicroseconds,
        vsyncOverheadUs: timing.vsyncOverhead.inMicroseconds,
      );
    }
  }

  void _updateRefreshRate() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    recorder.setContext(
      refreshRateHz: views.isEmpty ? 0 : views.first.display.refreshRate,
    );
  }

  @override
  void didChangeMetrics() => _updateRefreshRate();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!recorder.recording) return;
    final foreground = state == AppLifecycleState.resumed;
    recorder.setForeground(foreground);
    if (foreground) {
      _updateRefreshRate();
      _startHeartbeat();
    } else {
      _heartbeat?.cancel();
      _heartbeat = null;
    }
  }

  void _detach() {
    if (!_attached) return;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    WidgetsBinding.instance.removeObserver(this);
    _attached = false;
  }

  @override
  void dispose() {
    _disposed = true;
    recorder.stop();
    _heartbeat?.cancel();
    _limit?.cancel();
    _drain?.cancel();
    _detach();
    final done = _drained;
    _drained = null;
    if (done != null && !done.isCompleted) done.complete();
    super.dispose();
  }
}
