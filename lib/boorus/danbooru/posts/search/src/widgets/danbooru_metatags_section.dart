// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../../../core/configs/config/providers.dart';
import '../../../../../../core/search/options/search_options_section.dart';
import '../../../../../../core/search/search/widgets.dart';
import '../../../../../../foundation/url_launcher.dart';
import '../../../../configs/providers.dart';
import '../../../../danbooru.dart';
import '../../../../tags/user_metatags/providers.dart';

class DanbooruMetatagsSection extends ConsumerWidget {
  const DanbooruMetatagsSection({super.key, this.onOptionTap});

  final ValueChanged<String>? onOptionTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfigAuth;
    final loginDetails = ref.watch(danbooruLoginDetailsProvider(config));
    final booru = ref.watch(danbooruProvider);
    final notifier = ref.watch(danbooruUserMetatagsProvider.notifier);
    final pins = ref.watch(danbooruUserMetatagsProvider).valueOrNull;
    final controller = InheritedSearchPageController.maybeOf(context);
    final help = !loginDetails.hasStrictSFW
        ? () => launchExternalUrl(
            Uri.parse(booru.cheetsheet(config.url)),
            mode: ExternalLaunchMode.platformDefault,
            launcher: ref.read(externalUrlLauncherProvider),
          )
        : null;
    if (controller != null) {
      return SearchOptionsSection(
        controller: controller,
        pinnedKeys: pins,
        onPin: notifier.add,
        onUnpin: notifier.delete,
        onHelpRequest: help,
      );
    }
    // Preserve callback-based consumers outside the post-search controller.
    return MetatagsSection(
      onOptionTap: onOptionTap,
      metatags: ref.watch(metatagsProvider).toList(),
      userMetatags: pins,
      onHelpRequest: help,
      onUserMetatagDeleted: notifier.delete,
      onUserMetatagAdded: (tag) => notifier.add(tag.name),
    );
  }
}
