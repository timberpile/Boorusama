import 'dart:async';
import 'dart:math';
import 'package:http_parser/http_parser.dart' show parseHttpDate;
import 'package:dio/dio.dart';
import 'api_quota_key.dart';
import 'api_quota_policy.dart';
import 'api_request_context.dart';

final class ApiCooldownException implements Exception {
  const ApiCooldownException(this.quota, this.retryAt);
  final ApiQuotaKey quota;
  final DateTime retryAt;
  @override
  String toString() => 'API cooldown until ${retryAt.toIso8601String()}';
}

enum ApiWaitReason {
  serverWindow,
  serverPacing,
  passiveBudget,
  concurrency,
  priority,
}

final class ApiRequestDeferredException implements Exception {
  const ApiRequestDeferredException(this.reason);
  final ApiWaitReason reason;
  @override
  String toString() => 'Speculative API request deferred';
}

final class ApiAdmissionExpired implements Exception {
  const ApiAdmissionExpired();
}

final class ApiQuotaSnapshot {
  const ApiQuotaSnapshot({
    required this.quota,
    required this.inFlight,
    required this.queued,
    this.retryAt,
    this.passiveInFlight = 0,
    this.waiting = const {},
  });
  final int passiveInFlight;
  final Map<ApiWaitReason, int> waiting;
  final ApiQuotaKey quota;
  final int inFlight;
  final int queued;
  final DateTime? retryAt;
}

final class ApiRequestPermit {
  ApiRequestPermit._(this._onRelease, {required this.isPassive});
  final bool isPassive;
  void Function(bool)? _onRelease;
  void release() {
    final release = _onRelease;
    _onRelease = null;
    release?.call(true);
  }
}

extension ApiUnstartedPermit on ApiRequestPermit {
  void abandon() {
    final release = _onRelease;
    _onRelease = null;
    release?.call(false);
  }
}

final class ApiRequestCoordinator {
  ApiRequestCoordinator({
    Duration Function()? elapsed,
    DateTime Function()? now,
    double Function()? jitter,
    ApiQuotaPolicy Function(ApiQuotaKey)? policy,
  }) : _elapsed = elapsed ?? (() => _watch.elapsed),
       _now = now ?? (() => DateTime.now().toUtc()),
       _jitter = jitter ?? Random().nextDouble,
       _policy = policy ?? ApiQuotaPolicy.forOrigin;

  static final _watch = Stopwatch()..start();
  final Duration Function() _elapsed;
  final DateTime Function() _now;
  final double Function() _jitter;
  final ApiQuotaPolicy Function(ApiQuotaKey) _policy;
  final _quotas = <ApiQuotaKey, _Quota>{};
  final _events = StreamController<ApiQuotaSnapshot>.broadcast();
  var _disposed = false;

  Stream<ApiQuotaSnapshot> watch(ApiQuotaKey key) =>
      _events.stream.where((s) => s.quota == key);
  _Quota _quota(ApiQuotaKey key) =>
      _quotas.putIfAbsent(key, () => _Quota(_policy(key)));
  ApiQuotaSnapshot snapshot(ApiQuotaKey key) {
    final q = _quota(key);
    return ApiQuotaSnapshot(
      quota: key,
      inFlight: q.inFlight,
      queued: q.waiters.length,
      passiveInFlight: q.passiveInFlight,
      waiting: {
        for (final reason in ApiWaitReason.values)
          if (q.waiters.any((w) => w.reason == reason))
            reason: q.waiters.where((w) => w.reason == reason).length,
      },
      retryAt: q.blockedUntil != null && _elapsed() < q.blockedUntil!
          ? q.retryAt
          : null,
    );
  }

  void _publish(ApiQuotaKey key) {
    if (!_events.isClosed) _events.add(snapshot(key));
  }

  Future<ApiRequestPermit> acquire(
    ApiQuotaKey key, {
    ApiRequestContext context = const ApiRequestContext(),
    ApiRequestDescriptor descriptor = const ApiRequestDescriptor(),
  }) {
    if (_disposed) return Future.error(StateError('API coordinator disposed'));
    final token = context.cancelToken;
    if (token?.isCancelled ?? false) return Future.error(token!.cancelError!);
    final q = _quota(key);
    if (q.blockedUntil != null && _elapsed() < q.blockedUntil!) {
      return Future.error(ApiCooldownException(key, q.retryAt!));
    }
    final waiter = _Waiter(context, descriptor);
    q.waiters.add(waiter);
    waiter.subscription = context.changes?.listen((_) => _drain(key));
    token?.whenCancel.then((error) {
      if (q.waiters.remove(waiter)) {
        waiter.finish();
        waiter.result.completeError(error);
        _drain(key);
      }
    });
    _drain(key);
    if (context.admissionBehavior == ApiAdmissionBehavior.dropIfUnavailable &&
        q.waiters.remove(waiter)) {
      waiter.finish();
      waiter.result.completeError(ApiRequestDeferredException(waiter.reason));
      _drain(key);
    }
    return waiter.result.future;
  }

