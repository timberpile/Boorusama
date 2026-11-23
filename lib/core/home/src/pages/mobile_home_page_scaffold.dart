// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../foundation/display.dart';
import '../../../announcements/widgets.dart';
import '../../../configs/config/providers.dart';
import '../../../posts/count/widgets.dart';
import '../../../posts/listing/widgets.dart';
import '../../../posts/listing/src/widgets/post_grid_controller.dart';
import '../../../posts/post/providers.dart';
import '../../../search/search/types.dart';
import '../../../search/selected_tags/providers.dart';
import '../../../settings/providers.dart';
import '../../../tags/metatag/providers.dart';
import '../widgets/home_search_bar.dart';

class MobileHomePageScaffold extends ConsumerStatefulWidget {
  const MobileHomePageScaffold({
    super.key,
    this.nativeResultBuilder,
  });
  final Widget Function(BuildContext, String, List<Widget>)?
  nativeResultBuilder;

  @override
  ConsumerState<MobileHomePageScaffold> createState() =>
      _MobileHomePageScaffoldState();
}

class _MobileHomePageScaffoldState
    extends ConsumerState<MobileHomePageScaffold> {
  final selectedTagString = ValueNotifier('');
  var _queryRevision = 0;
  late final SelectedTagController selectedTagController;

  @override
  void initState() {
    super.initState();

    selectedTagController = SelectedTagController(
      metatagExtractor: ref.read(metatagExtractorProvider(ref.readConfigAuth)),
    );
  }

  @override
  void dispose() {
    super.dispose();
    selectedTagString.dispose();
    selectedTagController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchBarPosition = ref.watch(searchBarPositionProvider);

    Widget body({PostGridController? controller}) {
      void refresh() {
        if (controller != null) {
          controller.refresh();
        } else {
          setState(() => _queryRevision++);
        }
      }

      final headers = <Widget>[
        if (context.isLargeScreen || searchBarPosition == SearchBarPosition.top)
          SliverHomeSearchBar(
            selectedTagController: selectedTagController,
            selectedTagString: selectedTagString,
            onSearch: refresh,
          ),
        const SliverAppAnnouncementBanner(),
        if (context.isLargeScreen && controller != null)
          SliverResultHeader(
            selectedTagString: selectedTagString,
            controller: controller,
          ),
      ];
      return Column(
        children: [
          Expanded(
            child: controller == null
                ? KeyedSubtree(
                    key: ValueKey(_queryRevision),
                    child: widget.nativeResultBuilder!(
                      context,
                      selectedTagString.value,
                      headers,
                    ),
                  )
                : PostGrid(controller: controller, sliverHeaders: headers),
          ),
          if (searchBarPosition == SearchBarPosition.bottom &&
              !context.isLargeScreen)
            Consumer(
              builder: (_, ref, _) {
                final position = ref.watch(
                  settingsProvider.select(
                    (value) => value.booruConfigSelectorPosition,
                  ),
                );

                return SafeArea(
                  top: false,
                  bottom: !position.isBottom,
                  child: SizedBox(
                    height: kToolbarHeight,
                    child: CustomScrollView(
                      slivers: [
                        SliverHomeSearchBar(
                          primary: false,
                          selectedTagController: selectedTagController,
                          selectedTagString: selectedTagString,
                          onSearch: refresh,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      );
    }

    if (widget.nativeResultBuilder != null) return body();
    final postRepo = ref.watch(originAwarePostRepoProvider(ref.watchConfig));
    return PostScope(
      fetcher: (page) =>
          postRepo.getPostsFromController(selectedTagController.tagSet, page),
      builder: (context, controller) => body(controller: controller),
    );
  }
}
