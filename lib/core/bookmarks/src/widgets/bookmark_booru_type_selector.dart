// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../config_widgets/website_logo.dart';
import '../providers/local_providers.dart';
import 'bookmark_option_selector.dart';

class BookmarkBooruSourceUrlSelector extends ConsumerWidget {
  const BookmarkBooruSourceUrlSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedBooruUrlProvider);
    final sources = ref.watch(availableBooruUrlsProvider);
    final all = context.t.bookmark.groups.all;
    final label = '${context.t.post.detail.source_label}: ${selected ?? all}';

    return BookmarkOptionSelector<String?>(
      label: label,
      value: selected,
      options: [null, ...?sources.valueOrNull],
      optionLabel: (source) => source ?? all,
      optionLeading: (source) => source == null
          ? const Icon(Icons.public, size: 20)
          : ConfigAwareWebsiteLogo(
              url: (Uri.tryParse(source)?.hasScheme ?? false)
                  ? source
                  : 'https://$source',
              width: 20,
              height: 20,
            ),
      onSelected: (source) {
        ref.read(selectedBooruUrlProvider.notifier).state = source;
      },
    );
  }
}
