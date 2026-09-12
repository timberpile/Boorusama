import 'dart:io';

import 'package:boorusama_cli/src/builds/build_mode.dart';
import 'package:boorusama_cli/src/builds/build_plan.dart';
import 'package:boorusama_cli/src/builds/build_target.dart';
import 'package:boorusama_cli/src/io/logger.dart';
import 'package:boorusama_cli/src/io/process_runner.dart';
import 'package:boorusama_cli/src/package/apple.dart';
import 'package:boorusama_cli/src/project/env.dart';
import 'package:boorusama_cli/src/project/git.dart';
import 'package:boorusama_cli/src/project/project.dart';
import 'package:boorusama_cli/src/project/pubspec.dart';
import 'package:boorusama_cli/src/tool/tool_command.dart';
import 'package:boorusama_cli/src/tool/tool_runner.dart';
import 'package:boorusama_cli/src/tool/toolchain.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late Project project;
  late ApplePackager packager;

  setUp(() {
    root = Directory.systemTemp.createTempSync('boorusama-apple-test-');
    project = Project(
      root: root,
      pubspec: const PubspecInfo(
        name: 'boorusama',
        version: '1.0.0',
        versionName: '1.0.0',
        buildNumber: null,
      ),
      env: const Env({}, includePlatform: false),
      git: const GitInfo(commit: 'test', branch: 'test'),
    );
    packager = ApplePackager(_dryRunTools(root));
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('uses Timber production bundle name for iOS packaging', () async {
    final plan = _plan(target: BuildTarget.ipa, flavor: 'prod');

    await expectLater(
      packager.package(project, plan),
      throwsA(
        isA<ProcessFailure>().having(
          (error) => error.message,
          'message',
          equals(
            'iOS app not found at: '
            '${root.path}/build/ios/Release-prod-iphoneos/Boorusama Timber.app',
          ),
        ),
      ),
    );
  });

  test('uses Timber development bundle name for iOS packaging', () async {
    final plan = _plan(target: BuildTarget.ipa, flavor: 'dev');

    await expectLater(
      packager.package(project, plan),
      throwsA(
        isA<ProcessFailure>().having(
          (error) => error.message,
          'message',
          equals(
            'iOS app not found at: '
            '${root.path}/build/ios/Release-dev-iphoneos/Boorusama Timber Dev.app',
          ),
        ),
      ),
    );
  });

  test('uses Timber production bundle name for macOS packaging', () async {
    final plan = _plan(target: BuildTarget.dmg, flavor: 'prod');

    await expectLater(
      packager.package(project, plan),
      throwsA(
        isA<ProcessFailure>().having(
          (error) => error.message,
          'message',
          equals(
            'macOS app not found at: '
            '${root.path}/build/macos/Build/Products/Release-prod/Boorusama Timber.app',
          ),
        ),
      ),
    );
  });

  test('uses Timber development bundle name for macOS packaging', () async {
    final plan = _plan(target: BuildTarget.dmg, flavor: 'dev');

    await expectLater(
      packager.package(project, plan),
      throwsA(
        isA<ProcessFailure>().having(
          (error) => error.message,
          'message',
          equals(
            'macOS app not found at: '
            '${root.path}/build/macos/Build/Products/Release-dev/Boorusama Timber Dev.app',
          ),
        ),
      ),
    );
  });
}

BuildPlan _plan({required BuildTarget target, required String flavor}) {
  return BuildPlan(
    target: target,
    flavor: flavor,
    buildMode: BuildMode.release,
    flutterArgs: const [],
    outputDir: Directory.systemTemp,
    artifactName: 'test.${target.name}',
    targetFile: 'lib/main.dart',
  );
}

ToolRunner _dryRunTools(Directory root) {
  const command = ToolCommand('true');
  return ToolRunner(
    toolchain: const Toolchain(
      flutter: command,
      dart: command,
      git: command,
      pod: command,
      zip: command,
      tar: command,
      appImageTool: command,
      flatpak: command,
      flatpakBuilder: command,
      createDmg: command,
    ),
    processRunner: ProcessRunner(logger: Logger(), dryRun: true),
    root: root,
  );
}
