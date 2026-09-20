import 'package:equatable/equatable.dart';

class SearchRefreshSettings extends Equatable {
  const SearchRefreshSettings({this.enabled = true, this.intervalMinutes = 5});
  factory SearchRefreshSettings.parse(Object? value) {
    final json = switch (value) {
      final Map json => json,
      _ => const <String, Object?>{},
    };
    return SearchRefreshSettings(
      enabled: switch (json['enabled']) {
        final bool value => value,
        _ => true,
      },
      intervalMinutes: switch (json['intervalMinutes']) {
        final int value when value >= 1 && value <= 1440 => value,
        _ => 5,
      },
    );
  }
  final bool enabled;
  final int intervalMinutes;
  Duration get interval => Duration(minutes: intervalMinutes);
  SearchRefreshSettings copyWith({bool? enabled, int? intervalMinutes}) =>
      SearchRefreshSettings(
        enabled: enabled ?? this.enabled,
        intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      );
  Map<String, Object> toJson() => {
    'enabled': enabled,
    'intervalMinutes': intervalMinutes,
  };
  @override
  List<Object?> get props => [enabled, intervalMinutes];
}
