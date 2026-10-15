// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../bulk_downloads/routes.dart';
import '../../../../configs/config/types.dart';
import '../../../../configs/create/routes.dart';
import '../../../../settings/providers.dart';
import '../../../../tags/metatag/providers.dart';
import '../../../queries/providers.dart';
import '../../../selected_tags/providers.dart';
import '../types/search_bar_position.dart';
import 'selected_tag_list.dart';
import 'search_controller.dart';
import 'search_profile_menu.dart';
import 'search_profile_session.dart';

class SelectedTagListWithData extends ConsumerWidget {
  const SelectedTagListWithData({
    required this.controller,
    required this.config,
    super.key,
    this.flexibleBorderPosition = true,
  });

  final SelectedTagController controller;
  final bool flexibleBorderPosition;
  final BooruConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagComposer = ref.watch(tagQueryComposerProvider(config.search));
    final colorScheme = Kurumi.themeOf(context).colorScheme;
    final searchBarPosition = ref.watch(searchBarPositionProvider);
    final metatagExtractor = ref.watch(metatagExtractorProvider(config.auth));

    final borderSide = BorderSide(
      color: colorScheme.outlineVariant,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: flexibleBorderPosition
            ? Border(
                bottom: searchBarPosition == SearchBarPosition.top
                    ? borderSide
                    : BorderSide.none,
                top: searchBarPosition == SearchBarPosition.bottom
                    ? borderSide
                    : BorderSide.none,
              )
            : Border(
                bottom: borderSide,
              ),
      ),
      child: ValueListenableBuilder(
        valueListenable: controller,
        builder: (context, tags, child) {
          return tags.isNotEmpty
              ? SelectedTagList(
                  profileMenu: SearchProfileSession.maybeOf(context) == null
                      ? null
                      : SearchProfileMenu(
                          onSelected: (profile) =>
                              SearchProfileSession.maybeOf(context)!.onSwitch(
                                profile,
                                InheritedSearchPageController.of(context),
                              ),
                        ),
                  extraTagsCount: tagComposer.compose([]).length,
                  onOtherTagsCountTap: () {
                    goToUpdateBooruConfigPage(
                      ref,
                      config: config,
                      initialTab: 'search',
                    );
                  },
                  tags: tags,
                  onClear: () {
                    controller.clear();
                  },
                  onDelete: (tag) {
                    controller.removeTag(tag);
                  },
                  onUpdate: (oldTag, newTag) {
                    controller.updateTag(
                      oldTag,
                      oldTag.withQuery(
                        newTag,
                        extractor: metatagExtractor,
                      ),
                    );
                  },
                  onBulkDownload: (tags) => goToBulkDownloadPage(
                    context,
                    tags.map((e) => e.toString()).toList(),
                    ref: ref,
                  ),
                )
              : const SizedBox.shrink();
        },
      ),
    );
  }
}
