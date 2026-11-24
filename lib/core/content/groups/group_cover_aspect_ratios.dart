import 'package:equatable/equatable.dart';

/// Ratios of the retained static media, which may have different crops.
final class GroupCoverAspectRatios extends Equatable {
  GroupCoverAspectRatios({double? thumbnail, double? sample, double? original})
    : thumbnail = _valid(thumbnail),
      sample = _valid(sample),
      original = _valid(original);

  factory GroupCoverAspectRatios.fromJson(Map<String, dynamic> json) =>
      GroupCoverAspectRatios(
        thumbnail: _number(json['thumbnail']),
        sample: _number(json['sample']),
        original: _number(json['original']),
      );

  final double? thumbnail;
  final double? sample;
  final double? original;

  static double? _valid(double? value) =>
      value != null && value.isFinite && value > 0 ? value : null;

  Map<String, Object?> toJson() => {
    'thumbnail': ?thumbnail,
    'sample': ?sample,
    'original': ?original,
  };

  static double? _number(Object? value) =>
      value is num ? value.toDouble() : null;

  @override
  List<Object?> get props => [thumbnail, sample, original];
}
