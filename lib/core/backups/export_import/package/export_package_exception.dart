class ExportPackageException implements Exception {
  const ExportPackageException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'ExportPackageException: $message';
}

/// A supported export exceeded a configured read or preparation bound.
final class ExportPackageLimitException extends ExportPackageException {
  const ExportPackageLimitException(super.message);
}
