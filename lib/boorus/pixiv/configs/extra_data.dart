// Dart imports:
import 'dart:convert';

/// The non-secret half of a Pixiv login, stored as JSON in
/// `BooruConfig.passHash`.
///
/// The refresh token itself lives in `BooruConfig.apiKey`; nothing here is a
/// credential, so [toString] is safe — but note that it is also never
/// *needed*: this type exists purely to keep the account label and premium
/// flag out of the credential field.
///
/// Parsing is total: any legacy, foreign or malformed `passHash` yields
/// defaults rather than throwing, because the field is shared with other
/// engines' formats and with older versions of this one.
class PixivExtraData {
  const PixivExtraData({
    this.userId,
    this.userName,
    this.isPremium,
    this.xRestrict,
    this.tokenExpiry,
  });

  factory PixivExtraData.fromPassHash(String? passHash) {
    if (passHash == null || passHash.isEmpty) {
      return const PixivExtraData();
    }

    final decoded = _tryDecode(passHash);

    return switch (decoded) {
      final Map<String, dynamic> json => PixivExtraData(
        userId: switch (json['userId']) {
          final String id => id,
          final int id => id.toString(),
          _ => null,
        },
        userName: switch (json['userName']) {
          final String name => name,
          _ => null,
        },
        isPremium: switch (json['isPremium']) {
          final bool premium => premium,
          _ => null,
        },
        xRestrict: switch (json['xRestrict']) {
          final int x => x,
          _ => null,
        },
        tokenExpiry: switch (json['tokenExpiry']) {
          final int ms => DateTime.fromMillisecondsSinceEpoch(ms),
          _ => null,
        },
      ),
      _ => const PixivExtraData(),
    };
  }

  /// Builds the metadata to store after a successful token exchange or
  /// refresh. [expiresIn] is the access token's lifetime in seconds, as
  /// reported by the token endpoint.
  factory PixivExtraData.fromTokenResponse({
    required String? userId,
    required String? userName,
    required bool? isPremium,
    required int? xRestrict,
    required int? expiresIn,
    DateTime? now,
  }) => PixivExtraData(
    userId: userId,
    userName: userName,
    isPremium: isPremium,
    xRestrict: xRestrict,
    tokenExpiry: expiresIn == null
        ? null
        : (now ?? DateTime.now()).add(Duration(seconds: expiresIn)),
  );

  final String? userId;
  final String? userName;
  final bool? isPremium;

  /// The account's content-setting level, as reported by the token
  /// endpoint's embedded user object: 0 = all-ages only, 1 = R-18
  /// permitted, 2 = R-18G permitted. Distinct from the same-named field on
  /// an illust, which is that work's own rating.
  final int? xRestrict;

  /// When the *access* token obtained alongside this metadata stops working.
  /// The refresh token in `apiKey` outlives it and has no published expiry,
  /// so this is diagnostic information, not a session deadline.
  final DateTime? tokenExpiry;

  PixivExtraData copyWith({
    DateTime? tokenExpiry,
  }) => PixivExtraData(
    userId: userId,
    userName: userName,
    isPremium: isPremium,
    xRestrict: xRestrict,
    tokenExpiry: tokenExpiry ?? this.tokenExpiry,
  );

  String toPassHash() => jsonEncode({
    'userId': ?userId,
    'userName': ?userName,
    'isPremium': ?isPremium,
    'xRestrict': ?xRestrict,
    'tokenExpiry': ?tokenExpiry?.millisecondsSinceEpoch,
  });
}

dynamic _tryDecode(String value) {
  try {
    return jsonDecode(value);
  } catch (_) {
    return null;
  }
}