  void refreshAdmissions() {
    _quotas.keys.toList().forEach(_drain);
  }

  void _drain(ApiQuotaKey key) {
    final q = _quota(key);
    q.timer?.cancel();
    q.timer = null;
    if (_disposed) return;
    while (q.waiters.isNotEmpty) {
      q.waiters.sort((a, b) {
        final priority = a.context.requestClass.index.compareTo(
          b.context.requestClass.index,
        );
        return priority != 0 ? priority : a.sequence.compareTo(b.sequence);
      });
      final now = _elapsed();
      q.passiveStarts.removeWhere(
        (s) => now - s.at >= q.policy.passiveWindow.duration,
      );
      _Waiter? selected;
      var rules = <_RuleState>[];
      Duration? nextWake;
      // FIFO applies among eligible work: a search-specific exhausted rule
      // cannot silently impose its wait on an unrelated general endpoint.
      for (final candidate in List<_Waiter>.of(q.waiters)) {
        if ((candidate.context.cancelToken?.isCancelled ?? false) ||
            !(candidate.context.canStart?.call() ?? true)) {
          q.waiters.remove(candidate);
          candidate.finish();
          candidate.result.completeError(
            candidate.context.cancelToken?.cancelError ??
                DioException(
                  requestOptions: RequestOptions(),
                  type: DioExceptionType.cancel,
                ),
          );
          continue;
        }
        if (!(candidate.context.canAdmit?.call() ?? true)) {
          q.waiters.remove(candidate);
          candidate.finish();
          candidate.result.completeError(
            DioException(
              requestOptions: RequestOptions(),
              error: const ApiAdmissionExpired(),
            ),
          );
          continue;
        }
        final passive = candidate.context.isPassive;
        if (q.inFlight >= q.policy.maxInFlight ||
            (passive && q.passiveInFlight >= q.policy.maxPassiveInFlight)) {
          candidate.reason = ApiWaitReason.concurrency;
          continue;
        }
        var delay = Duration.zero;
        var reason = ApiWaitReason.serverWindow;
        final matching = q.rules
            .where((r) => r.rule.matches(candidate.descriptor))
            .toList();
        for (final rule in matching) {
          final wait = rule.delay(now);
          if (wait.duration > delay) {
            delay = wait.duration;
            reason = wait.reason;
          }
        }
        if (passive &&
            q.passiveStarts.length >= q.policy.passiveWindow.capacity) {
          final refill =
              q
                  .passiveStarts[q.passiveStarts.length -
                      q.policy.passiveWindow.capacity]
                  .at +
              q.policy.passiveWindow.duration -
              now;
          if (refill > delay) {
            delay = refill;
            reason = ApiWaitReason.passiveBudget;
          }
        }
        if (delay > Duration.zero) {
          candidate.reason = reason;
          if (nextWake == null || delay < nextWake) nextWake = delay;
          continue;
        }
        selected = candidate;
        rules = matching;
        break;
      }
      final w = selected;
      if (w == null) {
        if (nextWake != null) q.timer = Timer(nextWake, () => _drain(key));
        break;
      }
      final passive = w.context.isPassive;
      q.waiters.remove(w);
      w.finish();
      final start = _Start(now);
      for (final rule in rules) {
        rule.admit(start);
      }
      q.inFlight++;
      if (passive) {
        q.passiveStarts.add(start);
        q.passiveInFlight++;
      }
      // Classification is fixed at admission, even if shared ownership changes
      // while a dispatched credential rotation finishes.
      w.result.complete(
        ApiRequestPermit._((started) {
          if (!started) {
            for (final rule in rules) {
              rule.refund(start, _elapsed());
            }
            if (passive) q.passiveStarts.remove(start);
          }
          q.inFlight--;
          if (passive) q.passiveInFlight--;
          _drain(key);
        }, isPassive: passive),
      );
    }
    _publish(key);
  }

  Duration cooldownRemaining(ApiQuotaKey key) {
    final deadline = _quota(key).blockedUntil;
    final remaining = deadline == null ? Duration.zero : deadline - _elapsed();
    return remaining.isNegative ? Duration.zero : remaining;
  }

