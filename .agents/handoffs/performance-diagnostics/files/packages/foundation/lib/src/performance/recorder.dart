import 'dart:collection';
import 'dart:developer' as developer;

/// Fixed vocabulary: never pass URLs, queries, post IDs or user-supplied labels.
enum PerfScreen {
  other,
  dialog,
  searchGrid,
  bookmarks,
  bookmarkGroups,
  followingFeeds,
  followingFeed,
  postViewer,
  diagnostics,
}

enum PerfOperation {
  cacheQueueWait,
  cacheInitialize,
  cacheRead,
  cacheTrim,
  cacheEvictionScan,
  cacheCheckpoint,
  cacheIndexEncode,
  bookmarkDecodeAll,
  bookmarkSelect,
  bookmarkLibraryLoad,
  gridCountPayload,
  gridFilter,
  feedRepositoryRead,
  mixedPreloadResolve,
  exportEncode,
  exportPackage,
}

/// asyncWall includes waiting and MUST NOT be interpreted as CPU time.
enum PerfSpanKind { sync, asyncWall }

final performanceRecorder = PerformanceRecorder();

/// Process-local recorder. Native timestamps use the VM/engine monotonic clock.
/// Collection is deliberately separate from serialization and file I/O.
class PerformanceRecorder {
  PerformanceRecorder({
    int Function()? clock,
    this.eventCapacity = 2048,
    this.contextCapacity = 512,
    this.activeSpanCapacity = 128,
    this.spanDetailThresholdUs = 2000,
  }) : _clock = clock ?? _timelineNow {
    if (eventCapacity < 1 || contextCapacity < 1 || activeSpanCapacity < 1 ||
        spanDetailThresholdUs < 0) {
      throw ArgumentError('Invalid performance recorder limits');
    }
  }

  static int _timelineNow() => developer.Timeline.now;
  final int Function() _clock;
  final int eventCapacity;
  final int contextCapacity;
  final int activeSpanCapacity;
  final int spanDetailThresholdUs;
  final _events = ListQueue<Map<String, Object?>>();
  final _contexts = <_Context>[];
  final _windows = <_Window>[];
  final _active = <int, PerfSpan>{};
  final _operations = <(PerfOperation, PerfSpanKind), _Distribution>{};
  var _build = _Distribution();
  var _raster = _Distribution();
  var _latency = _Distribution();
  var _delay = _Distribution();
  var _generation = 0;
  var _nextId = 0;
  int? _start;
  int? _stop;
  int? _lastHeartbeat;
  var _recording = false;
  var _foreground = true;
  var _screen = PerfScreen.other;
  var _budgetUs = 16667;
  var _budgetEstimated = true;
  var _overBudget = 0;
  var _highLatency = 0;
  var _droppedEvents = 0;
  var _droppedSpans = 0;
  var _interruptedSpans = 0;
  var _rejectedFrames = 0;
  var _missingContexts = 0;

  bool get recording => _recording;
  bool get enabled => _recording && _foreground;
  bool get hasSession => _start != null;
  int get frameCount => _build.count;
  int get overBudgetFrames => _overBudget;
  int get uiDelayCount => _delay.count;
  int get retainedEvents => _events.length;
  int get nowUs => _clock();

  void start({bool foreground = true}) {
    clear();
    _start = _clock();
    _recording = true;
    _foreground = foreground;
    _contexts.add(_Context(_start!, _screen, _budgetUs, _budgetEstimated));
    if (foreground) _openWindow();
    _event({'type': 'session_start', 't_us': 0});
  }

  void stop() {
    if (!_recording) return;
    final now = _clock();
    _closeWindow(now);
    _stop = now;
    _recording = false;
    _invalidateSpans();
    _event({'type': 'session_stop', 't_us': _relative(now)});
  }

  void clear() {
    _generation++;
    _active.clear();
    _events.clear();
    _contexts.clear();
    _windows.clear();
    _operations.clear();
    _build = _Distribution();
    _raster = _Distribution();
    _latency = _Distribution();
    _delay = _Distribution();
    _start = null;
    _stop = null;
    _lastHeartbeat = null;
    _recording = false;
    _nextId = 0;
    _overBudget = 0;
    _highLatency = 0;
    _droppedEvents = 0;
    _droppedSpans = 0;
    _interruptedSpans = 0;
    _rejectedFrames = 0;
    _missingContexts = 0;
  }

  void setForeground(bool foreground) {
    if (_foreground == foreground) return;
    _foreground = foreground;
    if (!_recording) return;
    final now = _clock();
    if (foreground) {
      _openWindow();
    } else {
      _closeWindow(now);
      _invalidateSpans();
    }
    _event({
      'type': 'lifecycle', 't_us': _relative(now), 'foreground': foreground,
    });
  }

