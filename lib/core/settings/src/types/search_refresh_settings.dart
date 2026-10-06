import 'package:equatable/equatable.dart';

enum SearchRefreshMode { adaptive, fixed }

class SearchRefreshSettings extends Equatable {
  const SearchRefreshSettings({
    this.enabled = true,
    this.pinnedSearchesEnabled = true,
    this.followingFeedsEnabled = true,
    this.mode = SearchRefreshMode.adaptive,
    this.fixedIntervalHours = 24,
    this.wifiEthernetOnly = true,
  });

  factory SearchRefreshSettings.parse(Object? value) {
    final json = switch (value) {
      final Map json => json,
      _ => const <String, Object?>{},
    };
    final enabled = switch (json['enabled']) {
      final bool value => value,
      _ => true,
    };
    if (json['schemaVersion'] != 2) {
      // Old minute intervals are intentionally not carried into the new policy.
      return SearchRefreshSettings(enabled: enabled);
    }
    final fixedHours = switch (json['fixedIntervalHours']) {
      final int value
          when value == 6 ||
              value == 12 ||
              value == 24 ||
              value == 48 ||
              value == 168 =>
        value,
      _ => 24,
    };
    return SearchRefreshSettings(
      enabled: enabled,
      pinnedSearchesEnabled: switch (json['pinnedSearchesEnabled']) {
        final bool value => value,
        _ => true,
      },
      followingFeedsEnabled: switch (json['followingFeedsEnabled']) {
        final bool value => value,
        _ => true,
      },
      mode: json['mode'] == 'fixed'
          ? SearchRefreshMode.fixed
          : SearchRefreshMode.adaptive,
      fixedIntervalHours: fixedHours,
      wifiEthernetOnly: switch (json['wifiEthernetOnly']) {
        final bool value => value,
        _ => true,
      },
    );
  }

  final bool enabled;
  final bool pinnedSearchesEnabled;
  final bool followingFeedsEnabled;
  final SearchRefreshMode mode;
  final int fixedIntervalHours;
  final bool wifiEthernetOnly;

  Duration get interval => mode == SearchRefreshMode.adaptive
      ? const Duration(hours: 24)
      : Duration(hours: fixedIntervalHours);

  SearchRefreshSettings copyWith({
    bool? enabled,
    bool? pinnedSearchesEnabled,
    bool? followingFeedsEnabled,
    SearchRefreshMode? mode,
    int? fixedIntervalHours,
    bool? wifiEthernetOnly,
  }) => SearchRefreshSettings(
    enabled: enabled ?? this.enabled,
    pinnedSearchesEnabled: pinnedSearchesEnabled ?? this.pinnedSearchesEnabled,
    followingFeedsEnabled: followingFeedsEnabled ?? this.followingFeedsEnabled,
    mode: mode ?? this.mode,
    fixedIntervalHours: fixedIntervalHours ?? this.fixedIntervalHours,
    wifiEthernetOnly: wifiEthernetOnly ?? this.wifiEthernetOnly,
  );

  Map<String, Object> toJson() => {
    'schemaVersion': 2,
    'enabled': enabled,
    'pinnedSearchesEnabled': pinnedSearchesEnabled,
    'followingFeedsEnabled': followingFeedsEnabled,
    'mode': mode.name,
    'fixedIntervalHours': fixedIntervalHours,
    'wifiEthernetOnly': wifiEthernetOnly,
  };

  @override
  List<Object?> get props => [
    enabled,
    pinnedSearchesEnabled,
    followingFeedsEnabled,
    mode,
    fixedIntervalHours,
    wifiEthernetOnly,
  ];
}
