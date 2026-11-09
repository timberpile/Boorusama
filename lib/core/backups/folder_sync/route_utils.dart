import 'package:kurumi/material.dart';

import '../../settings/src/widgets/settings_page_scaffold.dart';

Future<T?> pushFolderSyncPage<T>(BuildContext context, WidgetBuilder builder) {
  final settings = context
      .getInheritedWidgetOfExactType<SettingsPageNavigationScope>();
  // Settings owns a separate category navigator. Workflow pages belong above
  // that host so platform Back cannot remove the category beneath them.
  final navigator = settings == null
      ? Navigator.of(context)
      : settings.applicationNavigator ??
            Navigator.of(context, rootNavigator: true);
  return navigator.push<T>(MaterialPageRoute(builder: builder));
}
