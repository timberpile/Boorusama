// Dart imports:
import 'dart:math';

// Package imports:
import 'package:i18n/i18n.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../widgets/widgets.dart';
import '../types/search_bar_position.dart';
import 'raw_search_page_scaffold.dart';
import 'search_app_bar.dart';
import 'search_controller.dart';

class RawSearchRegion extends StatelessWidget {
  const RawSearchRegion({
    required this.innerSearchButton,
    required this.controller,
    required this.tagList,
    super.key,
    this.initialQuery,
    this.trailingSearchButton,
    this.autoFocusSearchBar,
    this.searchBarPosition = SearchBarPosition.top,
  });

  final Widget innerSearchButton;
  final String? initialQuery;
  final SearchPageController controller;
  final Widget tagList;
  final Widget? trailingSearchButton;
  final bool? autoFocusSearchBar;
  final SearchBarPosition searchBarPosition;

  @override
  Widget build(BuildContext context) {
    final theme = Kurumi.themeOf(context);
    final parentRoute = ModalRoute.of(context);
    final children = [
      SizedBox(
        height: kSearchBarHeight,
        child: MultiValueListenableBuilder2(
          first: controller.state,
          second: controller.didSearchOnce,
          builder: (_, state, searchOnce) => KurumiBackHandler(
            enabled:
                state != SearchState.initial &&
                TickerMode.valuesOf(context).enabled &&
                (parentRoute?.isCurrent ?? true),
            onBack: controller.closeEditor,
            child: SearchAppBar(
              onTap: controller.openEditor,
              onEscape: controller.closeEditor,
              keepInnerActionWhileEditing: true,
              showClearButton: false,
              onTapOutside: switch (searchBarPosition) {
                SearchBarPosition.top => null,
                SearchBarPosition.bottom =>
                  searchOnce && state == SearchState.initial ? null : () {},
              },
              onSubmitted: controller.submit,
              submitEmpty: true,
              trailingSearchButton: trailingSearchButton,
              innerSearchButton: TextFieldTapRegion(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    innerSearchButton,
                    IconButton(
                      tooltip: context.t.search_options.title,
                      isSelected: state == SearchState.options,
                      onPressed: controller.toggleOptions,
                      icon: Icon(
                        state == SearchState.options
                            ? Symbols.keyboard_arrow_up
                            : Symbols.keyboard_arrow_down,
                      ),
                    ),
                  ],
                ),
              ),
              focusNode: controller.focus,
              listbox: controller.suggestionsListbox,
              autofocus: initialQuery == null ? autoFocusSearchBar : false,
              controller: controller.textController,
              leading: (parentRoute?.impliesAppBarDismissal ?? false)
                  ? const SearchAppBarBackButton()
                  : null,
            ),
          ),
        ),
      ),
      tagList,
    ];
    final region = ColoredBox(
      color: theme.colorScheme.surface,
      child: Column(
        children: switch (searchBarPosition) {
          SearchBarPosition.top => children,
          SearchBarPosition.bottom => children.reversed.toList(),
        },
      ),
    );
    return searchBarPosition == SearchBarPosition.top
        ? region
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [region, const _SearchRegionBottomDisplacement()],
          );
  }
}

class _SearchRegionBottomDisplacement extends StatelessWidget {
  const _SearchRegionBottomDisplacement();

  @override
  Widget build(BuildContext context) => Container(
    color: Kurumi.themeOf(context).colorScheme.surface,
    height: max(
      MediaQuery.viewInsetsOf(context).bottom,
      MediaQuery.viewPaddingOf(context).bottom,
    ),
  );
}
