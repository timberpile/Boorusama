import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:booru_clients/nhentai.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:boorusama/core/http/client/src/data/public_read_http_adapter.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opt-in real service/host decoder evidence. Ordinary regression is offline.
/// Android acceptance remains separate, even when this host probe passes.
void main() {
  test(
    'native anonymous API and exact returned CDN resources decode',
    () async {
      final coordinator = ApiRequestCoordinator();
      var current = true;
      final source = const AnonymousSourcePolicy().resolve(
        BooruType.nhentai,
        Uri.parse('https://nhentai.net'),
      )!;
      final dio = newGenericDio(
        baseUrl: source.site.toString(),
        apiCoordinator: coordinator,
        headers: {
          'Referer': source.site.toString(),
          'User-Agent': 'Boorusama/native-read-check',
        },
      );
      dio.options
        ..connectTimeout = const Duration(seconds: 15)
        ..receiveTimeout = const Duration(seconds: 20);
      dio.httpClientAdapter = PublicReadHttpClientAdapter(
        delegate: dio.httpClientAdapter,
        source: source,
        current: () => current,
      );
      addTearDown(() {
        current = false;
        dio.close(force: true);
        coordinator.dispose();
      });
      final client = NhentaiClient(dio: dio);
      final policy = await client.getMediaPolicy();
      final listing = await client.getGalleries(perPage: 2);
      final details = await client.getGallery(694482);
      final tags = await client.getTagsByIds([152]);
      final search = await client.getGalleries(
        query: 'language:english',
        perPage: 2,
      );
      print(
        jsonEncode({
          'stage': 'native_api',
          'listing_count': listing.rawCount,
          'search_count': search.rawCount,
          'tag_lookup_count': tags.length,
          'declared_pages': details.pageCount,
          'manifest_count': details.pages?.length,
        }),
      );
      expect(listing.items, isNotEmpty);
      expect(details.pages, isNotEmpty);
      expect(tags, isNotEmpty);
      expect(search.items, isNotEmpty);
      final page = details.pages!.first;
      for (final descriptor in [
        (role: 'page', thumbnail: false, path: page.path),
        (role: 'thumbnail', thumbnail: true, path: details.thumbnail?.path),
      ]) {
        expect(descriptor.path, isNotNull);
        final uri = policy.resolve(
          mediaId: details.mediaId!,
          path: descriptor.path!,
          thumbnail: descriptor.thumbnail,
        );
        final response = await dio.getUri<List<int>>(
          uri,
          options: Options(
            responseType: ResponseType.bytes,
            extra: const {apiMediaRequestKey: true},
          ),
        );
        expect(response.statusCode, 200);
        final bytes = Uint8List.fromList(response.data!);
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        print(
          jsonEncode({
            'stage': 'native_decode',
            'role': descriptor.role,
            'status': response.statusCode,
            'bytes': bytes.length,
            'width': frame.image.width,
            'height': frame.image.height,
            'duplicate_extension': RegExp(r'\.(webp|jpg|png)\.\1$')
                .hasMatch(uri.path),
          }),
        );
        expect(frame.image.width, greaterThan(0));
        expect(frame.image.height, greaterThan(0));
        frame.image.dispose();
        codec.dispose();
      }
    },
    skip: Platform.environment['BOORUSAMA_NHENTAI_LIVE'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
