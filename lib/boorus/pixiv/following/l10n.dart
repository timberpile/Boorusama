import 'package:i18n/i18n.dart';

extension PixivFollowingTranslations on Translations {
  PixivFollowingL10n get pixivFollowing =>
      PixivFollowingL10n($meta.locale.languageCode);
}

class PixivFollowingL10n {
  const PixivFollowingL10n(this.languageCode);
  final String languageCode;

  String get navigationLabel => switch (languageCode) {
    'de' => 'Folge ich',
    _ => 'Following',
  };

  String get title => switch (languageCode) {
    'de' => 'Pixiv: Folge ich',
    _ => 'Pixiv Following',
  };
}
