// Package imports:
import 'package:equatable/equatable.dart';

class DeveloperOptions extends Equatable {
  const DeveloperOptions({
    required this.automaticMediaLoadingEnabled,
    this.zoomStudyEnabled = false,
  });

  static const defaults = DeveloperOptions(
    automaticMediaLoadingEnabled: true,
  );

  final bool automaticMediaLoadingEnabled;
  final bool zoomStudyEnabled;

  DeveloperOptions copyWith({
    bool? automaticMediaLoadingEnabled,
    bool? zoomStudyEnabled,
  }) => DeveloperOptions(
    automaticMediaLoadingEnabled:
        automaticMediaLoadingEnabled ?? this.automaticMediaLoadingEnabled,
    zoomStudyEnabled: zoomStudyEnabled ?? this.zoomStudyEnabled,
  );

  @override
  List<Object?> get props => [automaticMediaLoadingEnabled, zoomStudyEnabled];
}
