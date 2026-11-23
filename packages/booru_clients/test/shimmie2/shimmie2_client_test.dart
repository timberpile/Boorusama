import 'dart:io';

import 'package:booru_clients/src/shimmie2/shimmie2_client.dart';
import 'package:booru_clients/src/shimmie2/types/types.dart';
import 'package:dio/dio.dart' as dio;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

void main() {
  group('Shimmie2 Favorite lookup', () {
    late String body;
    late Shimmie2Client client;

    setUp(() {
      final clientDio =
          dio.Dio(dio.BaseOptions(baseUrl: 'https://shimmie.example'))
            ..interceptors.add(
              dio.InterceptorsWrapper(
                onRequest: (request, handler) {
                  expect(
                    request.queryParameters['tags'],
                    'favorited_by=demo id=7,8',
                  );
                  handler.resolve(
                    dio.Response(
                      requestOptions: request,
                      data: body,
                      statusCode: 200,
                    ),
                  );
                },
              ),
            );
      addTearDown(() => clientDio.close(force: true));
      client = Shimmie2Client(
        baseUrl: 'https://shimmie.example',
        dio: clientDio,
      );
    });

    Future<List<int>> lookup() =>
        client.filterFavoritesFromUsername(username: 'demo', postIds: [7, 8]);

    test(
      'authored results can resolve both positive and negative IDs',
      () async {
        body = '<posts count="1"><post id="7"/></posts>';
        expect(await lookup(), [7]);
        body = '<posts count="0"/>';
        expect(await lookup(), isEmpty);
      },
    );

    for (final invalid in [
      '<html>Sign in</html>',
      '<posts success="false"/>',
      '<posts count="2"><post id="7"/></posts>',
      '<posts><post id="9"/></posts>',
      '<posts><post id="7"/><post id="7"/></posts>',
    ]) {
      test('rejects an inconclusive response ($invalid)', () async {
        body = invalid;
        await expectLater(lookup(), throwsFormatException);
      });
    }
  });

  group('Shimmie2Client extension discovery', () {
    late HttpServer server;
    late String baseUrl;
    late bool supportsInternalExtensions;
    late bool supportsLegacyExtensions;

    setUp(() async {
      supportsInternalExtensions = true;
      supportsLegacyExtensions = false;
      server = await shelf_io.serve(
        (request) {
          if (request.url.path == 'ext_doc' && supportsLegacyExtensions) {
            return Response.ok(
              """
<html>
  <body>
    <form id='extensions'>
      <table>
        <tbody>
          <tr data-ext='GraphQL'>
            <td></td>
            <td><a href='/ext_doc/graphql'>GraphQL</a></td>
            <td>Add a graphql API</td>
          </tr>
        </tbody>
      </table>
    </form>
    <footer>Shimmie version 2.11.0</footer>
  </body>
</html>
""",
              headers: {'content-type': 'text/html'},
            );
          }

          if (request.url.path == 'api/internal/extensions' &&
              supportsInternalExtensions) {
            return Response.ok(
              '["danbooru_api","graphql","user_api_keys","unknown"]',
              headers: {
                'content-type': 'application/json',
                'x-powered-by': 'Shimmie-2.12.2-20260425-0b60143',
              },
            );
          }

          return Response.notFound('Not found');
        },
        'localhost',
        0,
      );
      baseUrl = 'http://${server.address.host}:${server.port}';
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test(
      'uses legacy HTML extension data when internal API is unavailable',
      () async {
        supportsInternalExtensions = false;
        supportsLegacyExtensions = true;
        final client = Shimmie2Client(baseUrl: baseUrl);

        final result = await client.getExtensions();

        final success = result as ExtensionsSuccess;
        expect(success.source, ExtensionDiscoverySource.legacyHtml);
        expect(success.isPartial, false);
        expect(success.version.toString(), '2.11.0');
        expect(success.extensions.single.name, 'GraphQL');
        expect(success.extensions.single.description, 'Add a graphql API');
        expect(success.extensions.single.docLink, '$baseUrl/ext_doc/graphql');
      },
    );

    test('uses internal JSON extension keys when available', () async {
      final client = Shimmie2Client(baseUrl: baseUrl);

      final result = await client.getExtensions();

      final success = result as ExtensionsSuccess;
      expect(success.source, ExtensionDiscoverySource.internalJson);
      expect(success.isPartial, true);
      expect(success.version.toString(), '2.12.2');
      expect(
        success.extensions.map((e) => e.name),
        containsAll(['Danbooru Client API', 'GraphQL', 'User API Key']),
      );
      expect(success.extensions.map((e) => e.name), contains('unknown'));
    });
  });
}
