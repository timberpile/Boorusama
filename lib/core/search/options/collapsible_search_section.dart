import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Keeps section actions reachable even when its body is collapsed. PageStorage
/// retains the choice while navigating in the current search route.
class CollapsibleSearchSection extends StatefulWidget {
  const CollapsibleSearchSection({
    required this.title,
    required this.storageId,
    required this.child,
    this.trailing,
    this.initiallyExpanded = true,
    super.key,
  });

  final String title;
  final String storageId;
  final Widget child;
  final Widget? trailing;
  final bool initiallyExpanded;

  @override
  State<CollapsibleSearchSection> createState() =>
      _CollapsibleSearchSectionState();
}

class _CollapsibleSearchSectionState extends State<CollapsibleSearchSection> {
  late bool _expanded = widget.initiallyExpanded;
  String? _loadedId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restore();
  }

  @override
  void didUpdateWidget(CollapsibleSearchSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _restore();
  }

  void _restore() {
    if (_loadedId == widget.storageId) return;
    _loadedId = widget.storageId;
    final stored = PageStorage.maybeOf(context)?.readState(
      context,
      identifier: widget.storageId,
    );
    _expanded = stored is bool ? stored : widget.initiallyExpanded;
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    PageStorage.maybeOf(context)?.writeState(
      context,
      _expanded,
      identifier: widget.storageId,
    );
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  expanded: _expanded,
                  child: InkWell(
                    onTap: _toggle,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 4,
                      ),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.title,
                              style: Kurumi.themeOf(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            _expanded
                                ? Symbols.expand_less
                                : Symbols.expand_more,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.trailing != null)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth / 2,
                  ),
                  child: IntrinsicWidth(child: widget.trailing),
                ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.topCenter,
          child: _expanded ? widget.child : const SizedBox.shrink(),
        ),
      ],
    ),
  );
}
