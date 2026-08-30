import '../types/types.dart';

String formatBookmarkExportSuccess({
  required BackupOperationResult result,
  required String template,
}) => template.replaceAll('{count}', result.totalCount.toString());

String formatBookmarkImportSuccess({
  required BackupOperationResult result,
  required String template,
  required String existingTemplate,
}) {
  final messageTemplate = result.alreadyExistedCount > 0
      ? existingTemplate
      : template;

  return messageTemplate
      .replaceAll('{count}', result.totalCount.toString())
      .replaceAll('{existing}', result.alreadyExistedCount.toString());
}