  DateTime recordRateLimit(ApiQuotaKey key, {String? retryAfter}) {
    final q = _quota(key);
    final wall = _now().toUtc();
    Duration? delay;
    final seconds = int.tryParse(retryAfter?.trim() ?? '');
    if (seconds != null) {
      delay = Duration(seconds: max(0, seconds));
    } else if (retryAfter != null) {
      try {
        delay = parseHttpDate(retryAfter).toUtc().difference(wall);
        if (delay.isNegative) delay = Duration.zero;
      } catch (_) {}
    }
    final sameEpisode = q.blockedUntil != null && _elapsed() < q.blockedUntil!;
    if (delay == null && sameEpisode) {
      delay = q.blockedUntil! - _elapsed();
    }
    if (delay == null) {
      const steps = [30, 120, 600, 1800];
      final base = steps[q.penalty.clamp(0, 3)];
      delay = Duration(
        milliseconds: min(
          1800000,
          (base * 1000 * (1 + _jitter().clamp(0, 1) * .1)).ceil(),
        ),
      );
    }
    if (!sameEpisode) q.penalty = min(3, q.penalty + 1);
    final deadline = _elapsed() + delay;
    if (q.blockedUntil == null || deadline > q.blockedUntil!) {
      q.blockedUntil = deadline;
      q.retryAt = wall.add(delay);
    }
    q.timer?.cancel();
    q.timer = null;
    final pending = List<_Waiter>.of(q.waiters);
    q.waiters.clear();
    for (final w in pending) {
      w.finish();
      w.result.completeError(ApiCooldownException(key, q.retryAt!));
    }
    _publish(key);
    return q.retryAt!;
  }

  void recordSuccess(ApiQuotaKey key) {
    final q = _quota(key);
    if (q.blockedUntil == null || _elapsed() >= q.blockedUntil!) {
      q.penalty = max(0, q.penalty - 1);
      q.blockedUntil = null;
      q.retryAt = null;
    }
    _publish(key);
  }

  void dispose() {
    _disposed = true;
    for (final q in _quotas.values) {
      q.timer?.cancel();
      for (final w in q.waiters) {
        w.finish();
        w.result.completeError(
          DioException(
            requestOptions: RequestOptions(),
            type: DioExceptionType.cancel,
          ),
        );
      }
      q.waiters.clear();
    }
    _events.close();
  }
}

final class _Quota {
  _Quota(this.policy) : rules = policy.serverRules.map(_RuleState.new).toList();
  final ApiQuotaPolicy policy;
  final List<_RuleState> rules;
  final passiveStarts = <_Start>[];
  final waiters = <_Waiter>[];
  var inFlight = 0;
  var passiveInFlight = 0;
  var penalty = 0;
  Timer? timer;
  Duration? blockedUntil;
  DateTime? retryAt;
}

final class _Start {
  _Start(this.at);
  final Duration at;
}

final class _RuleState {
  _RuleState(this.rule) : tokens = rule.bucket?.capacity.toDouble() ?? 0;
  final ApiRateRule rule;
  final starts = <_Start>[];
  double tokens;
  Duration? updatedAt;
  void refill(Duration now) {
    final bucket = rule.bucket;
    if (bucket == null) return;
    final previous = updatedAt;
    if (previous != null) {
      tokens = min(
        bucket.capacity.toDouble(),
        tokens +
            (now - previous).inMicroseconds /
                bucket.refillPeriod.inMicroseconds,
      );
    }
    updatedAt = now;
  }

  ({Duration duration, ApiWaitReason reason}) delay(Duration now) {
    refill(now);
    var duration = Duration.zero;
    var reason = ApiWaitReason.serverWindow;
    final maxWindow = rule.windows.fold(
      Duration.zero,
      (a, w) => a > w.duration ? a : w.duration,
    );
    starts.removeWhere((s) => now - s.at >= maxWindow);
    for (final window in rule.windows) {
      final matching = starts
          .where((s) => now - s.at < window.duration)
          .toList();
      if (matching.length >= window.capacity) {
        final wait =
            matching[matching.length - window.capacity].at +
            window.duration -
            now;
        if (wait > duration) duration = wait;
      }
    }
    final bucket = rule.bucket;
    if (bucket != null && tokens < 1) {
      final wait = Duration(
        microseconds: ((1 - tokens) * bucket.refillPeriod.inMicroseconds)
            .ceil(),
      );
      if (wait > duration) {
        duration = wait;
        reason = ApiWaitReason.serverPacing;
      }
    }
    return (duration: duration, reason: reason);
  }

  void admit(_Start start) {
    if (rule.windows.isNotEmpty) starts.add(start);
    if (rule.bucket != null) tokens--;
  }

  void refund(_Start start, Duration now) {
    starts.remove(start);
    refill(now);
    final bucket = rule.bucket;
    if (bucket != null) tokens = min(bucket.capacity.toDouble(), tokens + 1);
  }
}

final class _Waiter {
  _Waiter(this.context, this.descriptor) : sequence = _next++;
  static var _next = 0;
  final int sequence;
  final ApiRequestContext context;
  final ApiRequestDescriptor descriptor;
  final result = Completer<ApiRequestPermit>();
  var reason = ApiWaitReason.priority;
  StreamSubscription<void>? subscription;
  void finish() {
    unawaited(subscription?.cancel());
  }
}
