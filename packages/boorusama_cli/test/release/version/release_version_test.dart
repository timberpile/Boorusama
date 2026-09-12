import 'package:boorusama_cli/src/project/pubspec.dart';
import 'package:boorusama_cli/src/release/version/release_version.dart';
import 'package:test/test.dart';

void main() {
  test('accepts Timberpile prerelease version with build metadata', () {
    const pubspec = PubspecInfo(
      name: 'boorusama',
      version: '4.5.0-timberpile.1+185',
      versionName: '4.5.0-timberpile.1',
      buildNumber: '185',
    );

    final version = ReleaseVersion.fromPubspec(pubspec);

    expect(version.full, '4.5.0-timberpile.1+185');
    expect(version.name, '4.5.0-timberpile.1');
    expect(version.buildNumber, '185');
    expect(version.tag, 'v4.5.0-timberpile.1');
  });
}
