import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as p;

import '../../../../foundation/filesystem.dart';
import 'import_preflight.dart';

enum ImportJournalState {
  preparing,
  prepared,
  applying,
  applied,
  rollingBack,
  recovered,
  committed,
  recoveryRequired,
}

final class ImportJournal extends Equatable {
  ImportJournal({
    required this.transactionId,
    required this.planHash,
    required this.state,
    required Iterable<String> sourceIds,
    Iterable<String> completedSourceIds = const [],
    Map<String, String> rollbackHashes = const {},
    this.currentSourceId,
    this.error,
  }) : sourceIds = List.unmodifiable(sourceIds),
       completedSourceIds = List.unmodifiable(completedSourceIds),
       rollbackHashes = Map.unmodifiable(rollbackHashes);

  factory ImportJournal.fromJson(Map<String, dynamic> json) => ImportJournal(
    transactionId: json['transactionId'] as String,
    planHash: json['planHash'] as String,
    state: ImportJournalState.values.byName(json['state'] as String),
    sourceIds: (json['sourceIds'] as List<dynamic>).cast<String>(),
    completedSourceIds: (json['completedSourceIds'] as List<dynamic>)
        .cast<String>(),
    rollbackHashes: Map<String, String>.from(
      json['rollbackHashes'] as Map? ?? const {},
    ),
    currentSourceId: json['currentSourceId'] as String?,
    error: json['error'] as String?,
  );

  final String transactionId;
  final String planHash;
  final ImportJournalState state;
  final List<String> sourceIds;
  final List<String> completedSourceIds;
  final Map<String, String> rollbackHashes;
  final String? currentSourceId;
  final String? error;

  ImportJournal copyWith({
    ImportJournalState? state,
    Iterable<String>? completedSourceIds,
    Map<String, String>? rollbackHashes,
    String? currentSourceId,
    bool clearCurrentSource = false,
    String? error,
  }) => ImportJournal(
    transactionId: transactionId,
    planHash: planHash,
    state: state ?? this.state,
    sourceIds: sourceIds,
    completedSourceIds: completedSourceIds ?? this.completedSourceIds,
    rollbackHashes: rollbackHashes ?? this.rollbackHashes,
    currentSourceId: clearCurrentSource
        ? null
        : currentSourceId ?? this.currentSourceId,
    error: error ?? this.error,
  );

  Map<String, Object?> toJson() => {
    'transactionId': transactionId,
    'planHash': planHash,
    'state': state.name,
    'sourceIds': sourceIds,
    'completedSourceIds': completedSourceIds,
    'rollbackHashes': rollbackHashes,
    'currentSourceId': currentSourceId,
    'error': error,
  };

  @override
  List<Object?> get props => [
    transactionId,
    planHash,
    state,
    sourceIds,
    completedSourceIds,
    rollbackHashes,
    currentSourceId,
    error,
  ];
}

final class ImportJournalStore {
  const ImportJournalStore({required this.fs, required this.rootPath});

  final AppFileSystem fs;
  final String rootPath;

  static const _retiredPrefix = '.retired-';
  static final _validId = RegExp(r'^[A-Za-z0-9_-]+$');

  String transactionPath(String id) {
    if (!_validId.hasMatch(id)) {
      throw const FormatException('Invalid import transaction ID');
    }
    return p.join(rootPath, id);
  }

  String _retiredPath(String id) => p.join(rootPath, '$_retiredPrefix$id');
  String rollbackPath(String id, String sourceId) =>
      '${transactionPath(id)}/rollback/$sourceId';

  Future<ImportJournal> create(
    String transactionId,
    ValidatedImportPlan plan,
  ) async {
    final path = transactionPath(transactionId);
    final retired = _retiredPath(transactionId);
    if (await fs.directoryExists(path) || await fs.directoryExists(retired)) {
      throw StateError('Import transaction ID is already in use');
    }
    await fs.createDirectory('$path/rollback', recursive: true);
    await fs.syncDirectory(p.dirname(rootPath));
    await fs.syncDirectory(rootPath);
    await fs.syncDirectory(path);
    await fs.syncDirectory('$path/rollback');
    final planJson = jsonEncode(plan.plan.toJson());
    await fs.writeString('$path/plan.json', planJson);
    await fs.syncFile('$path/plan.json');
    await fs.syncDirectory(path);
    final journal = ImportJournal(
      transactionId: transactionId,
      planHash: sha256.convert(utf8.encode(planJson)).toString(),
      state: ImportJournalState.preparing,
      sourceIds: plan.plan.sources.map((source) => source.id),
    );
    await write(journal);
    return journal;
  }

