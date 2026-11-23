import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

typedef _FileOperationNative = Int32 Function(Int32);
typedef _FileOperationDart = int Function(int);

DynamicLibrary? _cachedLibc;

/// Only path values cross the isolate boundary; Hive and transaction ownership
/// remain with the caller, which must await this durability barrier.
Future<void> syncPosixPathAsync(String path, {bool readWrite = false}) =>
    Isolate.run(_SyncPathTask(path, readWrite).run);

final class _SyncPathTask {
  const _SyncPathTask(this.path, this.readWrite);
  final String path;
  final bool readWrite;
  void run() => syncPosixPath(path, readWrite: readWrite);
}

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

/// Windows has no parent-directory fsync in IoFileSystem. Complete the
/// same-volume rename with write-through before recursive cleanup can begin.
Future<void> renameWindowsDirectoryDurably(String source, String destination) =>
    Isolate.run(() {
      final kernel = DynamicLibrary.open('kernel32.dll');
      final move = kernel
          .lookupFunction<
            Int32 Function(Pointer<Utf16>, Pointer<Utf16>, Uint32),
            int Function(Pointer<Utf16>, Pointer<Utf16>, int)
          >('MoveFileExW');
      final lastError = kernel
          .lookupFunction<Uint32 Function(), int Function()>('GetLastError');
      final from = source.toNativeUtf16();
      final to = destination.toNativeUtf16();
      try {
        const writeThrough = 0x8; // MOVEFILE_WRITE_THROUGH
        if (move(from, to, writeThrough) == 0) {
          final code = lastError();
          throw FileSystemException(
            'Cannot durably rename directory',
            source,
            OSError('', code),
          );
        }
      } finally {
        malloc.free(from);
        malloc.free(to);
      }
    });
