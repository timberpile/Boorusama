import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/create/src/types/edit_booru_config_id.dart';
import 'package:boorusama/core/configs/create/src/types/quick_profile_site.dart';

void main() {
  test('builds entries only from complete registered site metadata', () {
    const booru = BooruScaffold(
      config: BooruYamlConfig(
        name: 'test',
        type: BooruType.danbooru,
        protocol: NetworkProtocol.https_2_0,
        sites: [
          SiteConfig(
            url: 'https://required.example/',
            metadata: {
              'quick-profile': {
                'name': 'Required',
                'authentication': 'required',
              },
            },
          ),
          SiteConfig(
            url: 'https://optional.example/',
            metadata: {
              'quick-profile': {
                'name': 'Optional',
                'authentication': 'optional',
              },
            },
          ),
          SiteConfig(
            url: 'https://anonymous.example/',
            metadata: {
              'quick-profile': {
                'name': 'Anonymous',
                'authentication': 'unnecessary',
              },
            },
          ),
          SiteConfig(
            url: 'https://missing-name.example/',
            metadata: {
              'quick-profile': {'authentication': 'optional'},
            },
          ),
          SiteConfig(
            url: 'https://unknown-auth.example/',
            metadata: {
              'quick-profile': {
                'name': 'Unknown auth',
                'authentication': 'sometimes',
              },
            },
          ),
        ],
      ),
    );

    final entries = QuickProfileSiteCatalog.fromBoorus([booru]);

    expect(
      entries,
      [
        const QuickProfileSite(
          booruType: BooruType.danbooru,
          url: 'https://required.example/',
          profileName: 'Required',
          authentication: QuickProfileAuthentication.required,
        ),
        const QuickProfileSite(
          booruType: BooruType.danbooru,
          url: 'https://optional.example/',
          profileName: 'Optional',
          authentication: QuickProfileAuthentication.optional,
        ),
        const QuickProfileSite(
          booruType: BooruType.danbooru,
          url: 'https://anonymous.example/',
          profileName: 'Anonymous',
          authentication: QuickProfileAuthentication.unnecessary,
        ),
      ],
    );
  });

  test('returns no entries for empty and unknown engine metadata', () {
    const unknown = BooruScaffold(
      config: BooruYamlConfig(
        name: 'unknown',
        type: BooruType.unknown,
        protocol: NetworkProtocol.https_2_0,
        sites: [
          SiteConfig(
            url: 'https://unknown.example/',
            metadata: {
              'quick-profile': {
                'name': 'Unknown',
                'authentication': 'unnecessary',
              },
            },
          ),
        ],
      ),
    );

    expect(QuickProfileSiteCatalog.fromBoorus(const []), isEmpty);
    expect(QuickProfileSiteCatalog.fromBoorus(const [unknown]), isEmpty);
  });

  test('prepopulates the selected engine, URL, and profile name', () {
    const site = QuickProfileSite(
      booruType: BooruType.gelbooruV2,
      url: 'https://rule34.xxx/',
      profileName: 'Rule34',
      authentication: QuickProfileAuthentication.required,
    );

    final editId = site.toEditId();

    expect(editId.booruType, BooruType.gelbooruV2);
    expect(editId.url, 'https://rule34.xxx/');
    expect(editId.initialName, 'Rule34');
  });

  test(
    'keeps legacy profile creation links without a suggested name valid',
    () {
      final editId = EditBooruConfigId.fromUri(
        Uri.parse('/boorus/add?type=20&url=https://danbooru.donmai.us/&id=-1'),
      );

      expect(editId?.booruType, BooruType.danbooru);
      expect(editId?.url, 'https://danbooru.donmai.us/');
      expect(editId?.initialName, isNull);
    },
  );
}
