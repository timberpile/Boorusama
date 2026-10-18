import 'dart:convert';

import '../../../network/types.dart';

/// Warnings describe only affected options, never raw profile values/credentials.
/// Invalid/future values fall back to known options; invalid host rules are not
/// retained because applying them without validation could change auth origins.
List<String> profileOptionWarnings(Map<String, dynamic> json) {
  final warnings = <String>[];
  if (json.containsKey('thumbnailActions')) {
    final actions = json['thumbnailActions'];
    const known = {'default', 'bookmark', 'download', 'artist'};
    if (actions is! List ||
        actions.any((action) => !known.contains(action)) ||
        actions.length > 2 ||
        actions.toSet().length != actions.length) {
      warnings.add('profile_thumbnail_actions_fallback');
    }
  } else if (json['defaultPreviewImageButtonAction'] case final Object action
      when !{
        '',
        'default',
        'toggleBookmark',
        'download',
        'viewArtist',
      }.contains(action)) {
    warnings.add('profile_thumbnail_actions_fallback');
  }
  dynamic network = json['network'];
  if (network is String && network.isNotEmpty) {
    try {
      network = jsonDecode(network);
    } catch (_) {
      warnings.add('profile_media_rules_fallback');
      return warnings;
    }
  }
  if (network == null || network == '') return warnings;
  if (network is! Map) return [...warnings, 'profile_media_rules_fallback'];
  if (network['mediaHostOverridesEnabled'] case final Object enabled
      when enabled is! bool) {
    warnings.add('profile_media_enabled_fallback');
  }
  final rules = network['mediaHostOverrides'];
  if (rules != null &&
      (rules is! List ||
          rules.any((rule) => MediaHostOverride.tryParse(rule) == null))) {
    warnings.add('profile_media_rules_fallback');
  }
  return List.unmodifiable(warnings);
}
