/// Explicit account-favorites collection. None of these providers starts work
/// merely by being read; use ServerFavoriteFetchNotifier.start from user actions.
library;

export 'src/server_favorites/controller.dart';
export 'src/server_favorites/fetch_runner.dart';
export 'src/server_favorites/settings_provider.dart';
export 'src/server_favorites/source.dart';
export 'src/server_favorites/target_settings.dart';
