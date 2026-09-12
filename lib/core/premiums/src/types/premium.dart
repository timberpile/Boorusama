// Flutter imports:
import 'package:flutter/widgets.dart';

// Package imports:
import 'package:equatable/equatable.dart';
import 'package:i18n/i18n.dart';

List<Benefit> defaultBenefits(BuildContext context) => [
  Benefit(
    title: context.t.premium.benefits.exclusive_themes,
    description: context.t.premium.benefits.exclusive_themes_description,
  ),
  Benefit(
    title: context.t.premium.benefits.layout_customization,
    description: context.t.premium.benefits.layout_customization_description,
  ),
  Benefit(
    title: context.t.premium.benefits.enhanced_bulk_download,
    description: context.t.premium.benefits.enhanced_bulk_download_description,
  ),
  Benefit(
    title: context.t.premium.benefits.support_development,
    description: context.t.premium.benefits.support_development_description,
  ),
];

class Benefit extends Equatable {
  const Benefit({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  List<Object?> get props => [title, description];
}