  void setContext({PerfScreen? screen, double? refreshRateHz}) {
    final nextScreen = screen ?? _screen;
    final rateValid = refreshRateHz != null && refreshRateHz.isFinite &&
        refreshRateHz >= 20 && refreshRateHz <= 500;
    final nextBudget = refreshRateHz == null ? _budgetUs :
        rateValid ? (1000000 / refreshRateHz).round() : 16667;
    final estimated = refreshRateHz == null ? _budgetEstimated : !rateValid;
    if (nextScreen == _screen && nextBudget == _budgetUs &&
        estimated == _budgetEstimated) return;
    _screen = nextScreen;
    _budgetUs = nextBudget;
    _budgetEstimated = estimated;
    if (!_recording) return;
    final now = _clock();
    if (_contexts.length == contextCapacity) _contexts.removeAt(0);
    _contexts.add(_Context(now, _screen, _budgetUs, estimated));
    _event({
      'type': 'context', 't_us': _relative(now), 'screen': _screen.name,
      'budget_us': _budgetUs, 'budget_estimated': estimated,
    });
  }

  /// A fixed marker helps identify a manual reproduction without storing text.
  void mark() {
    if (enabled) _event({
      'type': 'marker', 't_us': _relative(_clock()), 'screen': _screen.name,
    });
  }

  PerfSpan begin(PerfOperation operation, PerfSpanKind kind, {int? items}) {
    if (!enabled) return const PerfSpan._disabled();
    if (_active.length >= activeSpanCapacity) {
      _droppedSpans++;
      return const PerfSpan._disabled();
    }
    final span = PerfSpan._(
      this, ++_nextId, _generation, operation, kind, _clock(), _screen, items,
    );
    _active[span.id] = span;
    return span;
  }

  T measureSync<T>(PerfOperation op, T Function() action, {int? items}) {
    if (!enabled) return action();
    final span = begin(op, PerfSpanKind.sync, items: items);
    var failed = false;
    try {
      return action();
    } catch (_) {
      failed = true;
      rethrow;
    } finally {
      span.finish(failed: failed);
    }
  }

  Future<T> measureAsync<T>(
    PerfOperation op, Future<T> Function() action, {int? items}
  ) {
    if (!enabled) return action();
    return _measureAsync(op, action, items);
  }

  Future<T> _measureAsync<T>(
    PerfOperation op, Future<T> Function() action, int? items
  ) async {
    final span = begin(op, PerfSpanKind.asyncWall, items: items);
    var failed = false;
    try {
      return await action();
    } catch (_) {
      failed = true;
      rethrow;
    } finally {
      span.finish(failed: failed);
    }
  }

  void _finish(PerfSpan span, bool failed) {
    if (span.generation != _generation || _active.remove(span.id) == null) {
      return;
    }
    final end = _clock();
    final duration = end - span.start;
    if (duration < 0) return;
    _operations.putIfAbsent((span.operation, span.kind), _Distribution.new)
        .add(duration);
    if (duration < spanDetailThresholdUs && !failed) return;
    _event({
      'type': 'span', 't_us': _relative(span.start), 'duration_us': duration,
      'op': span.operation.name, 'kind': span.kind.name,
      'screen': span.screen.name, 'id': span.id, 'failed': failed,
      if (span.items != null) 'items': span.items,
    });
  }

  /// Called with engine timestamps, NOT the delayed callback-arrival time.
  /// Frames from a previous session, background intervals or a different clock
  /// domain are excluded instead of being attributed to the current route.
  void recordFrame({
    required int startUs,
    required int finishUs,
    required int buildUs,
    required int rasterUs,
    required int vsyncOverheadUs,
  }) {
    if (_start == null) return;
    if (finishUs < startUs || startUs < _start! ||
        finishUs > _clock() + 1000 ||
        buildUs < 0 || rasterUs < 0 || vsyncOverheadUs < 0 ||
        !_inWindow(startUs, finishUs)) {
      _rejectedFrames++;
      return;
    }
    final context = _contextAt(startUs);
    if (context == null) {
      _missingContexts++;
      return;
    }
    final total = finishUs - startUs;
    _build.add(buildUs);
    _raster.add(rasterUs);
    _latency.add(total);
    final missedBudget = buildUs > context.budgetUs || rasterUs > context.budgetUs;
    final highLatency = total > context.budgetUs * 2;
    if (missedBudget) _overBudget++;
    if (highLatency) _highLatency++;
    if (!missedBudget && !highLatency) return;
    _event({
      'type': 'slow_frame', 't_us': _relative(startUs), 'duration_us': total,
      'build_us': buildUs, 'raster_us': rasterUs,
      'vsync_overhead_us': vsyncOverheadUs, 'budget_us': context.budgetUs,
      'budget_estimated': context.estimated, 'screen': context.screen.name,
      'over_budget': missedBudget, 'high_latency': highLatency,
    });
  }

  /// Timer scheduling delay: NOT a stack trace, CPU sample, or proof of blocking.
  void heartbeat({int periodUs = 100000, int thresholdUs = 50000}) {
    if (!enabled) return;
    final now = _clock();
    final last = _lastHeartbeat;
    _lastHeartbeat = now;
    if (last == null) return;
    final expected = last + periodUs;
    final late = now - expected;
    if (late < thresholdUs || !_inWindow(last, now)) return;
    _delay.add(late);
    _event({
      'type': 'ui_delay', 't_us': _relative(expected), 'duration_us': late,
      'screen': (_contextAt(expected)?.screen ?? PerfScreen.other).name,
    });
  }

