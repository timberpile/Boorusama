class PixivUserProfileImageUrls {
  const PixivUserProfileImageUrls({this.medium});

  factory PixivUserProfileImageUrls.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PixivUserProfileImageUrls();

    return PixivUserProfileImageUrls(medium: json['medium'] as String?);
  }

  final String? medium;
}

/// The illust author, as embedded in an illust object.
///
/// [id] is an `int` here, unlike [PixivTokenUser.id] which the token
/// endpoint returns as a `String` — the two are intentionally NOT shared.
class PixivIllustUser {
  const PixivIllustUser({
    this.id,
    this.name,
    this.account,
    this.profileImageUrls,
    this.isFollowed,
  });

  factory PixivIllustUser.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PixivIllustUser();

    return PixivIllustUser(
      id: json['id'] as int?,
      name: json['name'] as String?,
      account: json['account'] as String?,
      profileImageUrls: PixivUserProfileImageUrls.fromJson(
        json['profile_image_urls'] as Map<String, dynamic>?,
      ),
      isFollowed: json['is_followed'] as bool?,
    );
  }

  final int? id;
  final String? name;
  final String? account;
  final PixivUserProfileImageUrls? profileImageUrls;
  final bool? isFollowed;
}
