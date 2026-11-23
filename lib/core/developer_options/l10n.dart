// Package imports:
import 'package:i18n/i18n.dart';

extension DeveloperOptionsTranslationsX on Translations {
  DeveloperOptionsL10n get developerOptions => const DeveloperOptionsL10n();
}

class DeveloperOptionsL10n {
  const DeveloperOptionsL10n();

  String get title => 'Developer options';

  String get blockAutomaticMedia => 'Block automatic media loading';

  String get blockAutomaticMediaDescription =>
      'Prevents images, videos, and media preloading from using the network. '
      'Explicit downloads remain available.';

  String get zoomStudy => 'Zoom Study';

  String get zoomStudyDescription =>
      'Show a zoom meter in the Post Viewer. Record preferred scales and export '
      'a JSON report to Downloads. Records persist locally across restarts.';

  String get zoomStudyRecord => 'Record preferred zoom';

  String get zoomStudyExport => 'Export Zoom Study JSON';

  String get zoomStudyRecorded => 'Zoom recorded';

  String get zoomStudyExported => 'Zoom study exported to';

  String get zoomStudyFailure => 'Could not save zoom study';

  String get zoomStudyAndroidOnly => 'JSON export requires Android 10 or later';

  String get mediaLoadingOff => 'Media loading off';

  String get developerMode => 'Developer mode';
}
