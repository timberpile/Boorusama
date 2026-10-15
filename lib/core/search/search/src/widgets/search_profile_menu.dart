import 'package:anchor_ui/anchor_ui.dart' show AnchorData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../configs/config/types.dart';
import '../../../../configs/manage/providers.dart';

class SearchProfileMenu extends ConsumerWidget {
  const SearchProfileMenu({required this.onSelected, super.key});

  final ValueChanged<BooruConfig> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(booruConfigProvider);
    final activeId = ref.watch(currentBooruConfigProvider.select((c) => c.id));
    final parentMenu = AnchorData.maybeOf(context)?.controller;

    String label(BooruConfig profile) {
      final name = profile.name.trim();
      final duplicates = profiles.where((p) => p.name.trim() == name);
      final base = name.isEmpty
          ? profile.url
          : duplicates.length > 1
          ? '$name (${profile.url})'
          : name;
      // Identical names and URLs are valid for different accounts.
      return profiles
                  .where((p) => p.name.trim() == name && p.url == profile.url)
                  .length >
              1
          ? '$base · ${profiles.indexOf(profile) + 1}'
          : base;
    }

    return KurumiPopupMenuButton(
      maxWidth: 300,
      semanticLabel: context.t.search.switch_profile,
      items: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.5,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final profile in profiles)
                  Semantics(
                    checked: profile.id == activeId,
                    child: KurumiPopupMenuItem(
                      title: Text(label(profile)),
                      icon: SizedBox(
                        width: 24,
                        child: profile.id == activeId
                            ? const Icon(Symbols.check)
                            : null,
                      ),
                      onTap: () {
                        parentMenu?.hide();
                        onSelected(profile);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
      child: KurumiPopupMenuItem(
        title: Text(context.t.search.switch_profile),
        icon: const Icon(Symbols.swap_horiz),
        trailing: const Icon(Symbols.chevron_right),
        onTap: () {},
      ),
    );
  }
}
