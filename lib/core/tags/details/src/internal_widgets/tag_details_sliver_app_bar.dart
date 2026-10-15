// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../bulk_downloads/routes.dart';

class TagDetailsSlilverAppBar extends ConsumerWidget {
  const TagDetailsSlilverAppBar({
    required this.tagName,
    super.key,
  });

  final String tagName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return KurumiSliverAppBar(
      floating: true,
      backgroundColor: Kurumi.themeOf(context).colorScheme.surface,
      actions: [
        IconButton(
          splashRadius: 20,
          onPressed: () {
            goToBulkDownloadPage(
              context,
              [tagName],
              ref: ref,
            );
          },
          icon: const Icon(Symbols.download),
        ),
      ],
    );
  }
}
