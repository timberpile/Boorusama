import 'normalized_types.dart';

final class AnimeBoxesConversionReport {
  AnimeBoxesConversionReport.fromDocument(
    NormalizedAnimeBoxesDocument document, {
    List<AnimeBoxesDiagnostic> outputDiagnostics = const [],
  }) : _document = document,
       _outputDiagnostics = List.unmodifiable(outputDiagnostics);

  static const schema = 'boorusama.animeboxes.conversion-report';
  static const version = 1;

  final NormalizedAnimeBoxesDocument _document;
  final List<AnimeBoxesDiagnostic> _outputDiagnostics;

  Map<String, Object?> toJson() {
    final folders = _document.pinnedSearchFolders
        .where((group) => group.kind == 'folder')
        .length;
    final searches = _document.pinnedSearchFolders.fold(
      0,
      (count, group) => count + group.searches.length,
    );
    final duplicateBookmarks = _document.diagnostics
        .where((diagnostic) => diagnostic.code == 'duplicate_bookmark')
        .fold(0, (count, diagnostic) => count + diagnostic.count);
    final diagnostics = <String, int>{};
    for (final diagnostic in [
      ..._document.diagnostics,
      ..._outputDiagnostics,
    ]) {
      diagnostics.update(
        diagnostic.code,
        (count) => count + diagnostic.count,
        ifAbsent: () => diagnostic.count,
      );
    }

    final retainedCounts = {
      'profiles': _document.profiles.length,
      'history': _document.searchHistory.length,
      'bookmarks': _document.bookmarks.length,
      'blacklist': _document.blacklist.length,
      'folders': folders,
      'searches': searches,
    };
    return {
      'schema': schema,
      'version': version,
      'sourceCounts': {
        ...retainedCounts,
        'bookmarks': _document.bookmarks.length + duplicateBookmarks,
      },
      'retainedCounts': retainedCounts,
      'outputCounts': {
        'bookmarks': _document.bookmarks.length,
        'blacklistedTags': _document.blacklist.length,
        'pinnedSearchFolders': folders,
        'pinnedSearches': searches,
      },
      'diagnostics': [
        for (final entry in diagnostics.entries)
          {'code': entry.key, 'count': entry.value},
      ],
    };
  }
}
