import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../types/search_organization.dart';
import 'search_folder_dialog.dart';

typedef FolderChoice = ({String? folderId, String? createName});

Future<FolderChoice?> showMovePinToFolderDialog(
  BuildContext context,
  List<SharedSearchFolder> folders,
) => showDialog<FolderChoice>(
  context: context,
  builder: (context) => SimpleDialog(
    title: Text(context.t.pinned_searches.move_to_folder),
    children: [
      SimpleDialogOption(
        onPressed: () =>
            Navigator.pop(context, (folderId: null, createName: null)),
        child: Text(context.t.pinned_searches.home),
      ),
      for (final folder in folders)
        SimpleDialogOption(
          onPressed: () =>
              Navigator.pop(context, (folderId: folder.id, createName: null)),
          child: Text(folder.name),
        ),
      SimpleDialogOption(
        onPressed: () async {
          final name = await showSearchFolderNameDialog(context);
          if (name == null || !context.mounted) return;
          Navigator.pop(context, (folderId: null, createName: name));
        },
        child: Text(context.t.pinned_searches.create_folder),
      ),
    ],
  ),
);
