import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

/// A single row of compact choices that stays usable at enlarged text sizes.
class SearchOptionChoices extends StatefulWidget {
  const SearchOptionChoices({required this.children, super.key});

  final List<Widget> children;

  @override
  State<SearchOptionChoices> createState() => _SearchOptionChoicesState();
}

class _SearchOptionChoicesState extends State<SearchOptionChoices> {
  // Sibling rows share a PageStorage ancestor. A row must never restore a
  // different row's horizontal offset when the options list builds it lazily.
  final _scroll = ScrollController(keepScrollOffset: false);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Kurumi.themeOf(context);
    return Theme(
      data: Theme.of(context).copyWith(
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: ChipTheme(
        data: ChipTheme.of(context).copyWith(
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          selectedColor: theme.colorScheme.secondaryContainer,
          side: BorderSide(color: theme.colorScheme.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          labelStyle: theme.textTheme.labelMedium,
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        child: SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          primary: false,
          child: Row(
            children: [
              for (var i = 0; i < widget.children.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                widget.children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
