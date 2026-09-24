// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../config/types.dart';
import '../providers/current_booru_providers.dart';

class CurrentBooruConfigScope extends StatelessWidget {
  const CurrentBooruConfigScope({
    required this.config,
    required this.child,
    super.key,
  });

  final BooruConfig config;
  final Widget child;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      currentReadOnlyBooruConfigProvider.overrideWithValue(config),
      currentReadOnlyBooruConfigAuthProvider.overrideWithValue(config.auth),
      currentReadOnlyBooruConfigSearchProvider.overrideWithValue(config.search),
      currentReadOnlyBooruConfigFilterProvider.overrideWithValue(config.filter),
      currentReadOnlyBooruConfigGestureProvider.overrideWithValue(
        config.postGestures,
      ),
      currentReadOnlyBooruConfigThemeProvider.overrideWithValue(config.theme),
      currentReadOnlyBooruConfigLayoutProvider.overrideWithValue(config.layout),
      currentReadOnlyBooruConfigViewerProvider.overrideWithValue(config.viewer),
      currentReadOnlyBooruConfigDownloadProvider.overrideWithValue(
        config.download,
      ),
    ],
    child: child,
  );
}
