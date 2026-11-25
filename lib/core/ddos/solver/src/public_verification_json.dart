import 'dart:convert';

import '../../../../../foundation/browser/types.dart';

/// Fetch JSON again with credentials omitted. The initial navigation can use
/// the WebView's existing cookies.
Future<String?> readPublicVerificationJson(
  EmbeddedBrowserSession browser,
  Uri uri, {
  required bool Function() isCurrent,
}) async {
  final script =
      '''
(() => {
  const url = new URL(${jsonEncode(uri.toString())}).href;
  if (location.href !== url ||
      document.contentType !== 'application/json' ||
      navigator.serviceWorker?.controller) return '';
  if (window.boorusamaPublicVerificationJson?.url === url) {
    return window.boorusamaPublicVerificationJson.body;
  }

  const result = {url, body: 'pending'};
  window.boorusamaPublicVerificationJson = result;
  const abort = new AbortController();
  const timeout = setTimeout(() => abort.abort(), 3000);
  (async () => {
    try {
      const response = await fetch(url, {
        credentials: 'omit',
        cache: 'no-store',
        redirect: 'error',
        mode: 'same-origin',
        referrerPolicy: 'no-referrer',
        headers: {Accept: 'application/json'},
        signal: abort.signal,
      });
      const type = response.headers.get('Content-Type')?.split(';')[0].trim();
      if (response.status !== 200 || response.url !== url ||
          response.headers.get('cf-mitigated') === 'challenge' ||
          type !== 'application/json' || !response.body) return;

      const reader = response.body.getReader();
      const decoder = new TextDecoder('utf-8', {fatal: true});
      let body = '';
      let length = 0;
      for (;;) {
        const chunk = await reader.read();
        if (chunk.done) break;
        length += chunk.value.byteLength;
        if (length > 4 * 1024 * 1024) return;
        body += decoder.decode(chunk.value, {stream: true});
      }
      result.body = body + decoder.decode();
    } catch (_) {
      result.body = '';
    } finally {
      if (result.body === 'pending') result.body = '';
      clearTimeout(timeout);
      abort.abort();
    }
  })();
  return 'pending';
})()
''';
  for (var poll = 0; poll <= 20 && isCurrent(); poll++) {
    final raw = await browser
        .evaluateJavaScript(script)
        .timeout(const Duration(seconds: 1));
    if (!isCurrent() || raw is! String) return null;
    var body = raw;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is String) body = decoded;
    } on FormatException {
      // Some browser backends return JavaScript strings directly.
    }
    if (body != 'pending') {
      if (body.isEmpty) return null;
      final value = jsonDecode(body);
      return value is Map || value is List ? body : null;
    }
    if (poll < 20) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }
  return null;
}
