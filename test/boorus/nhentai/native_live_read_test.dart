import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:booru_clients/nhentai.dart';
import 'package:boorusama/boorus/nhentai/availability.dart';
import 'package:boorusama/boorus/nhentai/client_provider.dart';
import 'package:boorusama/boorus/nhentai/nhentai_repository.dart';
import 'package:boorusama/boorus/nhentai/tags/store.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/tags/autocompletes/types.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:boorusama/core/content/nhentai_public_transport.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fixtures.dart';
import 'tag_store_test.dart' show Cache;

/// Opt-in real service/host decoder evidence. Ordinary regression is offline.
/// Android acceptance remains separate, even when this host probe passes.
void main() {
  test(
    'native anonymous API and exact returned CDN resources decode',
    () async {
      final coordinator = ApiRequestCoordinator();
      var current = true;
      final source = const AnonymousSourcePolicy(nhentaiEnabled: true).resolve(
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
      final transport = NhentaiPublicTransport(
        dio: dio,
        source: source,
        current: () => current,
      );
      dio.httpClientAdapter = transport;
      addTearDown(() {
        current = false;
        dio.close(force: true);
        coordinator.dispose();
      });
      final client = NhentaiClient(dio: dio);
      final policy = await transport.mediaPolicy();
      final listing = await client.getGalleries(perPage: 2);
      final details = await client.getGallery(694482);
      final tags = await client.getTagsByIds([152]);
      final search = await client.getGalleries(
        query: 'language:english',
        perPage: 2,
      );
      debugPrint(
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
        debugPrint(
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
  test(
    'anonymous app search returns the live site suggestions and distinct query results',
    () async {
      final auth = galleryAccess().config!.auth;
      final container = ProviderContainer(
        overrides: [
          nhentaiAvailableProvider.overrideWithValue(true),
          defaultUserAgentProvider.overrideWithValue(
            'Boorusama/search-parity-check',
          ),
          nhentaiTagStoreProvider.overrideWithValue(
            NhentaiPersistentTagStore(Cache()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final repo = NhentaiRepository(ref: container.read(_ref))
          .autocomplete(auth);
      final suggestions = await repo.getAutocomplete(
        const AutocompleteQuery.text('vanilla'),
      );
      expect(suggestions.take(2).map((x) => x.value), [
        'artist:"vanilla"',
        'character:"vanilla"',
      ]);
      final client = container.read(nhentaiClientProvider(auth));
      final bare = await client.getGalleries(query: 'vanilla');
      final artist = await client.getGalleries(query: suggestions.first.value);
      final tag = await client.getGalleries(query: 'tag:"vanilla"');
      final next = await client.getGalleries(query: 'vanilla', page: 2);
      expect(bare.items, isNotEmpty);
      expect(artist.items, isNotEmpty);
      expect(
        artist.items.map((x) => x.id),
        isNot(equals(bare.items.map((x) => x.id))),
      );
      expect(
        tag.items.map((x) => x.id),
        isNot(equals(bare.items.map((x) => x.id))),
      );
      expect(
        next.items.map((x) => x.id),
        isNot(equals(bare.items.map((x) => x.id))),
      );
      printOnFailure('Live search totals and suggestion order may change.');
      // Report aggregate parity evidence without emitting Gallery titles or media.
      debugPrint(
        jsonEncode({
          'suggestion_count': suggestions.length,
          'suggestion_types': suggestions.map((tag) => tag.category).toList(),
          'bare_total': bare.total,
          'artist_total': artist.total,
          'tag_total': tag.total,
          'page_one_count': bare.rawCount,
          'page_two_count': next.rawCount,
        }),
      );
    },
    skip: Platform.environment['BOORUSAMA_NHENTAI_LIVE_SEARCH'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

final _ref = Provider<Ref>((ref) => ref);
