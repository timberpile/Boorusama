import 'package:i18n/i18n.dart';

/// Fork-local localization, following the Developer Options translation bridge.
extension TimelineToolbarTranslations on Translations {
  TimelineToolbarL10n get timelineToolbar =>
      TimelineToolbarL10n($meta.locale.languageCode);
}

class TimelineToolbarL10n {
  const TimelineToolbarL10n(this.languageCode);
  final String languageCode;

  String get keepVisible => switch (languageCode) {
    'de' => 'Timeline-Leiste sichtbar halten',
    _ => 'Keep Timeline Toolbar Visible',
  };

  String get scrollDescription => switch (languageCode) {
    'de' => 'Sonst beim Herunterscrollen ausblenden und beim Hochscrollen wieder anzeigen.',
    _ => 'Otherwise hide when scrolling down and show again when scrolling up.',
  };
}
