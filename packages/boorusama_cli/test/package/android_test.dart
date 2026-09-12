import 'package:boorusama_cli/src/package/android.dart';
import 'package:test/test.dart';

void main() {
  group('choosing split APKs to package', () {
    final cases = [
      (
        args: ['--split-per-abi'],
        expected: ['arm64-v8a', 'armeabi-v7a', 'x86_64'],
        description: 'packages every ABI when the build is not narrowed',
      ),
      (
        args: ['--target-platform', 'android-arm64'],
        expected: ['arm64-v8a'],
        description: 'packages the requested ABI from a separate flag value',
      ),
      (
        args: ['--target-platform=android-x64'],
        expected: ['x86_64'],
        description: 'packages the requested ABI from a joined flag value',
      ),
      (
        args: ['--target-platform', 'android-arm64,android-arm'],
        expected: ['arm64-v8a', 'armeabi-v7a'],
        description: 'packages comma-separated target platforms',
      ),
      (
        args: [
          '--target-platform',
          'android-x64',
          '--target-platform=android-arm64',
        ],
        expected: ['arm64-v8a', 'x86_64'],
        description: 'packages target platforms from repeated flags',
      ),
      (
        args: ['--target-platform', ' android-x64 '],
        expected: ['x86_64'],
        description: 'ignores whitespace around target platforms',
      ),
      (
        args: ['--target-platform', 'android-riscv64'],
        expected: ['arm64-v8a', 'armeabi-v7a', 'x86_64'],
        description: 'falls back to every ABI for an unknown platform',
      ),
      (
        args: ['--target-platform', ''],
        expected: ['arm64-v8a', 'armeabi-v7a', 'x86_64'],
        description: 'falls back to every ABI for an empty platform value',
      ),
      (
        args: ['--target-platform'],
        expected: ['arm64-v8a', 'armeabi-v7a', 'x86_64'],
        description: 'falls back to every ABI when a flag has no value',
      ),
    ];

    for (final testCase in cases) {
      test(testCase.description, () {
        expect(splitAbisFor(testCase.args), testCase.expected);
      });
    }
  });
}
