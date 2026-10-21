import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../groups/folder_tree.dart';
import '../types/bookmark_group.dart';
import '../types/bookmark_library_state.dart';
import 'target_settings.dart';

String serverFavoriteProblemText(
  BuildContext context,
  ServerFavoriteProblem problem,
) {
  final t = context.t.bookmark.server_favorites;
  return switch (problem) {
    ServerFavoriteProblem.unsupported => t.unsupported,
    ServerFavoriteProblem.signedOut => t.signedOut,
    ServerFavoriteProblem.ambiguousAccount => t.ambiguousAccount,
    ServerFavoriteProblem.noTarget => t.noTarget,
    ServerFavoriteProblem.targetMissing => t.targetMissing,
    ServerFavoriteProblem.confirmationRequired => t.confirmationRequired,
    ServerFavoriteProblem.targetChanged => t.targetChanged,
    ServerFavoriteProblem.accountChanged => t.accountChanged,
    ServerFavoriteProblem.missingPostIdentity => t.missingPostIdentity,
    ServerFavoriteProblem.paginationStalled => t.paginationStalled,
    ServerFavoriteProblem.remoteFailure => t.remoteFailure,
    ServerFavoriteProblem.localFailure => t.localFailure,
    ServerFavoriteProblem.timedOut => t.timedOut,
  };
}

String serverFavoriteGroupLabel(
  BookmarkLibraryState library,
  BookmarkGroup group,
) {
  final path = FolderTree(library.folders).path(group.folderId);
  return path.isEmpty ? group.name : '$path / ${group.name}';
}
