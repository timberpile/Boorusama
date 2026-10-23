import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

class BookmarkOverviewFilter extends StatelessWidget {
  const BookmarkOverviewFilter({required this.controller, super.key});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    child: ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        key: const Key('bookmark-group-name-filter'),
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
        decoration: InputDecoration(
          labelText: context.t.generic.action.search,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: context.t.generic.action.clear,
                  onPressed: controller.clear,
                  icon: const Icon(Icons.clear),
                ),
        ),
      ),
    ),
  );
}

class BookmarkOverviewNoMatches extends StatelessWidget {
  const BookmarkOverviewNoMatches({required this.onClear, super.key});
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off),
          const SizedBox(height: 8),
          Text(context.t.generic.no_content, textAlign: TextAlign.center),
          TextButton(
            onPressed: onClear,
            child: Text(context.t.generic.action.clear),
          ),
        ],
      ),
    ),
  );
}
