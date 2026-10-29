// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../foundation/url_launcher.dart';
import '../../../configs/config/providers.dart';
import '../../../configs/config/types.dart';
import '../../../premiums/providers.dart';
import '../../../settings/routes.dart';
import '../../../settings/types.dart';
import '../../../settings/src/providers/viewer_providers.dart';
import '../../../tags/show/routes.dart';
import '../../../widgets/adaptive_button_row.dart';
import '../../details_manager/routes.dart';
import '../../post/providers.dart';
import '../../post/types.dart';
import '../../cross_profile_lookup/page.dart';
import 'toolbars/customizable_post_toolbar.dart';

class CommonPostButtonsBuilder extends ConsumerWidget {
  const CommonPostButtonsBuilder({
    required this.builder,
    required this.post,
    required this.onStartSlideshow,
    required this.onLoadOriginal,
    required this.config,
    required this.configViewer,
    super.key,
    this.copy = true,
  });

  final BooruConfigAuth? config;
  final BooruConfigViewer? configViewer;
  final Widget Function(BuildContext context, List<ButtonData> commonButtons)
  builder;
  final Post post;
  final VoidCallback onStartSlideshow;
  final VoidCallback? onLoadOriginal;
  final bool copy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = this.config;

    final postLinkGenerator = config != null
        ? ref.watch(postLinkGeneratorProvider(config))
        : null;

    final loginDetails = config != null
        ? ref.watch(booruLoginDetailsProvider(config))
        : null;
    final hasStrictSFW = loginDetails?.hasStrictSFW ?? true;
    final (loadOriginalOnZoom, postQuality) = ref.watch(
      imageViewerSettingsProvider.select(
        (settings) => (settings.loadOriginalOnZoom, settings.postQuality),
      ),
    );

    final commonButtons = [
      SimpleButtonData(
        icon: Icons.travel_explore,
        title: context.t.post.cross_profile.action,
        placement: ButtonPlacement.menuOnly,
        onPressed: () => findOnOtherProfiles(ref, post),
      ),
      if (postLinkGenerator != null && config != null)
        if (!hasStrictSFW)
          ViewerToolbarSimpleButtonData(
            action: ViewerToolbarAction.browser,
            icon: Icons.open_in_browser,
            title: context.t.post.action.view_in_browser,
            onPressed: () => launchExternalUrlString(
              postLinkGenerator.getLink(post),
              launcher: ref.read(externalUrlLauncherProvider),
            ),
          ),
      if (config != null)
        if (post.tags.isNotEmpty)
          ViewerToolbarSimpleButtonData(
            action: ViewerToolbarAction.tags,
            icon: Icons.tag,
            title: context.t.post.action.view_tags,
            onPressed: () => goToShowTaglistPage(
              ref,
              post,
              config: ref.readConfig,
            ),
          ),
      if (postQuality != PostQuality.original &&
          !loadOriginalOnZoom &&
          post.hasFullView &&
          onLoadOriginal != null)
        ViewerToolbarSimpleButtonData(
          action: ViewerToolbarAction.original,
          icon: Icons.fullscreen,
          title: context.t.post.action.load_original,
          onPressed: () => onLoadOriginal!(),
        ),
      ViewerToolbarSimpleButtonData(
        action: ViewerToolbarAction.slideshow,
        icon: Icons.slideshow,
        title: context.t.post.action.slideshow,
        onPressed: onStartSlideshow,
      ),
      if (ref.watch(showPremiumFeatsProvider))
        SimpleButtonData(
          icon: Icons.brush,
          title: context.t.settings.appearance.customize,
          placement: ButtonPlacement.menuOnly,
          onPressed: () {
            goToDetailsLayoutManagerForPreviewWidgets(ref);
          },
        ),
      SimpleButtonData(
        icon: Icons.settings,
        title: context.t.settings.settings,
        placement: ButtonPlacement.menuOnly,
        onPressed: () => openImageViewerSettingsPage(ref),
      ),
    ];

    return builder(context, commonButtons);
  }
}
