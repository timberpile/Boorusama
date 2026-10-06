// Flutter imports:
import 'package:flutter/widgets.dart';

// Package imports:
import 'package:i18n/i18n.dart';

enum ImageQuality {
  automatic,
  low,
  high,
  original,
  highest;

  factory ImageQuality.parse(
    dynamic value, {
    ImageQuality fallback = defaultValue,
  }) => switch (value) {
    'automatic' || '0' || 0 => automatic,
    'low' || '1' || 1 => low,
    'high' || '2' || 2 => high,
    'original' || '3' || 3 => original,
    'highest' || '4' || 4 => highest,
    _ => fallback,
  };

  static const ImageQuality defaultValue = ImageQuality.automatic;
  static const List<ImageQuality> nonOriginalValues = [
    automatic,
    low,
    high,
    highest,
  ];

  bool get isHighres => switch (this) {
    high || highest => true,
    _ => false,
  };

  String localize(BuildContext context) => switch (this) {
    highest => context.t.settings.image_grid.image_quality.highest,
    high => context.t.settings.image_grid.image_quality.high,
    low => context.t.settings.image_grid.image_quality.low,
    original => context.t.settings.image_grid.image_quality.original,
    automatic => context.t.settings.image_grid.image_quality.automatic,
  };

  String localizeThumbnail(BuildContext context) => switch (this) {
    high => context.t.settings.image_grid.image_quality.medium,
    highest => context.t.settings.image_grid.image_quality.high,
    automatic => context.t.settings.image_grid.image_quality.auto,
    _ => localize(context),
  };

  dynamic toData() => index;
}
