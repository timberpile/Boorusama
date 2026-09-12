import 'dart:convert';

import 'package:dio/dio.dart';

import 'pixiv_constants.dart';
import 'types/types.dart';

/// Client for the `/auth/token` endpoint (`https://oauth.secure.pixiv.net`).
///
/// The injected/created [Dio] is deliberately BARE — no logging
/// interceptor, no other interceptor. A logging interceptor elsewhere in the
/// app logs `response.data`, and a token response body contains the access
/// and refresh tokens; routing this traffic through one would print both
/// into a user-exportable log file. Never attach a [Response] to a thrown
/// exception for the same reason — only ever extract a short message.
class PixivAuthClient {
  PixivAuthClient({Dio? dio, String baseUrl = kPixivOAuthBaseUrl})
    : _dio = dio ?? Dio(BaseOptions(baseUrl: baseUrl));

  final Dio _dio;

  /// Exposed for tests only, to assert the bareness required by FIX 1a: no
  /// interceptors (in particular no logging interceptor) on the Dio this
  /// client talks through.
  Dio get debugDio => _dio;

  /// Authorization-code grant, the final step of the PKCE login flow.
  Future<PixivTokens> exchangeCode({
    required String code,
    required String codeVerifier,
  }) => _requestToken({
    'client_id': kPixivClientId,
    'client_secret': kPixivClientSecret,
    'code': code,
    'code_verifier': codeVerifier,
    'grant_type': 'authorization_code',
    'include_policy': 'true',
    'redirect_uri': kPixivRedirectUri,
  });

  /// Refresh-token grant. The API rotates the refresh token on every call —
  /// callers must persist the newest one from the returned [PixivTokens].
  Future<PixivTokens> refresh({required String refreshToken}) => _requestToken({
    'client_id': kPixivClientId,
    'client_secret': kPixivClientSecret,
    'grant_type': 'refresh_token',
    'include_policy': 'true',
    'refresh_token': refreshToken,
  });

  Future<PixivTokens> _requestToken(Map<String, String> form) async {
    try {
      final response = await _dio.post<dynamic>(
        '/auth/token',
        data: form,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final decoded = _decode(response.data);
      final authError = _authErrorOf(decoded);
      if (authError != null) throw authError;

      if (decoded is! Map<String, dynamic>) {
        throw const PixivAuthException('Malformed token response');
      }

      return PixivTokens.fromJson(decoded);
    } on DioException catch (e) {
      final decoded = _decode(e.response?.data);
      final authError = _authErrorOf(decoded);
      if (authError != null) throw authError;

      throw PixivAuthException(e.message ?? 'Token request failed');
    }
  }
}

dynamic _decode(dynamic data) => switch (data) {
  final String s when s.isNotEmpty => _tryDecode(s),
  _ => data,
};

dynamic _tryDecode(String s) {
  try {
    return jsonDecode(s);
  } catch (_) {
    return null;
  }
}

/// The auth endpoint's error envelope is shaped differently from the rest of
/// the API:
/// `{"has_error":true,"errors":{"system":{"message":"...","code":1508}},
/// "error":"invalid_grant"}`.
PixivAuthException? _authErrorOf(dynamic decoded) {
  if (decoded is! Map) return null;
  if (decoded['has_error'] != true) return null;

  final errors = decoded['errors'];
  final system = errors is Map ? errors['system'] : null;
  final message = system is Map
      ? (system['message']?.toString() ?? 'Authentication failed')
      : (decoded['error']?.toString() ?? 'Authentication failed');
  final code = decoded['error']?.toString();

  return PixivAuthException(message, code: code);
}
