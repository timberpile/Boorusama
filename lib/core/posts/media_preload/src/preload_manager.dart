// Dart imports:
import 'dart:async';
import 'dart:math' as math;

// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:foundation/performance.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

// Project imports:
import 'preload_media.dart';
import 'preload_strategy.dart';
import 'types.dart';

const kEnablePreloadLogging = false;
const _urlHistoryLimit = 256;
const _completedUrlTtl = Duration(seconds: 30);
const _failedUrlRetryDelay = Duration(seconds: 5);

class PreloadManager {
  PreloadManager({
    required Preloader preloader,
    DownloadConfiguration? downloadConfiguration,
    bool Function()? isEnabled,
    Duration Function()? elapsed,
  }) : _preloader = preloader,
       _isEnabled = isEnabled ?? _alwaysEnabled,
       _elapsed = elapsed ?? _monotonicElapsed(),
       _downloadConfiguration =
           downloadConfiguration ?? const DownloadConfiguration();

  final Preloader _preloader;
  final bool Function() _isEnabled;
  final Duration Function() _elapsed;
  final DownloadConfiguration _downloadConfiguration;

  void _log(String message) {
    if (kEnablePreloadLogging) {
      debugPrint(message);
    }
  }

  final Map<String, CancelToken> _activeCancelTokens = {};
  final Set<String> _activeDownloads = {};
  // Completion is a short-lived hint, not proof of current disk residency.
  final Set<String> _completedUrls = {};
  final Map<String, Duration> _completedUntil = {};
  final Map<String, Duration> _retryAfter = {};
  var _disposed = false;
  final _pendingQueue = PriorityQueue<PrioritizedUrl>();
  Set<String> _currentSkipUrls = {};

  void preloadMedias(PreloadResult result) {
    if (_disposed || !_isEnabled()) {
      cancelAll();
      return;
    }

    _pruneHistory();
    final skipUrls = result.skipUrls;
    final cancelUrls = result.cancelUrls;

    for (final urlToCancel in cancelUrls) {
      if (_activeCancelTokens.containsKey(urlToCancel)) {
        _log(
          '[IPM] Cancellation: ${urlToCancel.split('/').last}',
        );
        _activeCancelTokens[urlToCancel]?.cancel();
        _activeCancelTokens.remove(urlToCancel);
        _activeDownloads.remove(urlToCancel);
      }
    }

    // Store current state
    _currentSkipUrls = Set.from(skipUrls);

    // Rebuild priority queue using strategy-provided priorities
    _rebuildPriorityQueue(result.prioritizedUrls, skipUrls);

    if (_pendingQueue.isEmpty) return;

    _logState(
      'Starting preload batch',
      pending: _pendingQueue.length,
      active: _activeDownloads.length,
      completed: _completedUrls.length,
    );
    _startNextDownloads();
  }

  /// Rebuild priority queue using strategy-provided priorities
  void _rebuildPriorityQueue(
    List<PrioritizedUrl> prioritizedUrls,
    Set<String> skipUrls,
  ) {
    _pendingQueue.clear();
    final bestByUrl = <String, PrioritizedUrl>{};

    for (final prioritizedUrl in prioritizedUrls) {
      if (!skipUrls.contains(prioritizedUrl.url) &&
          !_completedUrls.contains(prioritizedUrl.url) &&
          !_retryAfter.containsKey(prioritizedUrl.url) &&
          !_activeDownloads.contains(prioritizedUrl.url)) {
        final previous = bestByUrl[prioritizedUrl.url];
        if (previous == null || prioritizedUrl.compareTo(previous) < 0) {
          bestByUrl[prioritizedUrl.url] = prioritizedUrl;
        }
      }
    }
    // A queued duplicate must not dispatch after its first attempt's hint
    // expires while another URL holds a slot. A new plan restores eligibility.
    _pendingQueue.addAll(bestByUrl.values);

    if (kEnablePreloadLogging && _pendingQueue.isNotEmpty) {
      _log(
        '[IPM] Rebuilt priority queue with ${_pendingQueue.length} URLs',
      );
      final items = _pendingQueue.toList()..sort();
      for (var i = 0; i < math.min(3, items.length); i++) {
        _log('[IPM] Priority #${i + 1}: ${items[i]}');
      }
    }
  }

