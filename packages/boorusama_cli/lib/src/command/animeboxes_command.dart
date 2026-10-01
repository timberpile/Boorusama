import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../migrations/animeboxes/atomic_output.dart';
import '../migrations/animeboxes/boorusama_exporter.dart';
import '../migrations/animeboxes/csv_reader.dart';
import '../migrations/animeboxes/document_codec.dart';
import '../migrations/animeboxes/errors.dart';
import '../migrations/animeboxes/normalized_types.dart';
import '../migrations/animeboxes/normalizer.dart';

typedef AnimeBoxesOutput = void Function(String value);

final class AnimeBoxesCommand extends Command<int> {
  AnimeBoxesCommand({
    AnimeBoxesOutput? output,
    AnimeBoxesOutput? errorOutput,
    AtomicMigrationOutput atomicOutput = const AtomicMigrationOutput(),
  }) {
    final writeOutput = output ?? (String value) => stdout.writeln(value);
    final writeError = errorOutput ?? (String value) => stderr.writeln(value);
    addSubcommand(
      _AnimeBoxesNormalizeCommand(
        output: writeOutput,
        errorOutput: writeError,
        atomicOutput: atomicOutput,
      ),
    );
    addSubcommand(
      _AnimeBoxesExportCommand(
        output: writeOutput,
        errorOutput: writeError,
        atomicOutput: atomicOutput,
      ),
    );
  }

  @override
  String get name => 'animeboxes';

  @override
  String get description => 'Convert AnimeBoxes Android exports.';
}

final class _AnimeBoxesNormalizeCommand extends Command<int> {
  _AnimeBoxesNormalizeCommand({
    required AnimeBoxesOutput output,
    required AnimeBoxesOutput errorOutput,
    required AtomicMigrationOutput atomicOutput,
  }) : _output = output,
       _errorOutput = errorOutput,
       _atomicOutput = atomicOutput {
    argParser
      ..addOption('input', mandatory: true, valueHelp: 'csv')
      ..addOption('output', mandatory: true, valueHelp: 'normalized.json');
  }

  final AnimeBoxesOutput _output;
  final AnimeBoxesOutput _errorOutput;
  final AtomicMigrationOutput _atomicOutput;

  @override
  String get name => 'normalize';

  @override
  String get description => 'Convert an AnimeBoxes CSV to normalized JSON.';

  @override
  String get invocation =>
      'boorusama animeboxes normalize --input <csv> --output <normalized.json>';

  @override
  Future<int> run() async {
    final input = File(argResults!['input'] as String);
    final output = File(argResults!['output'] as String);
    if (_samePath(input.path, output.path)) {
      _errorOutput('AnimeBoxes output error [input_matches_output].');
      return 2;
    }

    try {
      final parsed = const AnimeBoxesCsvReader().parse(
        await input.readAsString(),
      );
      final document = const AnimeBoxesNormalizer().normalize(parsed);
      final encoded = const AnimeBoxesDocumentCodec().encode(document);
      await _atomicOutput.writeFile(target: output, contents: encoded);
      _output(_countSummary('Normalized AnimeBoxes export', document));
      _output('Wrote ${output.path}');
      return 0;
    } on AnimeBoxesFormatException catch (error) {
      _errorOutput(_formatDataError('input', error));
      return 2;
    } on AtomicMigrationOutputException catch (error) {
      _errorOutput(
        'AnimeBoxes output error [${error.code}] at ${output.path}.',
      );
      return 3;
    } on FileSystemException {
      _errorOutput('AnimeBoxes I/O error while reading ${input.path}.');
      return 3;
    } on Object {
      _errorOutput('AnimeBoxes normalization failed.');
      return 1;
    }
  }
}

final class _AnimeBoxesExportCommand extends Command<int> {
  _AnimeBoxesExportCommand({
    required AnimeBoxesOutput output,
    required AnimeBoxesOutput errorOutput,
    required AtomicMigrationOutput atomicOutput,
  }) : _output = output,
       _errorOutput = errorOutput,
       _atomicOutput = atomicOutput {
    argParser
      ..addOption('input', mandatory: true, valueHelp: 'normalized.json')
      ..addOption('output-dir', mandatory: true, valueHelp: 'directory');
  }

  final AnimeBoxesOutput _output;
  final AnimeBoxesOutput _errorOutput;
  final AtomicMigrationOutput _atomicOutput;

  @override
  String get name => 'export';

  @override
  String get description => 'Create Boorusama backups from normalized JSON.';

  @override
  String get invocation =>
      'boorusama animeboxes export --input <normalized.json> --output-dir <directory>';

  @override
  Future<int> run() async {
    final input = File(argResults!['input'] as String);
    final output = Directory(argResults!['output-dir'] as String);

    try {
      final document = const AnimeBoxesDocumentCodec().decode(
        await input.readAsString(),
      );
      final artifacts = const BoorusamaMigrationExporter().export(document);
      await _atomicOutput.writeDirectory(
        target: output,
        files: {
          AtomicMigrationOutput.bookmarksFilename: artifacts.bookmarks,
          AtomicMigrationOutput.blacklistedTagsFilename:
              artifacts.blacklistedTags,
          AtomicMigrationOutput.pinnedSearchesFilename:
              artifacts.pinnedSearches,
          AtomicMigrationOutput.reportFilename: artifacts.report,
        },
      );
      _output(_countSummary('Exported AnimeBoxes data', document));
      for (final filename in AtomicMigrationOutput.artifactNames) {
        _output('Wrote ${p.join(output.path, filename)}');
      }
      return 0;
    } on AnimeBoxesFormatException catch (error) {
      _errorOutput(_formatDataError('normalized data', error));
      return 2;
    } on AtomicMigrationOutputException catch (error) {
      _errorOutput(
        'AnimeBoxes output error [${error.code}] at ${output.path}.',
      );
      return 3;
    } on FileSystemException {
      _errorOutput('AnimeBoxes I/O error while reading ${input.path}.');
      return 3;
    } on Object {
      _errorOutput('AnimeBoxes export failed.');
      return 1;
    }
  }
}

String _formatDataError(String kind, AnimeBoxesFormatException error) {
  final location = switch ((error.section, error.row)) {
    (final section?, final row?) => ' at $section row $row',
    (final section?, null) => ' at $section',
    (null, final row?) => ' at row $row',
    _ => '',
  };
  return 'AnimeBoxes $kind error [${error.code}]$location.';
}

String _countSummary(String prefix, NormalizedAnimeBoxesDocument document) {
  final folders = document.pinnedSearchFolders
      .where((group) => group.kind == 'folder')
      .length;
  final searches = document.pinnedSearchFolders.fold(
    0,
    (count, group) => count + group.searches.length,
  );
  return '$prefix: profiles=${document.profiles.length}, '
      'history=${document.searchHistory.length}, '
      'bookmarks=${document.bookmarks.length}, '
      'blacklist=${document.blacklist.length}, '
      'folders=$folders, searches=$searches.';
}

bool _samePath(String left, String right) =>
    p.normalize(p.absolute(left)) == p.normalize(p.absolute(right));
