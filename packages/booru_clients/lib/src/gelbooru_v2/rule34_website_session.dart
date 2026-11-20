/// The website session for Rule34's HTTPS origin. API credentials use a
/// separate transport and are never included in these headers.
final class Rule34WebsiteSession {
  const Rule34WebsiteSession._(this.userId, this._signedUserId, this._token);

  static final origin = Uri.https('rule34.xxx');
  static final addFavoriteUri = origin.replace(path: '/public/addfav.php');
  static final indexUri = origin.replace(path: '/index.php');
  static const userIdCookie = 'r34_uid';
  static const sessionCookie = '__Host-session';

  // Store the browser session in the profile's existing website credential
  // slot, tagged with its scheme and account so legacy hashes fail closed.
  static const _prefix = 'rule34-session-v1:';
  static final _userIdPattern = RegExp(r'^[0-9]+$');
  static final _cookieOctets = RegExp(
    r'^[\x21\x23-\x2B\x2D-\x3A\x3C-\x5B\x5D-\x7E]+$',
  );

  final String userId;
  final String _signedUserId;
  final String _token;

  static bool isWebsite(String url) => Uri.tryParse(url)?.host == origin.host;

  static bool matchesOrigin(Uri uri) =>
      uri.scheme == origin.scheme &&
      uri.host == origin.host &&
      uri.port == origin.port &&
      uri.userInfo.isEmpty;

  static Rule34WebsiteSession? fromCookies({
    required String signedUserId,
    required String token,
  }) {
    final separator = signedUserId.indexOf('.');
    if (separator <= 0 ||
        separator == signedUserId.length - 1 ||
        _cookieOctets.stringMatch(signedUserId) != signedUserId ||
        _cookieOctets.stringMatch(token) != token) {
      return null;
    }
    final userId = signedUserId.substring(0, separator);
    if (_userIdPattern.stringMatch(userId) != userId) return null;
    return Rule34WebsiteSession._(userId, signedUserId, token);
  }

  static Rule34WebsiteSession? fromStoredValue(
    String? storedValue, {
    required String? userId,
  }) {
    if (userId == null || storedValue == null) return null;
    final prefix = '$_prefix$userId:';
    if (!storedValue.startsWith(prefix)) return null;
    final separator = storedValue.indexOf(';', prefix.length);
    if (separator < 0) return null;
    final session = fromCookies(
      signedUserId: storedValue.substring(prefix.length, separator),
      token: storedValue.substring(separator + 1),
    );
    return session?.userId == userId ? session : null;
  }

  String toStoredValue() => '$_prefix$userId:$_signedUserId;$_token';

  Map<String, String> get headers => {
    'Cookie': '$userIdCookie=$_signedUserId; $sessionCookie=$_token',
  };
}
