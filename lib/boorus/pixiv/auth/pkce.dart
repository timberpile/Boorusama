// Dart imports:
import 'dart:convert';
import 'dart:math';

// Package imports:
import 'package:crypto/crypto.dart';

/// Byte length of a generated code verifier. 32 bytes is the smallest size
/// that yields the maximum-entropy 43-character verifier RFC 7636 allows.
const _kVerifierBytes = 32;

/// A PKCE code verifier / challenge pair for the Pixiv login flow.
///
/// The verifier is the ONLY thing binding the returned authorization code to
/// the request that asked for it — Pixiv's login endpoint has no `state`
/// parameter — so it must be single-use: generate a pair when the login page
/// opens, keep it in that page's `State`, never persist it, and generate a
/// fresh pair for every retry.
///
/// [toString] deliberately omits [codeVerifier]: it is a short-lived secret
/// and this object must never leak it into a log line.
class PixivPkcePair {
  const PixivPkcePair({
    required this.codeVerifier,
    required this.codeChallenge,
  });

  /// Generates a fresh pair from [Random.secure].
  ///
  /// There is deliberately no seam for injecting a [Random]: a non-secure
  /// generator here would make the verifier predictable, which is the whole
  /// protection this flow relies on.
  factory PixivPkcePair.generate() {
    final random = Random.secure();
    final bytes = List<int>.generate(
      _kVerifierBytes,
      (_) => random.nextInt(256),
    );

    // base64Url (NOT base64) — the standard alphabet emits `+` and `/`,
    // which are outside RFC 7636's unreserved verifier character set.
    final verifier = _stripPadding(base64Url.encode(bytes));

    return PixivPkcePair(
      codeVerifier: verifier,
      codeChallenge: pixivCodeChallengeOf(verifier),
    );
  }

  final String codeVerifier;
  final String codeChallenge;

  /// Always `S256` — the only method Pixiv's login endpoint accepts.
  String get codeChallengeMethod => 'S256';

  @override
  String toString() => 'PixivPkcePair(codeChallenge: $codeChallenge)';
}

/// `base64url(sha256(ascii(verifier)))` with padding stripped, per RFC 7636
/// section 4.2 (the `S256` transformation).
String pixivCodeChallengeOf(String codeVerifier) {
  final digest = sha256.convert(ascii.encode(codeVerifier));

  return _stripPadding(base64Url.encode(digest.bytes));
}

String _stripPadding(String value) => value.replaceAll('=', '');
