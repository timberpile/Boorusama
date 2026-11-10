import 'dart:math' as math;

import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class BookmarkUnavailableIndicator extends StatefulWidget {
  const BookmarkUnavailableIndicator({
    required this.counts,
    super.key,
  });

  final Map<String, int> counts;

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
            Text(
              context.t.bookmark.unavailable_title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(context.t.bookmark.unavailable_account),
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