  /// Cheap decoded-cache counters; never walks disk directories or app data.
  void recordImageCache({required int bytes, required int live, required int pending}) {
    if (!enabled) return;
    _event({
      'type': 'image_cache', 't_us': _relative(_clock()),
      'bytes': bytes, 'live': live, 'pending': pending,
    });
  }

  Map<String, Object?> snapshot() {
    final start = _start;
    return {
      'schema_version': 1,
      'clock': 'monotonic_microseconds_relative_to_session',
      'recording': _recording,
      'elapsed_us': start == null ? 0 : (_stop ?? _clock()) - start,
      'limits': {
        'events': eventCapacity, 'active_spans': activeSpanCapacity,
        'contexts': contextCapacity, 'span_detail_threshold_us': spanDetailThresholdUs,
      },
      'coverage': {
        'evicted_events': _droppedEvents, 'unrecorded_spans': _droppedSpans,
        'interrupted_spans': _interruptedSpans, 'rejected_frames': _rejectedFrames,
        'frames_without_context': _missingContexts,
      },
      'summary': {
        'frames': frameCount, 'over_budget_frames': _overBudget,
        'high_latency_frames': _highLatency,
        'build': _build.toJson(), 'raster': _raster.toJson(),
        'frame_latency': _latency.toJson(), 'ui_delay': _delay.toJson(),
        'operations': [
          for (final entry in _operations.entries) {
            'op': entry.key.$1.name, 'kind': entry.key.$2.name,
            ...entry.value.toJson(),
          },
        ],
      },
      // Independent maps: subsequent recording must not mutate an exported report.
      'events': [for (final event in _events) Map<String, Object?>.of(event)],
    };
  }

  int _relative(int timestamp) => timestamp - (_start ?? timestamp);

  void _event(Map<String, Object?> event) {
    if (_events.length == eventCapacity) {
      _events.removeFirst();
      _droppedEvents++;
    }
    _events.add(event);
  }

  void _openWindow() {
    if (_windows.length == contextCapacity) _windows.removeAt(0);
    final now = _clock();
    _windows.add(_Window(now));
    _lastHeartbeat = now;
  }

  void _closeWindow(int now) {
    if (_windows.isNotEmpty && _windows.last.end == null) _windows.last.end = now;
    _lastHeartbeat = null;
  }

  void _invalidateSpans() {
    _interruptedSpans += _active.length;
    _active.clear();
    _generation++;
  }

  bool _inWindow(int start, int end) {
    for (var i = _windows.length - 1; i >= 0; i--) {
      final window = _windows[i];
      if (start >= window.start) return end <= (window.end ?? _clock());
    }
    return false;
  }

  _Context? _contextAt(int time) {
    // Small bounded history is necessary because release timings arrive batched.
    for (var i = _contexts.length - 1; i >= 0; i--) {
      final context = _contexts[i];
      if (context.at <= time) return context;
    }
    return null;
  }
}

class PerfSpan {
  PerfSpan._(this.recorder, this.id, this.generation, this.operation, this.kind,
      this.start, this.screen, this.items);
  const PerfSpan._disabled()
      : recorder = null, id = 0, generation = 0,
        operation = PerfOperation.cacheQueueWait, kind = PerfSpanKind.asyncWall,
        start = 0, screen = PerfScreen.other, items = null;
  final PerformanceRecorder? recorder;
  final int id;
  final int generation;
  final PerfOperation operation;
  final PerfSpanKind kind;
  final int start;
  final PerfScreen screen;
  final int? items;
  void finish({bool failed = false}) => recorder?._finish(this, failed);
}

class _Window {
  _Window(this.start);
  final int start;
  int? end;
}

class _Context {
  const _Context(this.at, this.screen, this.budgetUs, this.estimated);
  final int at;
  final PerfScreen screen;
  final int budgetUs;
  final bool estimated;
}

class _Distribution {
  static const boundsUs = [
    1000, 2000, 4000, 8000, 12000, 17000, 25000, 34000,
    50000, 100000, 250000, 500000, 1000000, 2000000, 5000000,
  ];
  final buckets = List<int>.filled(boundsUs.length + 1, 0);
  int count = 0;
  int totalUs = 0;
  int maxUs = 0;
  void add(int value) {
    count++;
    totalUs += value;
    if (value > maxUs) maxUs = value;
    var bucket = 0;
    while (bucket < boundsUs.length && value > boundsUs[bucket]) {
      bucket++;
    }
    buckets[bucket]++;
  }
  Map<String, Object?> toJson() => {
    'count': count, 'total_us': totalUs, 'max_us': maxUs,
    'histogram_bounds_us': boundsUs, 'histogram_counts': List<int>.of(buckets),
  };
}
