// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/services.dart';

// Package imports:
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

// Project imports:
import '../../../../foundation/filesystem.dart';

class ReceivedExport {
  const ReceivedExport({
    required this.id,
    required this.path,
    required this.displayName,
  });

  final String id;
  final String path;
  final String displayName;
}

abstract interface class ReceivedExportPlatform {
  Future<List<Object?>> takePendingExports();

  Stream<Object?> get exportEvents;
}

class MethodChannelReceivedExportPlatform implements ReceivedExportPlatform {
  const MethodChannelReceivedExportPlatform({
    this.methodChannel = const MethodChannel(
      'com.timberpile.boorusama/received_exports_methods',
    ),
    this.eventChannel = const EventChannel(
      'com.timberpile.boorusama/received_exports',
    ),
  });

  final MethodChannel methodChannel;
  final EventChannel eventChannel;

  @override
  Stream<Object?> get exportEvents => eventChannel.receiveBroadcastStream();

  @override
  Future<List<Object?>> takePendingExports() async =>
      await methodChannel.invokeListMethod<Object?>('takePendingExports') ??
      const [];
}

class ReceivedExportService {
  ReceivedExportService({
    required this.stagingDirectoryPath,
    this.platform = const MethodChannelReceivedExportPlatform(),
    this.fs = const IoFileSystem(),
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  static Future<ReceivedExportService> create({
    ReceivedExportPlatform platform =
        const MethodChannelReceivedExportPlatform(),
    AppFileSystem fs = const IoFileSystem(),
  }) async {
    final appStoragePath = await fs.getAppStoragePath();
    return ReceivedExportService(
      platform: platform,
      fs: fs,
      stagingDirectoryPath: p.join(appStoragePath, 'received_exports'),
    );
  }

  final String stagingDirectoryPath;
  final ReceivedExportPlatform platform;
  final AppFileSystem fs;
  final Uuid _uuid;
  final Set<String> _receivedIds = {};

  Stream<ReceivedExport> get exports async* {
    final liveEvents = StreamController<Object?>();
    final subscription = platform.exportEvents.listen(
      liveEvents.add,
      onError: liveEvents.addError,
      onDone: liveEvents.close,
    );

    try {
      final pending = await platform.takePendingExports();
      for (final event in pending) {
        final export = await _stage(event);
        if (export != null) yield export;
      }
      await for (final event in liveEvents.stream) {
        final export = await _stage(event);
        if (export != null) yield export;
      }
    } finally {
      await subscription.cancel();
    }
  }

  Future<ReceivedExport?> _stage(Object? rawEvent) async {
    if (rawEvent case {
      'id': final String id,
      'path': final String sourcePath,
    } when id.isNotEmpty && sourcePath.isNotEmpty) {
      if (!_receivedIds.add(id)) {
        await _deleteTransientCopy(sourcePath);
        return null;
      }

      await fs.createDirectory(stagingDirectoryPath, recursive: true);
      final destination = p.join(
        stagingDirectoryPath,
        '${_uuid.v4()}.bsexport',
      );
      try {
        await fs.copyFile(sourcePath, destination);
        await _deleteTransientCopy(sourcePath);
        final displayName = switch (rawEvent['displayName']) {
          final String name when name.isNotEmpty => name,
          _ => 'received.bsexport',
        };
        return ReceivedExport(
          id: id,
          path: destination,
          displayName: displayName,
        );
      } catch (_) {
        _receivedIds.remove(id);
        if (await fs.fileExists(destination)) {
          await fs.deleteFile(destination);
        }
        rethrow;
      }
    }

    return null;
  }

  Future<void> _deleteTransientCopy(String path) async {
    if (await fs.fileExists(path)) await fs.deleteFile(path);
  }
}