  /// Convenience method to calculate and preload using a strategy
  void preloadWithStrategy({
    required PreloadStrategy strategy,
    required int currentPage,
    required int itemCount,
    required PreloadMedia? Function(int index) mediaBuilder,
  }) {
    final diagnosticRecording = performanceRecorder.enabled;
    var diagnosticBuilds = 0;
    performanceRecorder.measureSync(PerfOperation.viewerPreloadPlan, () {
      if (_disposed || !_isEnabled()) {
        cancelAll();
        return;
      }

      _pruneHistory();
      final context = PreloadContext(
        currentPage: currentPage,
        itemCount: itemCount,
        mediaBuilder: diagnosticRecording
            ? (index) {
                diagnosticBuilds++;
                return mediaBuilder(index);
              }
            : mediaBuilder,
        activeDownloads: Set.from(_activeDownloads),
        // Calculation is synchronous; a read-only view avoids copying the
        // complete browsing history on every page change.
        completedUrls: UnmodifiableSetView(_completedUrls),
      );
      final result = strategy.calculatePreload(context);
      preloadMedias(result);
    });
    performanceRecorder.count(PerfCounter.preloadMediaBuilds, diagnosticBuilds);
    performanceRecorder.count(
      PerfCounter.preloadCompletedHistory,
      _completedUrls.length,
    );
  }

  void cancelAll() {
    for (final cancelToken in _activeCancelTokens.values) {
      cancelToken.cancel();
    }

    final activeCount = _activeDownloads.length;
    final pendingCount = _pendingQueue.length;
    final tokenCount = _activeCancelTokens.length;

    _activeCancelTokens.clear();
    _activeDownloads.clear();
    _pendingQueue.clear();
    _currentSkipUrls.clear();

    if (kEnablePreloadLogging) {
      if (activeCount > 0 || pendingCount > 0) {
        _log(
          '[IPM] Resource cleanup: cancelled_active=$activeCount cancelled_pending=$pendingCount tokens_cleared=$tokenCount reason=cancel_all',
        );
      }
    }
    // Retain only bounded hints across route cancellation. Dispose drops them.
  }

  /// For testing/debugging
  PreloadManagerState get state => PreloadManagerState(
    activeDownloads: Set.from(_activeDownloads),
    completedUrls: Set.from(_completedUrls),
    activeCancelTokensCount: _activeCancelTokens.length,
  );

  void _startNextDownloads() {
    if (_disposed || !_isEnabled()) {
      cancelAll();
      return;
    }

    _pruneHistory();
    while (_activeDownloads.length <
            _downloadConfiguration.maxConcurrentDownloads &&
        _pendingQueue.isNotEmpty) {
      final prioritizedUrl = _pendingQueue.removeFirst();
      final url = prioritizedUrl.url;

      // Double-check the URL is still valid to preload
      if (!_currentSkipUrls.contains(url) &&
          !_completedUrls.contains(url) &&
          !_retryAfter.containsKey(url) &&
          !_activeDownloads.contains(url)) {
        _logState(
          'Starting download',
          url: url,
          active: _activeDownloads.length + 1,
          extra: {
            'priority': prioritizedUrl.priority,
            'zone': prioritizedUrl.relevanceZone.name,
          },
        );
        // Fire and forget - we handle errors in the method itself
        _preloadSingleUrl(url);
      } else {
        if (kEnablePreloadLogging) {
          final reason = _currentSkipUrls.contains(url)
              ? 'in_skip_set'
              : _completedUrls.contains(url)
              ? 'already_completed'
              : _retryAfter.containsKey(url)
              ? 'retry_cooldown'
              : 'already_active';
          _log(
            '[IPM] Skipped download: url=${url.split('/').last} reason=$reason priority=${prioritizedUrl.priority}',
          );
        }
      }
    }
  }

