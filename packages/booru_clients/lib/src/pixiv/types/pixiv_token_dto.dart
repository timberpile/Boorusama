/// The account embedded in a token response.
///
/// [id] is a `String` here — unlike [PixivIllustUser.id], which the illust
/// API returns as an `int`. The two are intentionally separate model
/// classes; do not unify them.
class PixivTokenUser {
  const PixivTokenUser({
    this.id,
    this.name,
    this.account,
    this.isPremium,
    this.xRestrict,
    this.mailAddress,
  });

  factory PixivTokenUser.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PixivTokenUser();

    return PixivTokenUser(
      id: _parseId(json['id']),
      name: json['name'] as String?,
      account: json['account'] as String?,
      isPremium: json['is_premium'] as bool?,
      xRestrict: json['x_restrict'] as int?,
      mailAddress: json['mail_address'] as String?,
    );
  }

  final String? id;
  final String? name;
  final String? account;
  final bool? isPremium;
  final int? xRestrict;
  final String? mailAddress;

  /// The token endpoint returns `id` as a JSON string, but leniently accept
  /// a numeric one too in case that ever changes.
  static String? _parseId(dynamic value) => switch (value) {
    final String s => s,
    final int n => n.toString(),
    _ => null,
  };
}

/// Response of the `/auth/token` endpoint (authorization-code or refresh
/// grant). The API duplicates every field at the top level AND nested under
/// `response` — [fromJson] reads `response` first and falls back to the top
/// level.
///
/// Deliberately does NOT extend Equatable and overrides [toString] so a
/// stray `print`/log of this object never writes [accessToken] or
/// [refreshToken] — both are full-account bearer credentials.
class PixivTokens {
  const PixivTokens({
    this.accessToken,
    this.refreshToken,
    this.expiresIn,
    this.tokenType,
    this.user,
  });

  factory PixivTokens.fromJson(Map<String, dynamic> json) {
    final inner = json['response'] is Map<String, dynamic>
        ? json['response'] as Map<String, dynamic>
        : json;

    return PixivTokens(
      accessToken: (inner['access_token'] ?? json['access_token']) as String?,
      refreshToken:
          (inner['refresh_token'] ?? json['refresh_token']) as String?,
      expiresIn: (inner['expires_in'] ?? json['expires_in']) as int?,
      tokenType: (inner['token_type'] ?? json['token_type']) as String?,
      user: PixivTokenUser.fromJson(
        (inner['user'] ?? json['user']) as Map<String, dynamic>?,
      ),
    );
  }

  final String? accessToken;
  final String? refreshToken;
  final int? expiresIn;
  final String? tokenType;
  final PixivTokenUser? user;

  /// Deliberately omits [accessToken] and [refreshToken].
  @override
  String toString() =>
      'PixivTokens(expiresIn: $expiresIn, tokenType: $tokenType, '
      'user: ${user?.id})';
}
