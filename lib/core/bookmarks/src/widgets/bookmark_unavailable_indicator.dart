import 'dart:math' as math;

import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../posts/details/src/types/post_presentation_fallback_reason.dart';

class BookmarkUnavailableIndicator extends StatefulWidget {
  const BookmarkUnavailableIndicator({
    required this.counts,
    this.reasons = const {},
    this.onRetry,
    super.key,
  });

  final Map<String, int> counts;
  final Map<PostPresentationFallbackReason, int> reasons;
  final VoidCallback? onRetry;

  @override
  State<BookmarkUnavailableIndicator> createState() =>
      _BookmarkUnavailableIndicatorState();
}

class _BookmarkUnavailableIndicatorState
    extends State<BookmarkUnavailableIndicator> {
  final _anchor = AnchorController();

  int get _totalCount => widget.counts.values.fold(
    0,
    (total, count) => total + math.max(0, count),
  );

  @override
  void didUpdateWidget(covariant BookmarkUnavailableIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_countTotal(oldWidget.counts) > 0 && _totalCount == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _totalCount == 0) _anchor.hide();
      });
    }
  }

  @override
  void dispose() {
    _anchor.dispose();
    super.dispose();
  }

  List<(String, int)> _countGroups(BuildContext context) {
    final counts = widget.reasons;
    final accountCount = _positive(
      counts[PostPresentationFallbackReason.missingProfile],
    );
    final ambiguousCount = _positive(
      counts[PostPresentationFallbackReason.ambiguousProfile],
    );
    final readerCount =
        _positive(
          counts[PostPresentationFallbackReason.unavailableEngine],
        ) +
        _positive(counts[PostPresentationFallbackReason.malformedData]) +
        _positive(counts[PostPresentationFallbackReason.unsupportedVersion]) +
        _positive(
          counts[PostPresentationFallbackReason.incompatiblePresentation],
        ) +
        _positive(counts[PostPresentationFallbackReason.removedUpstreamPost]);
    final temporaryCount = _positive(
      counts[PostPresentationFallbackReason.refreshFailed],
    );

    return [
      if (accountCount > 0)
        (context.t.bookmark.unavailable_account, accountCount),
      if (ambiguousCount > 0)
        (context.t.bookmark.unavailable_ambiguous, ambiguousCount),
      if (readerCount > 0) (context.t.bookmark.unavailable_reader, readerCount),
      if (temporaryCount > 0)
        (context.t.bookmark.unavailable_temporary, temporaryCount),
    ];
  }

  Widget _popup(BuildContext context) {
    final media = MediaQuery.of(context);
    final availableHeight = math.max(
      0,
      media.size.height - media.padding.vertical - media.viewInsets.bottom - 24,
    );
    final width = math.max(0, math.min(380, media.size.width - 24)).toDouble();
    final groups =
        widget.counts.entries.where((entry) => entry.value > 0).toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    final reasons = _countGroups(context);
    final titleStyle = Theme.of(context).textTheme.titleMedium;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: width,
        maxHeight: availableHeight * .6,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    context.t.bookmark.unavailable_title,
                    style: titleStyle,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$_totalCount',
                  key: const ValueKey('bookmark-unavailable-total'),
                  style: titleStyle,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.reasons.isEmpty)
              Text(context.t.bookmark.unavailable_account),
            for (final (label, count) in reasons)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: reasons.length == 1
                    ? Text(label)
                    : Row(
                        children: [
                          Expanded(child: Text(label)),
                          const SizedBox(width: 12),
                          Text('$count'),
                        ],
                      ),
              ),
            const SizedBox(height: 8),
            for (final MapEntry(key: site, value: count) in groups)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        site.isEmpty
                            ? context.t.bookmark.unavailable_unknown_site
                            : site,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('$count'),
                  ],
                ),
              ),
            if ((widget.reasons[PostPresentationFallbackReason.refreshFailed] ??
                        0) >
                    0 &&
                widget.onRetry != null)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () {
                    _anchor.hide();
                    widget.onRetry?.call();
                  },
                  child: Text(context.t.generic.action.retry),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalCount;
    if (total == 0) return const SizedBox.shrink();

    final label = context.t.bookmark.unavailable_count(n: total);
    return KurumiAnchor(
      controller: _anchor,
      viewPadding: const EdgeInsets.all(12),
      overlayBuilder: _popup,
      child: Tooltip(
        message: label,
        child: Semantics(
          label: label,
          excludeSemantics: true,
          button: true,
          onTap: _anchor.toggle,
          child: TextButton.icon(
            key: const ValueKey('bookmark-unavailable-button'),
            onPressed: _anchor.toggle,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            icon: const Icon(Symbols.cloud_off, size: 20),
            label: Text('$total'),
          ),
        ),
      ),
    );
  }
}

int _countTotal(Map<String, int> counts) =>
    counts.values.fold(0, (total, count) => total + math.max(0, count));

int _positive(int? count) => math.max(0, count ?? 0);
