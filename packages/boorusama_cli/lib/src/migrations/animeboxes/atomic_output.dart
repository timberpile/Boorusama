import 'dart:io';
import 'dart:math';

final class AtomicMigrationOutput {
  const AtomicMigrationOutput();

  static const bookmarksFilename = 'boorusama_bookmarks.json';
  static const blacklistedTagsFilename = 'boorusama_blacklisted_tags.json';
  static const pinnedSearchesFilename = 'boorusama_pinned_searches.json';
  static const reportFilename = 'conversion_report.json';

  static const artifactNames = {
    bookmarksFilename,
    blacklistedTagsFilename,
    pinnedSearchesFilename,
    reportFilename,
  };

  Future<void> writeFile({
    required File target,
    required String contents,
  }) async {
    _requireWritableTarget(target.path);
    final temporary = File(_temporaryPath(target.path));
    try {
      await temporary.create(exclusive: true);
      await temporary.writeAsString(contents, flush: true);
      await temporary.rename(target.path);
    } on Object {
      _deleteTemporaryFile(temporary);
      throw AtomicMigrationOutputException(
        'file_write_failed',
        target.path,
      );
    }
  }

  Future<void> writeDirectory({
    required Directory target,
    required Map<String, String> files,
  }) async {
    _validateArtifactNames(files.keys);
    _requireWritableTarget(target.path);
    final temporary = Directory(_temporaryPath(target.path));
    try {
      await temporary.create();
      for (final entry in files.entries) {
        await File('${temporary.path}/${entry.key}').writeAsString(
          entry.value,
          flush: true,
        );
      }
      await temporary.rename(target.path);
    } on Object {
      _deleteTemporaryDirectory(temporary);
      throw AtomicMigrationOutputException(
        'directory_write_failed',
        target.path,
      );
    }
  }
}

final class AtomicMigrationOutputException implements Exception {
  const AtomicMigrationOutputException(this.code, this.path);

  final String code;
  final String path;

  @override
  String toString() => '$code: $path';
}

void _requireWritableTarget(String path) {
  if (FileSystemEntity.typeSync(path, followLinks: false) !=
      FileSystemEntityType.notFound) {
    throw AtomicMigrationOutputException('target_exists', path);
  }
  final parent = File(path).parent;
  if (!parent.existsSync()) {
    throw AtomicMigrationOutputException('missing_parent', path);
  }
}

void _validateArtifactNames(Iterable<String> names) {
  final supplied = names.toSet();
  if (supplied.length != AtomicMigrationOutput.artifactNames.length ||
      !supplied.containsAll(AtomicMigrationOutput.artifactNames)) {
    throw const AtomicMigrationOutputException(
      'invalid_artifact_names',
      '',
    );
  }
}

String _temporaryPath(String target) =>
    '$target.tmp.$pid.${DateTime.now().microsecondsSinceEpoch}.${Random.secure().nextInt(1 << 32)}';

void _deleteTemporaryFile(File temporary) {
  if (temporary.existsSync()) {
    temporary.deleteSync();
  }
}

void _deleteTemporaryDirectory(Directory temporary) {
  if (temporary.existsSync()) {
    temporary.deleteSync(recursive: true);
  }
}
