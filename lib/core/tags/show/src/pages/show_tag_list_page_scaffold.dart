import '../../../../selection/ordered_selection_canvas.dart';
import '../../../tag/types.dart';
import '../../../../selection/ordered_selection_controller.dart';
import '../../../../selection/selection_input.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:selection_mode/selection_mode.dart';

// Project imports:
import '../../../../configs/config/types.dart';
import '../../../../posts/post/types.dart';
import '../../../../search/search/widgets.dart';
import '../../../../settings/providers.dart';
import '../../../../widgets/default_selection_bar.dart';
import '../../../../widgets/widgets.dart';
import '../providers.dart';

class ShowTagListPageScaffold extends ConsumerStatefulWidget {
  const ShowTagListPageScaffold({
    required this.post,
    required this.auth,
    required this.initiallyMultiSelectEnabled,
    required this.scrollController,
    required this.list,
    required this.actionBar,
    super.key,
  });

  final Post post;
  final ScrollController scrollController;
  final BooruConfigAuth auth;
  final bool initiallyMultiSelectEnabled;
  final Widget list;
  final Widget actionBar;

  @override
  ConsumerState<ShowTagListPageScaffold> createState() =>
      _ShowTagListPageScaffoldState();
}

class _ShowTagListPageScaffoldState
    extends ConsumerState<ShowTagListPageScaffold> {
  late final SelectionModeController _selectionModeController;

  @override
  void initState() {
    super.initState();

    _selectionModeController = OrderedSelectionController<String>(
      initialEnabled: widget.initiallyMultiSelectEnabled,
    );
  }

  @override
  void dispose() {
    _selectionModeController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final params = (widget.auth, widget.post);
    final tags = ref.watch(showTagsProvider(params)).valueOrNull;
    final query = ref.watch(selectedViewTagQueryProvider);
    final visible = tags?.where((tag) => tag.rawName.contains(query)).toList();
    if (visible != null) {
      (_selectionModeController as OrderedSelectionController<String>)
          .reconcileDuringBuild(
            [for (final tag in visible) tag.rawName],
            scope: (widget.auth, widget.post, query),
          );
    }

    return CustomContextMenuOverlay(
      child: SelectionMode(
        scrollController: widget.scrollController,
        controller: _selectionModeController,
        options: ref.watch(selectionOptionsProvider),
        child: SelectionInput(
          controller: _selectionModeController,
          itemCount: visible?.length ?? 0,
          child: KurumiContextMenuPolicy(
            touchLongPress: !_selectionModeController.isActive,
            child: Scaffold(
              appBar: DefaultSelectionAppBar(
                itemsCount: visible?.length,
                appBar: KurumiAppBar(
                  title: Text(context.t.tags.title),
                  centerTitle: false,
                  actions: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: KurumiPopupMenuButton(
                        items: [
                          KurumiPopupMenuItem(
                            title: Text(context.t.generic.action.select),
                            icon: const Icon(Icons.checklist),
                            onTap: () {
                              _selectionModeController.enable();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              body: Stack(
                children: [
                  Column(
                    children: [
                      _buildSearchBar(),
                      const SizedBox(height: 4),
                      Expanded(
                        child: OrderedSelectionCanvas(
                          controller: _selectionModeController,
                          child: widget.list,
                        ),
                      ),
                    ],
                  ),
                  ListenableBuilder(
                    listenable: _selectionModeController,
                    builder: (context, _) => Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: widget.actionBar,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      child: BooruSearchBar(
        dense: true,
        hintText: context.t.tags.filter_hint,
        onChanged: (value) {
          _selectionModeController.disable();
          ref.read(selectedViewTagQueryProvider.notifier).state = value;
        },
      ),
    );
  }
}
