import 'package:flutter/services.dart';

/// Retained diagnostics must never contain exception messages or provider paths.
class AutoBackupFailure {
  const AutoBackupFailure._({required this.code, this.stage});

  factory AutoBackupFailure.fromError(Object error) {
    if (error is! PlatformException) {
      return const AutoBackupFailure._(code: 'backup_failed');
    }
    final code = switch (error.code) {
      'backup_folder_access_required' => 'backup_folder_access_required',
      'backup_storage_failed' => 'backup_storage_failed',
      'backup_picker_busy' => 'backup_picker_busy',
      _ => 'backup_failed',
    };
    final details = error.details;
    final stage = details is Map ? details['stage'] : null;
    return AutoBackupFailure._(
      code: code,
      stage: stage is String && _stages.contains(stage) ? stage : null,
    );
  }

  final String code;
  final String? stage;

  bool get requiresFolderAccess => code == 'backup_folder_access_required';
  String get diagnostic => stage == null ? code : '$code ($stage)';

  static const _stages = {
    'open_folder_picker',
    'persist_folder_permission',
    'validate_location',
    'check_persisted_permission',
    'resolve_root',
    'read_folder_name',
    'find_backup_folder',
    'create_backup_folder',
    'list_backup_folder',
    'read_backup_size',
    'delete_retained_backup',
    'read_manifest',
    'open_manifest',
    'write_manifest',
    'validate_staged_package',
    'create_backup_document',
    'copy_backup_document',
    'verify_backup_document',
    'dispatch_operation',
  };
}
