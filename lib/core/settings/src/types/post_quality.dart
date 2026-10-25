import 'package:flutter/widgets.dart';
import 'package:i18n/i18n.dart';

enum PostQuality {
  medium,
  high,
  original;

  // Keep the old High/Highest scalar meanings; enum indexes are not storage.
  factory PostQuality.parse(dynamic value) => switch (value) {
    '5' || 5 => original,
    'automatic' ||
    'low' ||
    'high' ||
    'medium' ||
    '0' ||
    '1' ||
    '2' ||
    0 ||
    1 ||
    2 => medium,
    _ => high,
  };

  int toData() => switch (this) {
    medium => 2,
    high => 4,
    original => 5,
  };

  String localize(BuildContext context) => switch (this) {
    medium => context.t.settings.image_grid.image_quality.medium,
    high => context.t.settings.image_grid.image_quality.high,
    original => context.t.settings.image_grid.image_quality.original,
  };
}
