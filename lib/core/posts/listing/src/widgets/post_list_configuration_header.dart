import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class PostListConfigurationHeader extends StatefulWidget {
  const PostListConfigurationHeader({
    required this.hiddenCount,
    required this.postCount,
    required this.blacklistControls,
    super.key,
    this.trailing,
    this.hasBlacklist = false,
    this.initiallyExpanded = false,
    this.axis = Axis.horizontal,
    this.onExpansionChanged,
    this.blacklistChanges,
  });

  final Widget? trailing;
  final int? hiddenCount;
  final bool hasBlacklist;
  final bool initiallyExpanded;
  final Axis axis;
  final int postCount;
  final ValueChanged<bool>? onExpansionChanged;
  final Widget blacklistControls;
  final Listenable? blacklistChanges;

  @override
  State<PostListConfigurationHeader> createState() =>
      _PostListConfigurationHeaderState();
}

class _PostListConfigurationHeaderState
    extends State<PostListConfigurationHeader> {
  final _anchor = AnchorController();

  @override
  void didUpdateWidget(covariant PostListConfigurationHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hasBlacklist && !widget.hasBlacklist) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.hasBlacklist) _anchor.hide();
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
      0.0,
      media.size.height - media.padding.vertical - media.viewInsets.bottom - 24,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: math.max(0, math.min(380, media.size.width - 24)).toDouble(),
        maxHeight: availableHeight * .6,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.t.blacklisted_tags.blacklisted_header_title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            widget.blacklistControls,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The vertical blacklist panel remains an inline, expandable panel.
    if (widget.axis == Axis.vertical) {
      if (!widget.hasBlacklist) return const SizedBox.shrink();
      return ExpansionTile(
        initiallyExpanded: widget.initiallyExpanded,
        onExpansionChanged: widget.onExpansionChanged,
        title: Text(context.t.blacklisted_tags.blacklisted_header_title),
        children: [widget.blacklistControls],
      );
    }

    final container = ProviderScope.containerOf(context, listen: false);
    final hidden = widget.hiddenCount ?? 0;
    final hiddenLabel = '${context.t.blacklisted_tags.blacklisted_header_title}: '
        '${context.t.posts.hidden_count(hidden: hidden, total: widget.postCount)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                key: const ValueKey('timeline-toolbar-content'),
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.t.posts.counter(n: widget.postCount),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (widget.hasBlacklist) ...[
                      const SizedBox(width: 12),
                      KurumiAnchor(
                        controller: _anchor,
                        onShow: () => widget.onExpansionChanged?.call(true),
                        onHide: () => widget.onExpansionChanged?.call(false),
                        overlayBuilder: (_) => UncontrolledProviderScope(
                          container: container,
                          child: InheritedTheme.captureAll(
                            context,
                            widget.blacklistChanges != null
                                ? ListenableBuilder(
                                    listenable: widget.blacklistChanges!,
                                    builder: (context, _) => _popup(context),
                                  )
                                : Builder(builder: _popup),
                          ),
                        ),
                        child: Tooltip(
                          message: hiddenLabel,
                          child: Semantics(
                            label: hiddenLabel,
                            excludeSemantics: true,
                            button: true,
                            onTap: _anchor.toggle,
                            child: TextButton.icon(
                              key: const ValueKey('timeline-blacklist-button'),
                              onPressed: _anchor.toggle,
                              style: TextButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              icon: const Icon(Symbols.visibility_off, size: 20),
                              label: Text('$hidden'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (widget.trailing case final trailing?) ...[
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: trailing,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