  Future<void> _preloadSingleUrl(String url) async {
    _activeDownloads.add(url);

    final cancelToken = CancelToken();
    _activeCancelTokens[url] = cancelToken;

    try {
      await _preloader(url, cancelToken);
      if (!cancelToken.isCancelled &&
          identical(_activeCancelTokens[url], cancelToken)) {
        _rememberCompleted(url);
        _logState(
          'Download completed',
          url: url,
          completed: _completedUrls.length,
        );
      }
    } catch (error) {
      // Only a later plan retries. A bounded cooldown prevents page-change
      // callbacks from immediately repeating a failed transport.
      if (!cancelToken.isCancelled &&
          identical(_activeCancelTokens[url], cancelToken)) {
        _retryAfter
          ..remove(url)
          ..[url] = _elapsed() + _failedUrlRetryDelay;
        _pruneHistory();
      }
      _logState(
        'Download failed',
        url: url,
        extra: {'error': error.toString().split('\n').first},
      );
    } finally {
      // A canceled request may finish after the same URL has been restarted.
      // Only the request that still owns the token may release that slot.
      if (identical(_activeCancelTokens[url], cancelToken)) {
        _activeDownloads.remove(url);
        _activeCancelTokens.remove(url);
        _startNextDownloads();
      }
    }
  }

  void _rememberCompleted(String url) {
    _retryAfter.remove(url);
    _completedUrls.add(url);
    _completedUntil
      ..remove(url)
      ..[url] = _elapsed() + _completedUrlTtl;
    _pruneHistory();
  }

  void _pruneHistory() {
    final now = _elapsed();
    void prune(Map<String, Duration> history, {Set<String>? urls}) {
      // Fixed TTLs and monotonic time keep insertion order in expiry order.
      while (history.isNotEmpty) {
        final oldest = history.entries.first;
        if (history.length <= _urlHistoryLimit && oldest.value > now) break;
        history.remove(oldest.key);
        urls?.remove(oldest.key);
      }
    }

    prune(_completedUntil, urls: _completedUrls);
    prune(_retryAfter);
  }

  void dispose() {
    _disposed = true;
    cancelAll();
    _completedUrls.clear();
    _completedUntil.clear();
    _retryAfter.clear();
  }

  void _logState(
    String action, {
    int? active,
    int? pending,
    int? completed,
    int? cancelled,
    String? url,
    Map<String, dynamic>? extra,
  }) {
    if (!kEnablePreloadLogging) return;

    final parts = <String>['[IPM]', action];
    if (url != null) parts.add('url=${url.split('/').last}');
    if (active != null) parts.add('active_downloads=$active');
    if (pending != null) parts.add('pending_downloads=$pending');
    if (completed != null) parts.add('completed_downloads=$completed');
    if (cancelled != null) parts.add('cancelled_downloads=$cancelled');
    if (extra != null) {
      extra.forEach((k, v) => parts.add('$k=$v'));
    }

    debugPrint(parts.join(' '));
  }
}

bool _alwaysEnabled() => true;

Duration Function() _monotonicElapsed() {
  final stopwatch = Stopwatch()..start();
  return () => stopwatch.elapsed;
}

class PreloadManagerState extends Equatable {
  const PreloadManagerState({
    required this.activeDownloads,
    required this.completedUrls,
    required this.activeCancelTokensCount,
  });

  final Set<String> activeDownloads;
  final Set<String> completedUrls; // URLs that completed successfully
  final int activeCancelTokensCount;

  @override
  List<Object?> get props => [
    activeDownloads,
    completedUrls,
    activeCancelTokensCount,
  ];
}
