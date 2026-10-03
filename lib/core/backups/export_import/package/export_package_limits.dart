final class ExportPackageLimits {
  const ExportPackageLimits({
    this.maxFileCount = 128,
    this.maxManifestBytes = 1024 * 1024,
    this.maxPartBytes = 512 * 1024 * 1024,
    this.maxExpandedBytes = 2 * 1024 * 1024 * 1024,
    this.maxExpansionRatio = 200,
  });

  final int maxFileCount;
  final int maxManifestBytes;
  final int maxPartBytes;
  final int maxExpandedBytes;
  final double maxExpansionRatio;
}
