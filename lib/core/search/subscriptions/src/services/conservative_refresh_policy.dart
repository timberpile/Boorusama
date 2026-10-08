import '../../../../settings/src/types/search_refresh_settings.dart';

enum AdaptiveRefreshResult {
  newPostsAutomatic,
  newPostsManual,
  emptyAutomatic,
  emptyManual,
  failed,
  cancelled,
  baseline,
  rateLimited,
}

class AdaptiveRefreshState {
  const AdaptiveRefreshState({
    this.interval = const Duration(hours: 24),
    this.consecutiveEmptyAutomatic = 0,
  });

  final Duration interval;
  final int consecutiveEmptyAutomatic;

  AdaptiveRefreshState after(AdaptiveRefreshResult result) => switch (result) {
    AdaptiveRefreshResult.newPostsAutomatic => AdaptiveRefreshState(
      interval: interval ~/ 2 < const Duration(hours: 6)
          ? const Duration(hours: 6)
          : interval ~/ 2,
    ),
    AdaptiveRefreshResult.emptyAutomatic when consecutiveEmptyAutomatic == 0 =>
      AdaptiveRefreshState(
        interval: interval,
        consecutiveEmptyAutomatic: 1,
      ),
    AdaptiveRefreshResult.emptyAutomatic => AdaptiveRefreshState(
      interval: interval * 2 > const Duration(days: 7)
          ? const Duration(days: 7)
          : interval * 2,
    ),
    _ => this,
  };
}

enum RefreshNetwork {
  wifi,
  ethernet,
  unmeteredMobile,
  metered,
  offline,
  unknown,
}

enum RefreshSkipReason {
  disabled,
  inactive,
  network,
  batterySaver,
  scope,
  unsupported,
  cooldown,
  notDue,
}

class RefreshSourceCandidate {
  const RefreshSourceCandidate({
    required this.id,
    this.pinned = false,
    this.feedSource = false,
    this.supported = true,
    this.createdAt,
    this.lastMaterialEditAt,
    this.lastAttemptAt,
    this.lastSuccessfulCheckAt,
    this.cooldownUntil,
    this.adaptiveState = const AdaptiveRefreshState(),
  });

  final String id;
  final bool pinned;
  final bool feedSource;
  final bool supported;
  final DateTime? createdAt;
  final DateTime? lastMaterialEditAt;
  final DateTime? lastAttemptAt;
  final DateTime? lastSuccessfulCheckAt;
  final DateTime? cooldownUntil;
  final AdaptiveRefreshState adaptiveState;
}

class ConservativeRefreshPlan {
  const ConservativeRefreshPlan(this.selectedIds, this.skipped);

  final List<String> selectedIds;
  final Map<String, RefreshSkipReason> skipped;
}

DateTime? _latest(DateTime? first, DateTime? second) =>
    switch ((first, second)) {
      (null, final other) => other,
      (final other, null) => other,
      (final a?, final b?) => a.isAfter(b) ? a : b,
    };

class ConservativeRefreshTiming {
  const ConservativeRefreshTiming({
    required this.interval,
    required this.dueAt,
    required this.eligibleAt,
  });
  final Duration interval;
  final DateTime dueAt;
  final DateTime eligibleAt;
}

DateTime? refreshActivityAnchor(RefreshSourceCandidate source) => [
  source.createdAt,
  source.lastMaterialEditAt,
  source.lastAttemptAt,
  source.lastSuccessfulCheckAt,
].whereType<DateTime>().fold<DateTime?>(null, _latest);

ConservativeRefreshTiming conservativeRefreshTiming({
  required RefreshSourceCandidate source,
  required SearchRefreshSettings settings,
  required DateTime now,
}) {
  final interval = settings.mode == SearchRefreshMode.adaptive
      ? source.adaptiveState.interval
      : settings.interval;
  final dueAt = (refreshActivityAnchor(source) ?? now).add(interval);
  return ConservativeRefreshTiming(
    interval: interval,
    dueAt: dueAt,
    eligibleAt: _latest(dueAt, source.cooldownUntil)!,
  );
}

ConservativeRefreshPlan planConservativeRefresh({
  required DateTime now,
  required SearchRefreshSettings settings,
  required bool foreground,
  required RefreshNetwork network,
  required bool batterySaver,
  required Iterable<RefreshSourceCandidate> sources,
}) {
  final unique = <String, RefreshSourceCandidate>{};
  for (final source in sources) {
    unique.update(
      source.id,
      (previous) => RefreshSourceCandidate(
        id: source.id,
        pinned: previous.pinned || source.pinned,
        feedSource: previous.feedSource || source.feedSource,
        supported: previous.supported && source.supported,
        createdAt: _latest(previous.createdAt, source.createdAt),
        lastMaterialEditAt: _latest(
          previous.lastMaterialEditAt,
          source.lastMaterialEditAt,
        ),
        lastAttemptAt: _latest(previous.lastAttemptAt, source.lastAttemptAt),
        lastSuccessfulCheckAt: _latest(
          previous.lastSuccessfulCheckAt,
          source.lastSuccessfulCheckAt,
        ),
        cooldownUntil: _latest(previous.cooldownUntil, source.cooldownUntil),
        adaptiveState: previous.adaptiveState,
      ),
      ifAbsent: () => source,
    );
  }
  final skipped = <String, RefreshSkipReason>{};
  final globalPause = switch ((settings.enabled, foreground, batterySaver)) {
    (false, _, _) => RefreshSkipReason.disabled,
    (_, false, _) => RefreshSkipReason.inactive,
    (_, _, true) => RefreshSkipReason.batterySaver,
    _ => switch (network) {
      RefreshNetwork.offline ||
      RefreshNetwork.unknown ||
      RefreshNetwork.metered => RefreshSkipReason.network,
      RefreshNetwork.unmeteredMobile when settings.wifiEthernetOnly =>
        RefreshSkipReason.network,
      _ => null,
    },
  };
  if (globalPause != null) {
    for (final id in unique.keys) {
      skipped[id] = globalPause;
    }
    return ConservativeRefreshPlan(const [], skipped);
  }
  final due = <RefreshSourceCandidate>[];
  for (final source in unique.values) {
    final timing = conservativeRefreshTiming(
      source: source,
      settings: settings,
      now: now,
    );
    final reason = switch (source) {
      _
          when !(source.pinned && settings.pinnedSearchesEnabled) &&
              !(source.feedSource && settings.followingFeedsEnabled) =>
        RefreshSkipReason.scope,
      _ when !source.supported => RefreshSkipReason.unsupported,
      _
          when source.cooldownUntil != null &&
              now.isBefore(source.cooldownUntil!) =>
        RefreshSkipReason.cooldown,
      _ when now.isBefore(timing.dueAt) => RefreshSkipReason.notDue,
      _ => null,
    };
    if (reason != null) {
      skipped[source.id] = reason;
    } else {
      due.add(source);
    }
  }
  due.sort((left, right) {
    final leftActivity = refreshActivityAnchor(left);
    final rightActivity = refreshActivityAnchor(right);
    final date = switch ((leftActivity, rightActivity)) {
      (null, null) => 0,
      (null, _) => -1,
      (_, null) => 1,
      (final leftDate?, final rightDate?) => leftDate.compareTo(rightDate),
    };
    return date != 0 ? date : left.id.compareTo(right.id);
  });
  return ConservativeRefreshPlan(
    [for (final source in due.take(6)) source.id],
    skipped,
  );
}