  Future<void> write(ImportJournal journal) async {
    final path = transactionPath(journal.transactionId);
    final temporary = '$path/journal.json.tmp';
    final backup = '$path/journal.json.bak';
    await fs.writeString(temporary, jsonEncode(journal.toJson()));
    await fs.syncFile(temporary);
    if (await fs.fileExists('$path/journal.json')) {
      if (await fs.fileExists(backup)) await fs.deleteFile(backup);
      await fs.renameFile('$path/journal.json', backup);
      await fs.syncDirectory(path);
    }
    await fs.renameFile(temporary, '$path/journal.json');
    await fs.syncDirectory(path);
    // The new journal is durable. Backups left by failed cleanup can be
    // removed by the next write or by retirement.
    try {
      await fs.deleteFileIfExists(backup);
    } on FileSystemException catch (error, stackTrace) {
      _logCleanup(error, stackTrace);
    }
  }

  Future<ImportJournal> read(String transactionId) async {
    final path = transactionPath(transactionId);
    final journalPath = await fs.fileExists('$path/journal.json')
        ? '$path/journal.json'
        : await fs.fileExists('$path/journal.json.tmp')
        ? '$path/journal.json.tmp'
        : '$path/journal.json.bak';
    return _decode(await fs.readString(journalPath), transactionId);
  }

  ImportJournal _decode(String bytes, String id) {
    final decoded = jsonDecode(bytes);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid import journal');
    }
    final journal = ImportJournal.fromJson(decoded);
    if (journal.transactionId != id) {
      throw const FormatException(
        'Import journal ID does not match its directory',
      );
    }
    return journal;
  }

  Future<void> verifyPlan(ImportJournal journal) async {
    final bytes = utf8.encode(
      await fs.readString(
        '${transactionPath(journal.transactionId)}/plan.json',
      ),
    );
    if (sha256.convert(bytes).toString() != journal.planHash) {
      throw const FormatException('Import plan failed verification');
    }
  }

  Future<List<ImportJournal>> pending() async {
    if (!await fs.directoryExists(rootPath)) return const [];
    final journals = <ImportJournal>[];
    for (final entry in await fs.listDirectory(rootPath, followLinks: false)) {
      if (!entry.isDirectory) continue;
      final name = p.basename(entry.path);
      if (name.startsWith(_retiredPrefix)) {
        final id = name.substring(_retiredPrefix.length);
        if (await fs.directoryExists(transactionPath(id))) {
          throw const FormatException(
            'Active and retired import directories both exist',
          );
        }
        await _retryCleanup(() => _deleteRetired(entry.path, id));
      } else {
        journals.add(await read(name));
      }
    }
    return journals;
  }

  Future<void> retire(ImportJournal journal) async {
    _requireTerminal(journal);
    final path = transactionPath(journal.transactionId);
    final retired = _retiredPath(journal.transactionId);
    await _retryCleanup(() async {
      if (await fs.directoryExists(path)) {
        if (await fs.directoryExists(retired)) {
          throw const FormatException(
            'Import retirement destination already exists',
          );
        }
        // The caller may hold an earlier snapshot of a still-active journal.
        // Use the same on-disk journal selection as cold recovery.
        _requireTerminal(await read(journal.transactionId));
        await fs.renameDirectory(path, retired);
      }
      if (await fs.directoryExists(retired)) {
        await _deleteRetired(retired, journal.transactionId);
      }
    });
  }

  Future<void> _deleteRetired(String path, String id) async {
    final bytes = await fs.readStringIfExists(p.join(path, 'journal.json'));
    if (bytes != null) _requireTerminal(_decode(bytes, id));
    // Make the rename durable before recursively deleting any journal or rollback
    // data. Startup can retry deletion even if the renamed directory is partial.
    await fs.syncDirectory(rootPath);
    await fs.deleteDirectory(path, recursive: true);
    await fs.syncDirectory(rootPath);
  }

  static void _requireTerminal(ImportJournal journal) {
    if (journal.currentSourceId != null ||
        (journal.state != ImportJournalState.preparing &&
            journal.state != ImportJournalState.committed &&
            journal.state != ImportJournalState.recovered)) {
      throw const FormatException('Cannot retire a nonterminal import journal');
    }
  }

  Future<void> _retryCleanup(Future<void> Function() cleanup) async {
    try {
      await cleanup();
    } on FileSystemException catch (error, stackTrace) {
      _logCleanup(error, stackTrace);
    }
  }

  static void _logCleanup(FileSystemException error, StackTrace stackTrace) {
    developer.log(
      'Import journal cleanup deferred',
      name: 'boorusama.import',
      error: error.osError?.errorCode,
      stackTrace: stackTrace,
    );
  }
}
