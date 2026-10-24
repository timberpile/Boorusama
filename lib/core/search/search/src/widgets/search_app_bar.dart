// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../types/constants.dart';
import 'search_context_profile_picker.dart';
import 'search_profile_session.dart';
import '../../../../navigation/navigation_profile_picker.dart';
import '../../../../navigation/destination_profile_scope.dart';
import '../../../../navigation/destination_id.dart';
import 'booru_search_bar.dart';

class SearchAppBar extends ConsumerWidget {
  const SearchAppBar({
    required this.controller,
    required this.leading,
    super.key,
    this.onSubmitted,
    this.submitEmpty = false,
    this.focusNode,
    this.onClear,
    this.onChanged,
    this.trailingSearchButton,
    this.autofocus,
    this.dense,
    this.height,
    this.onTapOutside,
    this.innerSearchButton,
    this.searchBarBuilder,
    this.suggestionsFocus,
    this.listbox,
    this.onTap,
    this.onEscape,
    this.keepInnerActionWhileEditing = false,
    this.showClearButton = true,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final Widget? leading;
  final void Function(String value)? onSubmitted;
  final bool submitEmpty;
  final VoidCallback? onClear;
  final void Function(String value)? onChanged;
  final Widget? trailingSearchButton;
  final Widget? innerSearchButton;
  final bool? autofocus;
  final bool? dense;
  final double? height;
  final VoidCallback? onTapOutside;
  final Widget Function(BuildContext context, Widget child)? searchBarBuilder;
  final FocusScopeNode? suggestionsFocus;
  final KurumiListboxController? listbox;
  final VoidCallback? onTap;
  final VoidCallback? onEscape;
  final bool keepInnerActionWhileEditing;
  final bool showClearButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchBar = BooruSearchBar(
      dense: dense,
      autofocus: autofocus ?? false,
      onTap: onTap,
      onEscape: onEscape,
      onTapOutside: onTapOutside,
      focus: focusNode,
      suggestionsFocus: suggestionsFocus,
      listbox: listbox,
      controller: controller,
      leading: leading,
      trailing: ValueListenableBuilder(
        valueListenable: controller,
        builder: (context, value, child) {
          if (value.text.isEmpty || !showClearButton) {
            return innerSearchButton ?? const SizedBox.shrink();
          }
          final clearButton = IconButton(
            splashRadius: 16,
            icon: const Icon(Symbols.close),
            onPressed: () {
              controller.clear();
              onClear?.call();
            },
          );
          return keepInnerActionWhileEditing
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [?innerSearchButton, clearButton],
                )
              : clearButton;
        },
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      submitEmpty: submitEmpty,
    );

    return LayoutBuilder(
      builder: (context, constraints) => KurumiAppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: height ?? kToolbarHeight,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kSearchAppBarWidth),
                child: switch (searchBarBuilder) {
                  null => searchBar,
                  final builder => builder(context, searchBar),
                },
              ),
            ),
            if (SearchProfileSession.maybeOf(context)?.local ?? false)
              const SearchContextProfilePicker()
            else if (DestinationScope.maybeOf(context)?.id.kind ==
                DestinationKind.browse)
              const NavigationProfilePicker(favorites: false),
            if (trailingSearchButton != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: trailingSearchButton,
              ),
          ],
        ),
      ),
    );
  }
}

class SearchAppBarBackButton extends StatelessWidget {
  const SearchAppBarBackButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    splashRadius: 16,
    icon: const Icon(Symbols.arrow_back),
    onPressed: () => Navigator.of(context).pop(),
  );
}
