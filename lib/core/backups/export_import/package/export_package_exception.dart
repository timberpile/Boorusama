class ExportPackageException implements Exception {
  const ExportPackageException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'ExportPackageException: $message';
}
