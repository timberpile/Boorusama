// Package imports:
import 'package:kurumi/material.dart';
import 'package:shelf/shelf.dart' as shelf;

// Project imports:
import '../preparation/version_checking.dart';
import 'types.dart';

abstract interface class BackupExportScope {}

class BackupExportOptions {
  const BackupExportOptions({this.scope});

  final BackupExportScope? scope;
}

class ServerCapability {
  const ServerCapability({
    required this.export,
    required this.prepareImport,
  });

  final Future<shelf.Response> Function(shelf.Request request) export;
  final Future<ImportPreparation> Function(
    String serverUrl,
    BuildContext? uiContext,
  )
  prepareImport;
}

class FileCapability {
  const FileCapability({
    required this.export,
    required this.prepareImport,
  });

  final Future<BackupOperationResult?> Function(
    String path, {
    BackupExportOptions? options,
  })
  export;
  final Future<ImportPreparation> Function(String path, BuildContext? uiContext)
  prepareImport;
}

class ClipboardCapability {
  const ClipboardCapability({
    required this.export,
    required this.prepareImport,
  });

  final Future<BackupOperationResult?> Function({
    BackupExportOptions? options,
  })
  export;
  final Future<ImportPreparation> Function(BuildContext? uiContext)
  prepareImport;
}

class BackupCapabilities {
  const BackupCapabilities({
    required this.server,
    this.file,
    this.clipboard,
  });

  final ServerCapability server; // Required for transfer system
  final FileCapability? file;
  final ClipboardCapability? clipboard;
}

abstract class BackupDataSource {
  String get id;
  int get priority;
  String get displayName;
  BackupCapabilities get capabilities;
  Widget buildTile(BuildContext context);
}
