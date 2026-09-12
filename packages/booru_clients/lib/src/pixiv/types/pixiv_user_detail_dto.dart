import 'pixiv_illust_user_dto.dart';

/// Response of `/v1/user/detail`.
///
/// Only [user] is typed; `profile`, `profile_publicity` and `workspace` are
/// kept as raw maps since no current caller needs them and Pixiv's shape for
/// those has been observed to vary by account privacy settings.
class PixivUserDetailDto {
  const PixivUserDetailDto({
    this.user,
    this.profile,
    this.profilePublicity,
    this.workspace,
  });

  factory PixivUserDetailDto.fromJson(Map<String, dynamic> json) {
    return PixivUserDetailDto(
      user: PixivIllustUser.fromJson(json['user'] as Map<String, dynamic>?),
      profile: json['profile'] as Map<String, dynamic>?,
      profilePublicity: json['profile_publicity'] as Map<String, dynamic>?,
      workspace: json['workspace'] as Map<String, dynamic>?,
    );
  }

  final PixivIllustUser? user;
  final Map<String, dynamic>? profile;
  final Map<String, dynamic>? profilePublicity;
  final Map<String, dynamic>? workspace;
}
