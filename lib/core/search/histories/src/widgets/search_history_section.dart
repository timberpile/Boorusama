// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../../../core/widgets/widgets.dart';
import '../../../../../foundation/display/media_query_utils.dart';
import '../../../../../foundation/platform.dart';
import '../../../options/collapsible_search_section.dart';
import '../../../selected_tags/types.dart';
import '../types/search_history.dart';

class SearchHistorySection extends ConsumerWidget {
  const SearchHistorySection({
    required this.onHistoryTap,
    required this.histories,
    super.key,
    this.onFullHistoryRequested,
    this.maxHistory = 5,
    this.showTime = false,
    this.reverseScheme,
  });

  final ValueChanged<SearchHistory> onHistoryTap;
  final void Function()? onFullHistoryRequested;
  final List<SearchHistory> histories;
  final int maxHistory;
  final bool showTime;
  final bool? reverseScheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (histories.isEmpty) return const SizedBox.shrink();
    return RemoveLeftPaddingOnLargeScreen(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: CollapsibleSearchSection(
          title: context.t.search.history.history,
          storageId: 'search-history',
          trailing: onFullHistoryRequested != null
              ? IconButton(
                  tooltip: context.t.search.history.history,
                  onPressed: onFullHistoryRequested,
                  icon: const Icon(Symbols.manage_history),
                )
              : null,
          child: Column(
            children: [
              for (final item in histories.take(maxHistory))
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    visualDensity: VisualDensity.compact,
                    title: SearchHistoryQueryWidget(
                      history: item,
                      reverseScheme: reverseScheme,
                    ),
                    contentPadding: EdgeInsets.zero,
                    onTap: () => onHistoryTap(item),
                    minTileHeight: ref.watch(appPlatformProvider).isDesktop
                        ? 0
                        : null,
                    subtitle: showTime
                        ? DateTooltip(
                            date: item.createdAt,
                            child: Text(
                              item.createdAt.fuzzify(
                                locale: Localizations.localeOf(context),
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class SearchHistoryQueryWidget extends StatelessWidget {
  const SearchHistoryQueryWidget({
    required this.history,
    super.key,
    this.reverseScheme,
  });

  final SearchHistory history;
  final bool? reverseScheme;

  @override
  Widget build(BuildContext context) => switch (history.queryType) {
    QueryType.list => Wrap(
      spacing: 4,
      runSpacing: 4,
      children: history
          .queryAsList()
          .map(
            (e) => IgnorePointer(
              child: KurumiCompactChip(
                label: e,
                borderRadius: BorderRadius.circular(8),
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                backgroundColor: (reverseScheme ?? false)
                    ? Kurumi.themeOf(context).colorScheme.surface
                    : Kurumi.themeOf(context)
                          .colorScheme
                          .surfaceContainerHighest,
              ),
            ),
          )
          .toList(),
    ),
    _ => Text(history.query),
  };
}
