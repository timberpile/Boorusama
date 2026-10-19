// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' hide GoRouterHelper;

// Project imports:
import 'navigation/app_navigation.dart';
import 'navigation/production_navigation_router.dart';

export 'package:boorusama/core/routers/routers.dart';

export 'navigation/app_navigation.dart';
export 'navigation/navigation_facade.dart';

export 'package:go_router/go_router.dart' hide GoRouterHelper;

final routerProvider = Provider<GoRouter>((ref) {
  return createProductionNavigationRouter(
    ref,
    ref.watch(appNavigationProvider),
  );
});

extension RouterRef on WidgetRef {
  GoRouter get router => read(routerProvider);
}
