// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../configs/config/widgets.dart';
import '../providers/settings_notifier.dart';
import '../providers/settings_provider.dart';
import '../widgets/more_settings_redirect_card.dart';
import '../widgets/settings_interaction_blocker.dart';
import '../widgets/settings_page_scaffold.dart';
import 'appearance/image_viewer_settings_section.dart';
import 'viewer_toolbar_layout_page.dart';

class ImageViewerPage extends ConsumerStatefulWidget {
  const ImageViewerPage({
    super.key,
  });
  @override
  ConsumerState<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends ConsumerState<ImageViewerPage> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifer = ref.watch(settingsNotifierProvider.notifier);
    return SettingsPageScaffold(
      title: Text(context.t.settings.image_viewer.image_viewer),
      children: [
        // Toolbar layout is global, even when this profile overrides media settings.
        ListTile(
          leading: const Icon(Icons.view_week_outlined),
          title: Text(context.t.post.detail.widgets.toolbar),
          subtitle: Text(context.t.settings.appearance.customize),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: 'viewer_toolbar_layout'),
              builder: (_) => const ViewerToolbarLayoutPage(),
            ),
          ),
        ),
        ViewerSettingsInteractionBlocker(
          child: ImageViewerSettingsSection(
            viewer: settings.viewer,
            onUpdate: (change) => notifer.updateWith(
              (settings) => settings.copyWith(
                viewer: change(settings.viewer),
              ),
            ),
          ),
        ),

        BooruConfigMoreSettingsRedirectCard.imageViewer(
          extraActions: [
            RedirectAction(
              label: context.t.settings.accessibility.accessibility,
              onPressed: () => SettingsPageNavigationScope.of(
                context,
              ).openDestination('accessibility'),
            ),
          ],
        ),
      ],
    );
  }
}
