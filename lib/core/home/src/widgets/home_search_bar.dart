// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:sliver_tools/sliver_tools.dart';

// Project imports:
import '../../../../foundation/app_update/widgets.dart';
import '../../../configs/config/providers.dart';
import '../../../configs/config/types.dart';
import '../../../posts/listing/src/widgets/measured_floating_header.dart';
import '../../../posts/listing/src/widgets/timeline_header_sliver.dart';
import '../../../posts/listing/src/widgets/timeline_toolbar_host.dart';
import '../../../search/histories/providers.dart';
import '../../../search/search/types.dart';
import '../../../search/search/routes.dart';
import '../../../search/search/widgets.dart';
import '../../../search/selected_tags/providers.dart';
import '../../../settings/providers.dart';
import '../../../tags/metatag/providers.dart';
import '../../../navigation/navigation_profile_picker.dart';

class HomeSearchBar extends ConsumerWidget {
  const HomeSearchBar({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BooruSearchBar(
      enabled: false,
      trailing: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppUpdateButton(),
          NavigationProfilePicker(favorites: false),
        ],
      ),
      onTap: () => goToSearchPage(ref, fromSearchBar: true),
    );
  }
}

class SliverHomeSearchBar extends ConsumerWidget {
  const SliverHomeSearchBar({
    required this.onSearch,
    super.key,
    this.selectedTagString,
    this.selectedTagController,
    this.primary,
  });

  final ValueNotifier<String>? selectedTagString;
  final void Function() onSearch;
  final SelectedTagController? selectedTagController;
  final bool? primary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfigAuth;

    return SliverHomeSearchBarInternal(
      selectedTagString: selectedTagString,
      onSearch: onSearch,
      selectedTagController: selectedTagController,
      config: config,
      primary: primary,
    );
  }
}

class SliverHomeSearchBarInternal extends ConsumerStatefulWidget {
  const SliverHomeSearchBarInternal({
    required this.onSearch,
    required this.config,
    super.key,
    this.selectedTagString,
    this.selectedTagController,
    this.primary,
  });

  final ValueNotifier<String>? selectedTagString;
  final void Function() onSearch;
  final SelectedTagController? selectedTagController;
  final BooruConfigAuth config;
  final bool? primary;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _SliverHomeSearchBarState();
}

class _SliverHomeSearchBarState
    extends ConsumerState<SliverHomeSearchBarInternal> {
  late final SelectedTagController selectedTagController;

  late final selectedTagString = widget.selectedTagString ?? ValueNotifier('');

  @override
  void initState() {
    super.initState();

    selectedTagController =
        widget.selectedTagController ??
        SelectedTagController(
          metatagExtractor: ref.read(metatagExtractorProvider(widget.config)),
        );
  }

  @override
  void dispose() {
    if (widget.selectedTagController == null) {
      selectedTagController.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Kurumi.themeOf(context).colorScheme;
    final persistentSearchBar = ref.watch(
      settingsProvider.select(
        (value) => value.searchBarScrollBehavior.persistSearchBar,
      ),
    );

    // Desktop variant
    if (context.isLargeScreen) {
      final child = ColoredBox(
        color: colorScheme.surface,
        child: DesktopSearchbar(
          key: ValueKey(widget.config),
          onSearch: _onSearch,
          selectedTagController: selectedTagController,
        ),
      );

      return MediaQuery.heightOf(context) >= 550
          ? SliverPinnedHeader(child: child)
          : SliverToBoxAdapter(child: child);
    }

    // Mobile variant
    return KurumiSliverAppBar(
      primary: widget.primary ?? true,
      backgroundColor: colorScheme.surface,
      title: const HomeSearchBar(),
      floating: true,
      snap: true,
      pinned: persistentSearchBar,
      automaticallyImplyLeading: false,
    );
  }

  void _onSearch() {
    ref
        .read(searchHistoryProvider.notifier)
        .addHistoryFromController(selectedTagController, ref.readConfigAuth);
    selectedTagString.value = selectedTagController.rawTagsString;
    widget.onSearch();
  }
}

/// Supplies the leading Search sliver and, when both rows auto-hide, hosts
/// the Timeline Toolbar in that sliver. The grid retains its controller.
class BrowseTimelineHeader extends ConsumerStatefulWidget {
  const BrowseTimelineHeader({
    required this.searchBar,
    required this.builder,
    super.key,
  });

  final SliverHomeSearchBar searchBar;
  final Widget Function(BuildContext context, Widget? leadingSliver) builder;

  @override
  ConsumerState<BrowseTimelineHeader> createState() =>
      _BrowseTimelineHeaderState();
}

class _BrowseTimelineHeaderState extends ConsumerState<BrowseTimelineHeader> {
  final _toolbarHost = TimelineToolbarHost();

  @override
  void dispose() {
    _toolbarHost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final largeScreen = context.isLargeScreen;
    final searchAtTop =
        ref.watch(searchBarPositionProvider) == SearchBarPosition.top;
    final attachToolbar =
        !largeScreen &&
        searchAtTop &&
        !ref.watch(
          settingsProvider.select(
            (settings) => settings.searchBarScrollBehavior.persistSearchBar,
          ),
        ) &&
        !ref.watch(
          imageListingSettingsProvider.select(
            (settings) => settings.keepTimelineToolbarVisible,
          ),
        );
    final leadingSliver = attachToolbar
        ? _AttachedBrowseHeader(host: _toolbarHost)
        : largeScreen || searchAtTop
        ? widget.searchBar
        : null;
    return TimelineToolbarHostScope(
      host: attachToolbar ? _toolbarHost : null,
      child: widget.builder(context, leadingSliver),
    );
  }
}

/// Browse's two auto-hiding rows must share the same sliver geometry. An
/// independent floating Toolbar follows both the Search overlap and its own
/// scroll offset after a reverse drag deep in the results.
class _AttachedBrowseHeader extends ConsumerWidget {
  const _AttachedBrowseHeader({required this.host});

  final TimelineToolbarHost host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surface = Kurumi.themeOf(context).colorScheme.surface;
    return MeasuredFloatingHeader(
      reduceMotion: ref.watch(
        settingsProvider.select((settings) => settings.reduceAnimations),
      ),
      child: ColoredBox(
        color: surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: kToolbarHeight + MediaQuery.paddingOf(context).top,
              child: KurumiAppBar(
                toolbarHeight: kToolbarHeight,
                backgroundColor: surface,
                automaticallyImplyLeading: false,
                automaticallyImplyActions: false,
                title: const HomeSearchBar(),
              ),
            ),
            ListenableBuilder(
              listenable: host,
              builder: (context, _) => ColoredBox(
                color: TimelineHeaderSliver.backgroundColorOf(context),
                child: host.toolbar ?? const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
