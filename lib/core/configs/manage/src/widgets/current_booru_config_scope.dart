// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../config/types.dart';
import '../../../../content/content_access.dart';
import '../../../../content/content_access_provider.dart';
import '../../../../content/content_media_access.dart';
import '../../../../navigation/page_source_context.dart';
import '../../../../navigation/page_presentation_profile.dart';

import 'package:i18n/i18n.dart';

import '../providers/booru_config_provider.dart';
import '../providers/current_booru_providers.dart';

class CurrentBooruConfigScope extends ConsumerWidget {
  const CurrentBooruConfigScope({
    required this.config,
    required this.child,
    this.accessKey,
    this.requireAccess = false,
    this.bookmarkId,
    super.key,
  });

  final BooruConfig config;
  final Widget child;
  final ContentAccessKey? accessKey;
  final bool requireAccess;
  final int? bookmarkId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key =
        accessKey ??
        config.anonymousReadScope?.key ??
        ref.watch(currentContentAccessKeyProvider);
    final required =
        requireAccess ||
        config.anonymousReadScope != null ||
        ref.watch(contentAccessRequiredProvider);
    final recordId = bookmarkId ?? ref.watch(currentContentBookmarkIdProvider);
    Widget scoped(BooruConfig value) => _scope(
      value,
      key: key,
      required: required,
      recordId: recordId,
    );
    if (required) {
      final access = key == null
          ? null
          : ref.watch(contentAccessContextProvider(key));
      if (access == null ||
          access.config?.auth != config.auth ||
          (access.config?.anonymousReadScope?.isCurrent == false) ||
          (key!.profileId != null && key.profileId != config.id)) {
        return _scope(
          BooruConfig.empty,
          key: null,
          required: true,
          recordId: recordId,
        );
      }
      if (access.key.profileId == null) return scoped(access.config!);
    }
    // Source-less mixed posts use an inert scope with no account credentials.
    if (config == BooruConfig.empty) return scoped(config);
    final live = ref
        .watch(booruConfigProvider)
        .where((value) => value.id == config.id)
        .firstOrNull;
    if (live == null || live.auth != config.auth)
      return Scaffold(
        body: Center(child: Text(context.t.navigation.unavailable_profile)),
      );
    return scoped(live);
  }

  Widget _scope(
    BooruConfig config, {
    required ContentAccessKey? key,
    required bool required,
    required int? recordId,
  }) => ProviderScope(
    overrides: [
      currentContentAccessKeyProvider.overrideWithValue(
        key,
      ),
      contentAccessRequiredProvider.overrideWithValue(
        required,
      ),
      currentContentBookmarkIdProvider.overrideWithValue(recordId),
      pagePresentationProfileProvider.overrideWithValue(
        config == BooruConfig.empty || config.anonymousReadScope != null
            ? null
            : config,
      ),
      explicitPageSourceProvider.overrideWithValue(
        config == BooruConfig.empty || config.anonymousReadScope != null
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
