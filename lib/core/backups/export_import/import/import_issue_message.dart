import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import 'import_plan.dart';

String importIssueMessage(
  BuildContext context,
  ImportPlanIssue issue, {
  required Map<String, String> sourceNames,
  required Map<String, String> itemLabels,
}) {
  final strings = context.t.settings.backup_and_restore.export_import.issues;
  final source = sourceNames[issue.sourceId] ?? issue.sourceId;
  final item = issue.itemId == null
      ? source
      : itemLabels[issue.itemId] ?? issue.itemId!;
  return switch (issue.code) {
    'unsupported_source' => strings.unsupported_source.replaceAll(
      '{source}',
      source,
    ),
    'unsupported_source_version' =>
      strings.unsupported_source_version.replaceAll('{source}', source),
    'unknown_selected_item' =>
      strings.unknown_selected_item
          .replaceAll('{source}', source)
          .replaceAll('{item}', item),
    'unselected_payload_item' =>
      strings.unselected_payload_item
          .replaceAll('{source}', source)
          .replaceAll('{item}', item),
    'unknown_recommended_item' =>
      strings.unknown_recommended_item
          .replaceAll('{source}', source)
          .replaceAll('{item}', item),
    'missing_bookmark_reference' =>
      strings.missing_bookmark_reference.replaceAll('{item}', item),
    'duplicate_profile_id' => strings.duplicate_profile_id.replaceAll(
      '{item}',
      item,
    ),
    'credentials_included' => strings.credentials_included,
    'credential_flag_mismatch' => strings.credential_flag_mismatch,
    'unsupported_recommended_action' =>
      strings.unsupported_recommendation.replaceAll('{item}', item),
    'invalid_source_action' => strings.invalid_source_action.replaceAll(
      '{source}',
      source,
    ),
    'invalid_item_action' => strings.invalid_item_action.replaceAll(
      '{item}',
      item,
    ),
    'invalid_merge_target' || 'unresolved_item_target' =>
      strings.invalid_target.replaceAll('{item}', item),
    'insufficient_storage' => strings.insufficient_storage,
    'unresolved_profile_dependency' => switch (issue.profileDependency) {
      final dependency? =>
        (dependency.missingProfile
                ? strings.missing_profile_site
                : strings.unresolved_profile_site)
            .replaceAll(
              '{site}',
              dependency.label.isEmpty
                  ? strings.unknown_site
                  : dependency.label,
            )
            .replaceAll(
              '{sources}',
              dependency.sourceIds
                  .map((id) => sourceNames[id] ?? id)
                  .join(', '),
            ),
      null =>
        strings.unresolved_profile_site
            .replaceAll('{site}', item)
            .replaceAll('{sources}', source),
    },
    'unresolved_profile_import' => strings.unresolved_profile_import.replaceAll(
      '{item}',
      item,
    ),
    'duplicate_source_preflight' || 'missing_source_preflight' =>
      strings.incomplete_checks.replaceAll('{source}', source),
    _ => strings.unknown_problem.replaceAll('{source}', source),
  };
}
