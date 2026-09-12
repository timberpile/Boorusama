import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'pixiv_constants.dart';

/// Builds the full header set required on every `app-api` call.
///
/// Returned as a plain map to be passed via dio `Options(headers: ...)` on
/// each request — callers must NOT write these into the shared Dio's
/// `BaseOptions.headers`, since that Dio is shared and built app-side.
Map<String, String> buildPixivApiHeaders({
  required String accessToken,
  required String acceptLanguage,
  DateTime? now,
}) {
  final clientTime = _formatClientTime(now ?? DateTime.now());
  final clientHash = md5
      .convert(utf8.encode('$clientTime$kPixivHashSecret'))
      .toString();

  return {
    'Authorization': 'Bearer $accessToken',
    'User-Agent': kPixivUserAgent,
    'App-OS': kPixivAppOs,
    'App-OS-Version': kPixivAppOsVersion,
    'App-Version': kPixivAppVersion,
    'Accept-Language': acceptLanguage,
    'Referer': kPixivApiReferer,
    'X-Client-Time': clientTime,
    'X-Client-Hash': clientHash,
  };
}

/// ISO8601 with a numeric offset (e.g. `2026-09-08T06:29:00+00:00`) — Dart's
/// default `DateTime.toIso8601String()` uses `Z`/no-offset instead, which the
/// API does not accept.
String _formatClientTime(DateTime time) {
  final t = time.toLocal();
  final offset = t.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final absOffset = offset.abs();
  final hours = absOffset.inHours.toString().padLeft(2, '0');
  final minutes = (absOffset.inMinutes % 60).toString().padLeft(2, '0');

  String two(int n) => n.toString().padLeft(2, '0');

  final date =
      '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)}';
  final clock = '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';

  return '${date}T$clock$sign$hours:$minutes';
}
