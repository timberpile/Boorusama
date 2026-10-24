import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../../configs/config/types.dart';
import '../../../../tags/categories/providers.dart';
import '../../../../tags/tag/providers.dart';
import '../../../../themes/colors/providers.dart';
import '../providers/topic_query_tag_categories_provider.dart';
import '../types/topic_query_display.dart';

/// Passive tag chips; opening and editing remain actions of the containing card.
class FollowingTopicQueryText extends StatelessWidget {
  const FollowingTopicQueryText({
    required this.query,
    this.auth,
    this.style,
    this.maxLines = 2,
    super.key,
  });

  final String query;
  final BooruConfigAuth? auth;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final tokens = topicQueryDisplayTokens(query);
    final profile = auth;
    if (profile == null) {
      return _chips(context, tokens, const {});
    }
    return Consumer(
      builder: (context, ref, _) {
        final resolved = ref
            .watch(topicQueryTagCategoriesProvider((profile, query)))
            .valueOrNull;
        final colors = <String, KurumiChipColors?>{};
        for (final tag
            in tokens
                .map((token) => token.tagName)
                .whereType<String>()
                .toSet()) {
          final category =
              resolved?[tag] ??
              ref.watch(booruTagTypeProvider((profile, tag))).valueOrNull;
          if (category == null || category == 'unknown') {
            continue;
          }
          final color = ref.watch(tagColorProvider((profile, category)));
          if (color != null) {
            colors[tag] = ref.watch(booruChipColorsProvider).fromColor(color);
          }
        }
        return _chips(context, tokens, colors);
      },
    );
  }

  Widget _chips(
    BuildContext context,
    List<TopicQueryDisplayToken> tokens,
    Map<String, KurumiChipColors?> colors,
  ) {
    final textStyle = DefaultTextStyle.of(context).style.merge(style);
    final scaledStyle = textStyle.copyWith(
      fontSize: MediaQuery.textScalerOf(context)
          .scale(textStyle.fontSize ?? 14),
    );
    return Semantics(
      label: tokens.map((t) => '${t.operator}${t.displayBody}').join(),
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) => Text.rich(
            TextSpan(
              children: [
                for (final token in tokens)
                  if (token.raw.trim().isEmpty)
                    TextSpan(text: token.raw)
                  else
                    WidgetSpan(
                      alignment: PlaceholderAlignment.top,
                      child: IgnorePointer(
                        child: _chip(
                          context,
                          token,
                          colors[token.tagName],
                          constraints.hasBoundedWidth
                              ? constraints.maxWidth
                              : MediaQuery.widthOf(context),
                        ),
                      ),
                    ),
              ],
            ),
            // Inline chips scale their own text; do not scale the widget again.
            textScaler: TextScaler.noScaling,
            style: scaledStyle,
            strutStyle: StrutStyle.fromTextStyle(
              scaledStyle,
              forceStrutHeight: true,
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    TopicQueryDisplayToken token,
    KurumiChipColors? colors,
    double maxWidth,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return KurumiRawCompactChip(
      backgroundColor:
          colors?.backgroundColor ?? scheme.surfaceContainerHighest,
      foregroundColor: colors?.foregroundColor ?? scheme.onSurface,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors?.borderColor ?? scheme.outlineVariant),
      ),
      label: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: math.max(0, maxWidth - 8)),
        child: Text.rich(
          TextSpan(text: '${token.operator}${token.displayBody}'),
          style: DefaultTextStyle.of(context).style
              .merge(style)
              .copyWith(
                color: colors?.foregroundColor ?? scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
