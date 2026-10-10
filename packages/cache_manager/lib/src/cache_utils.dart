import 'dart:convert';

import 'package:crypto/crypto.dart';

String generateCacheKey(
  String url, {
  String? customKey,
  required String Function(String) keyToMd5,
}) {
  if (customKey != null) {
    return customKey;
  }

  final uri = Uri.tryParse(url);
  if (uri == null) {
    return keyToMd5(url);
  }

  // Include the origin to avoid collisions between unrelated sites.
  // URL fragments do not identify a different HTTP resource.
  return keyToMd5(uri.replace(fragment: '').toString());
}

String keyToMd5(String key) {
  final bytes = utf8.encode(key);
  final digest = md5.convert(bytes);
  return digest.toString();
}
