import 'dart:io';

// Numeric OS codes distinguish unavailable storage, access failures and network
// errors without reading messages, file paths, hosts or socket addresses.
List<String> platformErrorDetails(Object error) {
  final osError = switch (error) {
    FileSystemException(:final osError) => osError,
    SocketException(:final osError) => osError,
    final OSError error => error,
    _ => null,
  };
  return [if (osError != null) 'os_error=${osError.errorCode}'];
}
