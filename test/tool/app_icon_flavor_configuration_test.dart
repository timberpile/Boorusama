import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('flutter launcher icons uses the matching artwork for every flavor', () {
    final cases = [
      (flavor: 'main', sourceDirectory: 'assets/icon'),
      (flavor: 'prod', sourceDirectory: 'assets/icon'),
      (flavor: 'dev', sourceDirectory: 'assets/icon/dev'),
    ];

    for (final iconCase in cases) {
      final config = File(
        'flutter_launcher_icons-${iconCase.flavor}.yaml',
      ).readAsStringSync();
      expect(
        config,
        contains('${iconCase.sourceDirectory}/icon-512x512.png'),
      );
      expect(
        config,
        contains('${iconCase.sourceDirectory}/icon-ios.png'),
      );
      expect(
        config,
        contains('${iconCase.sourceDirectory}/icon-monochrome-512x512.png'),
      );
    }
  });

  test('Apple builds select the icon catalog for their flavor', () {
    final iosProject = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final macosProject = File(
      'macos/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    for (final configuration in ['Debug', 'Release', 'Profile']) {
      expect(
        _iconCatalog(iosProject, configuration),
        'AppIcon-main',
        reason: 'iOS $configuration',
      );
      expect(
        _iconCatalog(iosProject, '$configuration-prod'),
        'AppIcon-prod',
        reason: 'iOS $configuration-prod',
      );
      expect(
        _iconCatalog(iosProject, '$configuration-dev'),
        'AppIcon-dev',
        reason: 'iOS $configuration-dev',
      );

      expect(
        _iconCatalog(macosProject, configuration),
        'AppIcon',
        reason: 'macOS $configuration',
      );
      expect(
        _iconCatalog(macosProject, '$configuration-prod'),
        'AppIcon',
        reason: 'macOS $configuration-prod',
      );
      expect(
        _iconCatalog(macosProject, '$configuration-dev'),
        'AppIconDev',
        reason: 'macOS $configuration-dev',
      );
    }
  });

  test('Windows and web builds select the development artwork', () {
    final cmake = File('windows/runner/CMakeLists.txt').readAsStringSync();
    final resources = File('windows/runner/Runner.rc').readAsStringSync();
    final web = File('web/index.html').readAsStringSync();
    final webBuild = File('scripts/build_web_dev.sh').readAsStringSync();

    expect(cmake, contains('FLUTTER_APP_FLAVOR STREQUAL "dev"'));
    expect(cmake, contains('BOORUSAMA_DEV_ICON'));
    expect(resources, contains('app_icon_dev.ico'));
    expect(resources, contains('#ifdef BOORUSAMA_DEV_ICON'));
    expect(web, contains("'{{BOORUSAMA_ICON_FLAVOR}}' === 'dev'"));
    expect(web, contains('icons-dev/Icon-192.png'));
    expect(web, contains('manifest-dev.json'));
    expect(webBuild, contains('--web-define=BOORUSAMA_ICON_FLAVOR=dev'));
  });
}

String? _iconCatalog(String project, String configuration) {
  final escaped = RegExp.escape(configuration);
  final blocks = RegExp(
    r'[A-F0-9]+ /\* ' + escaped + r' \*/ = \{(.*?)\n\t\t\};',
    dotAll: true,
  ).allMatches(project);

  for (final block in blocks) {
    final value = RegExp(
      'ASSETCATALOG_COMPILER_APPICON_NAME = ([^;]+);',
    ).firstMatch(block.group(1)!)?.group(1);
    if (value != null) return value;
  }
  return null;
}
