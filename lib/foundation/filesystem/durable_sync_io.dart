import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _FileOperationNative = Int32 Function(Int32);
typedef _FileOperationDart = int Function(int);

DynamicLibrary? _cachedLibc;

void syncPosixPath(String path, {bool readWrite = false}) {
  final libc = _cachedLibc ??= _loadLibc();
  final open = libc
      .lookupFunction<
        Int32 Function(Pointer<Utf8>, Int32),
        int Function(Pointer<Utf8>, int)
      >('open');
  final fsync = libc.lookupFunction<_FileOperationNative, _FileOperationDart>(
    'fsync',
  );
  final close = libc.lookupFunction<_FileOperationNative, _FileOperationDart>(
    'close',
  );
  final nativePath = path.toNativeUtf8();
  final descriptor = open(nativePath, readWrite ? 2 : 0);
  malloc.free(nativePath);
  if (descriptor < 0) {
    throw FileSystemException('Failed to open path for durable sync', path);
  }
  try {
    if (fsync(descriptor) != 0) {
      throw FileSystemException('Failed to durably sync path', path);
    }
  } finally {
    close(descriptor);
  }
}

DynamicLibrary _loadLibc() {
  if (Platform.isAndroid) return DynamicLibrary.open('libc.so');
  if (Platform.isLinux) return DynamicLibrary.open('libc.so.6');
  return DynamicLibrary.process();
}
