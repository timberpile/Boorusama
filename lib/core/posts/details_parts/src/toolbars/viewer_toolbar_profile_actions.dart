import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../boorus/booru/types.dart';
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/config/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../settings/providers.dart';
import '../../../../settings/src/types/viewer_toolbar_layout.dart';
import '../../../../settings/types.dart';
import '../../../favorites/providers.dart';

bool supportsViewerToolbarLayout(BooruType type) => type != BooruType.hydrus;

typedef ViewerToolbarProfileActions = ({
  List<ViewerToolbarAction> actions,
  int visibleCount,
});

typedef ViewerToolbarProfileActionsBuilder =
    ViewerToolbarProfileActions Function(
      Ref ref,
      BooruConfigAuth auth,
    );

final standardViewerFavoriteAvailableProvider = Provider.autoDispose
    .family<bool, BooruConfigAuth>((ref, auth) {
      final isAuthorized = ref
          .watch(booruLoginDetailsProvider(auth))
          .hasLogin();
      return (isAuthorized && ref.watch(canFavoriteProvider(auth))) ||
          ref.watch(favoriteNeedsWebsiteLoginProvider(auth));
    });

ViewerToolbarProfileActions standardViewerToolbarActions(
  Ref ref,
  BooruConfigAuth auth, {
  bool? favorite,
  int visibleCount = 5,
}) => (
  visibleCount: visibleCount,
  actions: [
    if (favorite ?? ref.watch(standardViewerFavoriteAvailableProvider(auth)))
      ViewerToolbarAction.favorite,
    ViewerToolbarAction.bookmark,
    if (auth.anonymousReadScope == null) ViewerToolbarAction.download,
    ViewerToolbarAction.share,
    if (ref.watch(booruBuilderProvider(auth))?.commentPageBuilder != null)
      ViewerToolbarAction.comments,
  ],
);

/// Editor metadata for an example image with tags and an original.
final viewerToolbarProfileLayoutProvider = Provider.autoDispose
    .family<ViewerToolbarLayout, BooruConfig>((ref, profile) {
      final auth = profile.auth;
      final custom = ref
          .watch(booruBuilderProvider(auth))
          ?.postDetailsUIBuilder
          .viewerToolbarProfileActions;
      final definition = custom == null
          ? standardViewerToolbarActions(ref, auth)
          : custom(ref, auth);
      final config = profile.viewerConfigs;
      final viewer = config != null && config.enable
          ? config.settings
          : ref.watch(settingsProvider.select((settings) => settings.viewer));
      final actions = [
        ...definition.actions,
        if (!ref.watch(booruLoginDetailsProvider(auth)).hasStrictSFW)
          ViewerToolbarAction.browser,
        ViewerToolbarAction.tags,
        if (viewer.postQuality != PostQuality.original &&
            !viewer.loadOriginalOnZoom)
          ViewerToolbarAction.original,
        ViewerToolbarAction.slideshow,
      ];
      final count = definition.visibleCount.clamp(
        0,
        ViewerToolbarLayout.maxToolbarActions,
      );
      return ViewerToolbarLayout(
        toolbar: actions.take(count),
        more: actions.skip(count),
      );
    }, dependencies: [settingsProvider]);
