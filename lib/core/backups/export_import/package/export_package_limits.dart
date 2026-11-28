final class ExportPackageLimits {
  const ExportPackageLimits({
    this.separateBookmarkBudget = false,
    this.maxFileCount = 128,
    this.maxManifestBytes = 1024 * 1024,
    this.maxPartBytes = 512 * 1024 * 1024,
    this.maxExpandedBytes = 2 * 1024 * 1024 * 1024,
    this.maxExpansionRatio = 200,
  });

  /// Normal backups grant streamed Bookmark tables a separate disk budget.
  /// Callers supplying tighter preparation limits share them across all parts.
  final bool separateBookmarkBudget;
  final int maxFileCount;
  final int maxManifestBytes;
  final int maxPartBytes;
  final int maxExpandedBytes;
  final double maxExpansionRatio;
}
