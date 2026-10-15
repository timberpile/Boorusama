import 'package:kurumi/material.dart';
import '../../../../groups/folder_navigation.dart';
import '../types/search_organization.dart';
import 'search_folder_dialog.dart';

typedef FolderChoice = ({
  String? folderId,
  String? createName,
  String? parentId,
});
Future<FolderChoice?> showMovePinToFolderDialog(
  BuildContext context,
  List<SharedSearchFolder> folders,
) async {
  String? createName;
  String? createParentId;
  final choice = await showFolderDestinationPicker(
    context,
    folders: folders,
    onCreate: (context, parentId) async {
      createParentId = parentId;
      createName = await showSearchFolderNameDialog(context);
      return createName == null ? null : '__new__';
    },
  );
  return choice == null
      ? null
      : (
          folderId: createName == null ? choice.folderId : null,
          createName: createName,
          parentId: createParentId,
        );
}
