import 'dart:io';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'native data redirects count effective ports and isolate Hydrus/custom credentials',
    () async {
      final first = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final second = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final source = Uri.parse('http://127.0.0.1:${first.port}');
      final target = Uri.parse('http://127.0.0.1:${second.port}');
      final c = ApiRequestCoordinator();
      final requests = <HttpRequest>[];
      first.listen((request) async {
        requests.add(request);
        expect(c.snapshot(ApiQuotaKey.fromUri(source)).inFlight, 1);
        expect(request.headers.value('Hydrus-Client-API-Access-Key'), 'secret');
        request.response.statusCode = HttpStatus.found;
        request.response.headers.set('location', '$target/result?location=ok');
        await request.response.close();
      });
      second.listen((request) async {
        requests.add(request);
        expect(c.snapshot(ApiQuotaKey.fromUri(target)).inFlight, 1);
        expect(c.snapshot(ApiQuotaKey.fromUri(source)).inFlight, 0);
        expect(request.uri.queryParameters, {'location': 'ok'});
        for (final name in [
          'authorization',
          'cookie',
          'Hydrus-Client-API-Access-Key',
          'X-Custom-Credential',
        ]) {
          expect(request.headers.value(name), isNull);
        }
        expect(request.headers.value('accept'), 'application/json');
        request.response.write('done');
        await request.response.close();
      });
      final dio = Dio(
        BaseOptions(
          baseUrl: source.toString(),
          headers: {
            'Authorization': 'Bearer secret',
            'Cookie': 'secret=cookie',
            'Hydrus-Client-API-Access-Key': 'secret',
            'X-Custom-Credential': 'custom',
            'Accept': 'application/json',
          },
        ),
      );
      coordinateApiDio(dio, c);
      try {
        final response = await dio.get(
          '/start',
          queryParameters: {'api_key': 'secret', 'search': 'original'},
        );
        expect(response.data, 'done');
        expect(requests, hasLength(2));
        expect(ApiQuotaKey.fromUri(source), isNot(ApiQuotaKey.fromUri(target)));
        expect(c.snapshot(ApiQuotaKey.fromUri(target)).inFlight, 0);
      } finally {
        dio.close(force: true);
        c.dispose();
        await first.close(force: true);
        await second.close(force: true);
      }
    },
  );
}
