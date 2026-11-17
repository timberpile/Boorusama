void syncPosixPath(String path, {bool readWrite = false}) {
  throw UnsupportedError('Durable file sync is unavailable');
}

Future<void> syncPosixPathAsync(String path, {bool readWrite = false}) async =>
    syncPosixPath(path, readWrite: readWrite);
