import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../posts/listing/src/widgets/post_grid_config_icon_button.dart';
import '../../posts/listing/src/widgets/post_list_configuration_header.dart';
import '../../settings/providers.dart';

/// Native entries share listing preferences without pretending to be Posts.
class NativeContentConfigurationHeader extends ConsumerWidget {
  const NativeContentConfigurationHeader({
    required this.count,
    this.allowPageModeChange = false,
    super.key,
  });
  final int count;
  final bool allowPageModeChange;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) => PostListConfigurationHeader(
    hiddenCount: null,
    postCount: count,
    counterLabel: context.t.search.result_counter(n: count),
    blacklistControls: const SizedBox.shrink(),
    trailing: KurumiPopupMenuButton(
      iconBackgroundColor: Colors.transparent,
      items: [
        KurumiPopupMenuItem(
          title: Text(context.t.posts.actions.view_options),
          icon: const Icon(Icons.settings, size: 18),
          onTap: () {
            if (!context.mounted) return;
            final settings = ref.read(settingsNotifierProvider.notifier);
            Kurumi.showAppModalBottomSheet(
              context: context,
              routeSettings: const RouteSettings(name: 'grid_config'),
              builder: (_) {
                return PostGridActionSheet(
                  // Cursor-only sources retain their explicit infinite mode.
                  showPageMode: allowPageModeChange,
                  onModeChanged: (value) => settings.updateWith(
                    (state) => state.copyWith(
                      listing: state.listing.copyWith(pageMode: value),
                    ),
                  ),
                  onGridChanged: (value) => settings.updateWith(
                    (state) => state.copyWith(
                      listing: state.listing.copyWith(gridSize: value),
                    ),
                  ),
                  onImageListChanged: (value) => settings.updateWith(
                    (state) => state.copyWith(
                      listing: state.listing.copyWith(imageListType: value),
                    ),
                  ),
                  onImageQualityChanged: (value) => settings.updateWith(
                    (state) => state.copyWith(
                      listing: state.listing.copyWith(imageQuality: value),
                    ),
                  ),
                );
              },
            );
          },
        ),
        KurumiPopupMenuItem(
          title: Text(context.t.posts.actions.edit_blacklist),
          icon: const Icon(Icons.block, size: 18),
          onTap: () {
            if (!context.mounted) return;
            Kurumi.showAppModalBottomSheet(
              context: context,
              builder: (_) => const EditBlacklistActionSheet(),
            );
          },
        ),
      ],
    ),
  );
}
