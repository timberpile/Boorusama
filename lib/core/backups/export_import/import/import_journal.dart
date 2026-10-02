import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';

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

  String transactionPath(String id) => '$rootPath/$id';
  String rollbackPath(String id, String sourceId) =>
      '${transactionPath(id)}/rollback/$sourceId';

  Future<ImportJournal> create(
    String transactionId,
    ValidatedImportPlan plan,
  ) async {
    final path = transactionPath(transactionId);
    await fs.createDirectory('$path/rollback', recursive: true);
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
    if (await fs.fileExists(backup)) await fs.deleteFile(backup);
    await fs.syncDirectory(path);
  }

  Future<ImportJournal> read(String transactionId) async {
    final path = transactionPath(transactionId);
    final journalPath = await fs.fileExists('$path/journal.json')
        ? '$path/journal.json'
        : await fs.fileExists('$path/journal.json.tmp')
        ? '$path/journal.json.tmp'
        : '$path/journal.json.bak';
    final decoded = jsonDecode(await fs.readString(journalPath));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid import journal');
    }
    return ImportJournal.fromJson(decoded);
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
    for (final entry in await fs.listDirectory(rootPath)) {
      if (!entry.isDirectory) continue;
      journals.add(await read(entry.path.split('/').last));
    }
    return journals;
  }

  Future<void> delete(String transactionId) async {
    final path = transactionPath(transactionId);
    if (await fs.directoryExists(path)) {
      await fs.deleteDirectory(path, recursive: true);
      await fs.syncDirectory(rootPath);
    }
  }
}
