import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../providers/bookmark_picker_actions.dart';
import '../types/bookmark_picker_request.dart';
import 'bookmark_group_name_dialog.dart';

/// Creation owns metadata and cancellation after the originating picker closes.
class BookmarkPickerGroupCreation extends ConsumerStatefulWidget {
  const BookmarkPickerGroupCreation({
    required this.request,
    this.parentGroupId,
    super.key,
  });
  final BookmarkPickerRequest request;
  final String? parentGroupId;
  @override
  ConsumerState<BookmarkPickerGroupCreation> createState() =>
      _BookmarkPickerGroupCreationState();
}

class _BookmarkPickerGroupCreationState
    extends ConsumerState<BookmarkPickerGroupCreation> {
  var _committing = false;
  late final BookmarkPickerActions _actions;
  @override
  void initState() {
    super.initState();
    _actions = BookmarkPickerActions(
      container: ProviderScope.containerOf(context, listen: false),
      request: widget.request,
      isActive: () => mounted && (ModalRoute.of(context)?.isCurrent ?? false),
    );
  }

  @override
  void dispose() {
    _actions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    watchBookmarkPickerDraft(ref, widget.request);
    return BookmarkGroupNameDialog(
      title: context.t.bookmark.groups.create,
      canDismiss: !_committing,
      onSave: (name) async {
        try {
          await _actions.createGroup(
            name,
            widget.parentGroupId,
            beforeCommit: () => setState(() => _committing = true),
          );
        } finally {
          if (mounted) setState(() => _committing = false);
        }
      },
    );
  }
}
