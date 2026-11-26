import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../configs/config/types.dart';
import '../../../content/content_access_provider.dart';
import '../../../content/groups/group_capability.dart';
import '../../../navigation/destination_activity.dart';
import '../../../widgets/multi_select_button.dart';
import '../../providers.dart';
import '../types/content_group_bookmark.dart';
import 'bookmark_group_picker.dart';
import 'bookmark_multi_selection.dart';

class SelectedContentGroupsBookmarkButton extends ConsumerWidget {
  const SelectedContentGroupsBookmarkButton({
    required this.groups,
    required this.supports,
    required this.request,
    super.key,
  });
  final List<GroupBookmarkPresentationData> groups;
  final bool Function(GroupBookmarkPresentationData) supports;
  final ContentGroupBookmarkPickerRequest Function(
    ProviderContainer,
    GroupBookmarkPresentationData,
  )
  request;

  bool _valid(
    ProviderContainer container,
    List<GroupBookmarkPresentationData> groups,
  ) {
    if (groups.isEmpty) return false;
    final checkedAccess = Set<Object>.identity();
    for (final data in groups) {
      if (!supports(data) || !data.access.accepts(data.summary.reference)) {
        return false;
      }
      if (checkedAccess.add(data.access)) {
        final current = container.read(
          contentAccessContextProvider(data.access.key),
        );
        if (current == null || !data.access.hasSameAuthorization(current)) {
          return false;
        }
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    for (final key in groups.map((data) => data.access.key).toSet()) {
      ref.watch(contentAccessContextProvider(key));
    }
    final container = ProviderScope.containerOf(context, listen: false);
    return MultiSelectButton(
      icon: const Icon(Symbols.bookmark),
      name: context.t.post.action.bookmark,
      onPressed: !_valid(container, groups)
          ? null
          : () async {
              final captured = List<GroupBookmarkPresentationData>.unmodifiable(
                groups,
              );
              if (!NavigationActivity.of(context)) return;
              void validate() {
                if (!context.mounted || !_valid(container, captured)) {
                  throw StateError('Selected group access changed');
                }
              }

              try {
                validate();
                if (captured.length == 1) {
                  await showBookmarkPickerDialog(
                    context,
                    request: request(container, captured.single),
                  );
                  return;
                }
                final drafts = List<ContentGroupBookmark>.unmodifiable([
                  for (final data in captured) request(container, data).draft,
                ]);
                final target = await showBookmarkGroupSelectionDialog(
                  context,
                  operation: BookmarkMultiSelectionOperation.add,
                  posts: const [],
                  config: captured.first.access.config!.auth,
                  contentDrafts: drafts,
                  beforeCommit: validate,
                );
                if (target == null || target.appliedCount != null) return;
                validate();
                await container
                    .read(bookmarkProvider.notifier)
                    .addContentGroupDraftsToGroup(
                      drafts,
                      target.id!,
                      beforeCommit: validate,
                    );
              } catch (_) {
                if (context.mounted) {
                  Kurumi.showErrorToast(
                    context,
                    context.t.bookmark.groups.operation_failed,
                  );
                }
              }
            },
    );
  }
}
