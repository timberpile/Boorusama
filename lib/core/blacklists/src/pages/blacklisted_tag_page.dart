// Package imports:
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../providers/global_blacklisted_tag_notifier.dart';
import '../providers/local_providers.dart';
import '../types/utils.dart';
import '../widgets/blacklisted_tag_view_scaffold.dart';
import 'blacklisted_tag_config_sheet.dart';

const kFavoriteTagsSelectedLabelKey = 'favorite_tags_selected_label';

class BlacklistedTagPage extends ConsumerWidget {
  const BlacklistedTagPage({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(globalBlacklistedTagsProvider)
        .when(
          data: (tags) {
            final sortType = ref.watch(selectedBlacklistedTagsSortTypeProvider);
            final sortedTags = sortBlacklistedTags(tags, sortType);

            return BlacklistedTagsViewScaffold(
              title: context.t.blacklist.manage.title,
              limitation: const DefaultBlacklistTagsLimitation(
                storageKey: 'blacklisted_tag_limitation_banner',
              ),
              actions: [
                IconButton(
                  onPressed: () {
                    Kurumi.showModalBottomSheet(
                      context: context,
                      routeSettings: const RouteSettings(
                        name: 'blacklisted_tag_sort',
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      builder: (context) => BlacklistedTagConfigSheet(
                        onSorted: (value) {
                          ref
                                  .read(
                                    selectedBlacklistedTagsSortTypeProvider
                                        .notifier,
                                  )
                                  .state =
                              value;
                        },
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.sort,
                    fill: 1,
                    size: 20,
                  ),
                ),
              ],
              tags: sortedTags.map((e) => e.name).toList(),
              onAddTag: (tag) {
                ref
                    .read(globalBlacklistedTagsProvider.notifier)
                    .addTagWithToast(context, tag);
              },
              onEditTap: (oldTag, newTag) {
                final oldBlacklistedTag = sortedTags.firstWhereOrNull(
                  (e) => e.name == oldTag,
                );

                if (oldBlacklistedTag == null) {
                  Kurumi.showErrorToast(context, 'Cannot find tag $oldTag');
                  return;
                }

                ref
                    .read(globalBlacklistedTagsProvider.notifier)
                    .updateTag(
                      oldTag: oldBlacklistedTag,
                      newTag: newTag,
                    );
              },
              onRemoveTag: (tag) {
                final blacklistedTag = sortedTags.firstWhereOrNull(
                  (e) => e.name == tag,
                );

                if (blacklistedTag == null) {
                  Kurumi.showErrorToast(context, 'Cannot find tag $tag');
                  return;
                }

                ref
                    .read(globalBlacklistedTagsProvider.notifier)
                    .removeTag(blacklistedTag);
              },
            );
          },
          error: (error, stackTrace) {
            return Scaffold(
              appBar: KurumiAppBar(
                title: Text(context.t.blacklist.manage.title),
              ),
              body: Center(
                child: Text(
                  error.toString(),
                  style: Kurumi.themeOf(context).textTheme.bodyLarge,
                ),
              ),
            );
          },
          loading: () {
            return const Scaffold(
              appBar: KurumiAppBar(),
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          },
        );
  }
}
