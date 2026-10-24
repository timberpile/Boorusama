import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import 'search_option.dart';

/// Native field punctuation must not become punctuation in generated i18n keys.
String searchOptionLocalizationKey(String key) =>
    key.replaceAll(RegExp('[^a-zA-Z0-9_]'), '_');

String? _translation(BuildContext context, String key) {
  final value = context.t[key];
  return value is String && value.isNotEmpty ? value : null;
}

String _label(BuildContext context, String key, String fallback) =>
    _translation(context, key) ?? fallback;

String searchOptionTitle(BuildContext context, SearchOption option) {
  if (option.labelKey != null || option.kind == SearchOptionKind.metadata) {
    final key = searchOptionLocalizationKey(option.labelKey ?? option.key);
    return _label(context, 'search_options.ext.labels.$key', option.key);
  }
  return _label(
    context,
    'search_options.labels.${option.kind.name}',
    option.key,
  );
}

String searchOptionDescription(BuildContext context, SearchOption option) {
  final key =
      option.descriptionKey ??
      (option.kind == SearchOptionKind.metadata ? option.input.name : null);
  return key != null
      ? _label(
          context,
          'search_options.ext.descriptions.${searchOptionLocalizationKey(key)}',
          '${option.key}:…',
        )
      : _label(
          context,
          'search_options.descriptions.${option.kind.name}',
          context.t.search_options.descriptions.native,
        );
}

String searchOptionChoiceLabel(
  BuildContext context,
  SearchOptionChoice choice,
) {
  if (choice.literal) return choice.label;
  final key = searchOptionLocalizationKey(choice.label);
  final label =
      _translation(context, 'search_options.values.${choice.label}') ??
      _translation(context, 'search_options.ext.values.$key');
  if (label != null) return label;
  final order = RegExp(r'^(.*)(?:[:,_])(asc|desc)$').firstMatch(choice.label);
  if (order != null) {
    final field = searchOptionLocalizationKey(order[1]!);
    final fieldLabel = _label(
      context,
      'search_options.ext.labels.$field',
      order[1]!,
    );
    final direction = _label(
      context,
      'search_options.ext.values.${order[2]}',
      order[2]!,
    );
    return '$fieldLabel · $direction';
  }
  return _label(context, 'search_options.ext.labels.$key', choice.value);
}
