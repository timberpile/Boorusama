import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Publishes a complete temporary file without replacing any existing entry.
/// Unlike an existence check followed by rename, the native operation also
/// protects against other isolates/processes publishing the same destination.
bool publishFileIfAbsent(String source, String destination) {
  final int result;
  if (Platform.isWindows) {
    final move = DynamicLibrary.open('kernel32.dll')
        .lookupFunction<
          Int32 Function(Pointer<Utf16>, Pointer<Utf16>),
          int Function(Pointer<Utf16>, Pointer<Utf16>)
        >('MoveFileW');
    final from = source.toNativeUtf16();
    final to = destination.toNativeUtf16();
    try {
      result = move(from, to) != 0 ? 0 : -1;
    } finally {
      malloc.free(from);
      malloc.free(to);
    }
  } else {
    final libc = Platform.isAndroid
        ? DynamicLibrary.open('libc.so')
        : Platform.isLinux
        ? DynamicLibrary.open('libc.so.6')
        : DynamicLibrary.process();
    final from = source.toNativeUtf8();
    final to = destination.toNativeUtf8();
    try {
      if (Platform.isMacOS || Platform.isIOS) {
        final rename = libc
            .lookupFunction<
              Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Uint32),
              int Function(Pointer<Utf8>, Pointer<Utf8>, int)
            >('renamex_np');
        result = rename(from, to, 0x4); // RENAME_EXCL
      } else if (libc.providesSymbol('renameat2')) {
        final rename = libc
            .lookupFunction<
              Int32 Function(
                Int32,
                Pointer<Utf8>,
                Int32,
                Pointer<Utf8>,
                Uint32,
              ),
              int Function(int, Pointer<Utf8>, int, Pointer<Utf8>, int)
            >('renameat2');
        result = rename(-100, from, -100, to, 1); // AT_FDCWD, RENAME_NOREPLACE
      } else if (Platform.isAndroid) {
        // Bionic exposed renameat2 only in newer API levels, but the kernel
        // operation is available on supported Android kernels. Calling it
        // directly also works on shared storage where hard links are forbidden.
        final number = switch (Abi.current()) {
          Abi.androidArm => 382,
          Abi.androidArm64 || Abi.androidRiscv64 => 276,
          Abi.androidIA32 => 353,
          Abi.androidX64 => 316,
          _ => throw UnsupportedError('Unknown Android syscall ABI'),
        };
        final syscall = libc
            .lookupFunction<
              IntPtr Function(
                IntPtr,
                IntPtr,
                Pointer<Utf8>,
                IntPtr,
                Pointer<Utf8>,
                IntPtr,
              ),
              int Function(int, int, Pointer<Utf8>, int, Pointer<Utf8>, int)
            >('syscall');
        result = syscall(number, -100, from, -100, to, 1);
      } else {
        // On older libc, a hard link also publishes atomically. Unsupported
        // filesystems fail visibly instead of replacing another writer's file.
        final link = libc
            .lookupFunction<
              Int32 Function(Pointer<Utf8>, Pointer<Utf8>),
              int Function(Pointer<Utf8>, Pointer<Utf8>)
            >('link');
        result = link(from, to);
      }
    } finally {
      malloc.free(from);
      malloc.free(to);
    }
  }
  if (result == 0) return true;
  if (FileSystemEntity.typeSync(destination, followLinks: false) !=
      FileSystemEntityType.notFound) {
    return false;
  }
  throw FileSystemException('Atomic publication failed', destination);
}
