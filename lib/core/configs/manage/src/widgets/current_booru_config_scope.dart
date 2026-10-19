// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../config/types.dart';
import '../../../../navigation/page_source_context.dart';
import '../../../../navigation/page_presentation_profile.dart';

import 'package:i18n/i18n.dart';

import '../providers/booru_config_provider.dart';
import '../providers/current_booru_providers.dart';

class CurrentBooruConfigScope extends ConsumerWidget {
  const CurrentBooruConfigScope({
    required this.config,
    required this.child,
    super.key,
  });

  final BooruConfig config;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Source-less mixed posts use an inert scope with no account credentials.
    if (config == BooruConfig.empty) return _scope(config);
    final live = ref
        .watch(booruConfigProvider)
        .where((value) => value.id == config.id)
        .firstOrNull;
    if (live == null || live.auth != config.auth)
      return Scaffold(
        body: Center(child: Text(context.t.navigation.unavailable_profile)),
      );
    return _scope(live);
  }

  Widget _scope(BooruConfig config) => ProviderScope(
    overrides: [
      pagePresentationProfileProvider.overrideWithValue(
        config == BooruConfig.empty ? null : config,
      ),
      explicitPageSourceProvider.overrideWithValue(
        config == BooruConfig.empty
            ? null
            : PageSourceContext(profileId: config.id),
      ),
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
    // The page owns controller lifetimes. A mixed viewer changes presentation
    // profiles while retaining its sheet controller and ordered post snapshot.
    child: child,
  );
}
