// Dart imports:
import 'dart:convert';

import '../../../configs/config/types.dart';

final class ProfileExportSanitizer {
  const ProfileExportSanitizer();

  Map<String, dynamic> sanitizeJson(
    Map<String, dynamic> json, {
    required bool includeCredentials,
  }) {
    final result = _copyMap(json);
    result['credentialsIncluded'] = includeCredentials;
    if (includeCredentials) return result;

    const [
      'apiKey',
      'login',
      'passHash',
      'password',
      'token',
      'accessToken',
      'refreshToken',
      'cookie',
    ].forEach(result.remove);
    if (result['url'] case final String url) {
      result['url'] = normalizeBooruSiteUrl(url);
    }
    if (result['proxySettings'] case final Map proxy) {
      final sanitizedProxy = Map<String, dynamic>.from(proxy)
        ..remove('username')
        ..remove('password');
      result['proxySettings'] = sanitizedProxy;
    }
    return result;
  }

  String sanitizeExportJson(String encoded, bool includeCredentials) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic> || decoded['data'] is! List<dynamic>) {
      throw const FormatException('Invalid profile export payload');
    }
    final result = _copyMap(decoded);
    result['credentialsIncluded'] = includeCredentials;
    result['data'] = [
      for (final entry in decoded['data'] as List<dynamic>)
        if (entry is Map<String, dynamic>)
          sanitizeJson(entry, includeCredentials: includeCredentials)
        else
          throw const FormatException('Invalid profile export entry'),
    ];
    return jsonEncode(result);
  }
}

Map<String, dynamic> _copyMap(Map<String, dynamic> source) => source.map(
  (key, value) => MapEntry(key, switch (value) {
    final Map value => _copyMap(Map<String, dynamic>.from(value)),
    final List value => value.toList(),
    _ => value,
  }),
);

bool profileContainsCredentials(BooruConfig profile) =>
    _hasValue(profile.apiKey) ||
    _hasValue(profile.login) ||
    _hasValue(profile.passHash) ||
    _hasValue(profile.proxySettings?.username) ||
    _hasValue(profile.proxySettings?.password);

bool _hasValue(String? value) => value != null && value.isNotEmpty;
