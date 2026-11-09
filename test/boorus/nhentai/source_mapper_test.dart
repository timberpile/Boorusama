import 'dart:async';

import 'package:booru_clients/nhentai.dart';
import 'package:boorusama/boorus/nhentai/galleries/mapper.dart';
import 'package:boorusama/boorus/nhentai/galleries/source.dart';
import 'package:boorusama/boorus/nhentai/nhentai.dart';
import 'package:boorusama/boorus/nhentai/posts/data.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/posts/links/boorusama_post_link.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  test('registered native engine owns its parser and capability factory', () {
    final engine = createNhentai();
    expect(engine.parser.parse().type, BooruType.nhentai);
    expect(engine.createGroupCapability, isNotNull);
    expect(
      engine.createBuilder().postPresentation.supports(
        NhentaiPostData(galleryId: 101, pageNumber: 1),
      ),
      isTrue,
    );
  });

  test(
    'listing summaries require no detail envelope and retain unknown fields',
    () {
      final summary = nhentaiGallerySummary(
        NhentaiGallerySummary.fromJson({
          'id': 101,
          'media_id': '7001',
          'english_title': 'Fixture',
          'thumbnail': 'galleries/7001/thumb.webp',
          'tag_ids': [5],
        }),
        galleryAccess(),
        galleryPolicy(),
      );
      expect(summary.reference.sourceKey, 'gallery:101');
      expect(summary.memberCount, isNull);
      expect(summary.previewTags!.coverage, MetadataCoverage.partial);
      expect(summary.cover!.thumbnail.host, 't1.nhentai.net');
      expect(summary.previewTags!.values.single.name, isNull);
    },
  );

  test(
    'actual Page identity, exact media path and portable locator round trip',
    () {
      final access = galleryAccess();
      final posts = nhentaiGalleryPosts(
        NhentaiGalleryDetails.fromJson(galleryJson()),
        access,
        galleryPolicy(),
      );
      expect(posts, hasLength(2));
      expect(
        posts.map((post) => (post.booruData as NhentaiPostData).pageNumber),
        [1, 3],
      );
      expect(
        posts.last.originalImageUrl,
        'https://i1.nhentai.net/galleries/7001/3.webp',
      );
      expect(posts.last.width, 110);
      expect(
        posts.last.tags,
        isEmpty,
        reason: 'Gallery tags are not Page facts',
      );
      final link = BoorusamaPostLink.fromPost(
        posts.last,
        auth: access.config!.auth,
      )!;
      expect(link.key, 'gallery-page:101:3');
      expect(link.postId, const StringPostId('gallery-page:101:3'));
      expect(BoorusamaPostLink.parse(link.uri.toString()), link);
      expect(link.matches(posts.last), isTrue);
      final snapshot = const StoredPostCodec().encode(
        posts.last,
        dataCodec: const NhentaiPostCodec(),
      );
      final restored = const StoredPostCodec().decode(
        snapshot,
        dataCodec: const NhentaiPostCodec(),
      ) as StoredPostDecodeSuccess;
      expect(restored.post.booruData, posts.last.booruData);
      expect(restored.post.id, posts.last.id);
    },
  );

  test(
    'unknown/partial tags do not become an authoritative empty observation',
    () {
      for (final raw in [
        galleryJson(omitTags: true),
        galleryJson(tags: null),
        galleryJson(tags: 'bad'),
      ]) {
        expect(
          nhentaiGalleryDetails(
            NhentaiGalleryDetails.fromJson(raw),
            galleryAccess(),
            galleryPolicy(),
          ).tags,
          isNull,
        );
      }
      final malformed = nhentaiGroupTags(
        NhentaiGalleryDetails.fromJson(galleryJson(tags: [null])),
      )!;
      expect(malformed.coverage, MetadataCoverage.partial);
      expect(malformed.values, isEmpty);
      final partial = nhentaiGalleryDetails(
        NhentaiGalleryDetails.fromJson(
          galleryJson(
            tags: [
              {'id': 5, 'type': 'future_type', 'name': 'valid'},
              null,
            ],
          ),
        ),
        galleryAccess(),
        galleryPolicy(),
      );
      expect(partial.tags!.coverage, MetadataCoverage.partial);
      expect(partial.tags!.values.single.category, 'future_type');
      final empty = nhentaiGalleryDetails(
        NhentaiGalleryDetails.fromJson(galleryJson(tags: [])),
        galleryAccess(),
        galleryPolicy(),
      );
      expect(empty.tags!.values, isEmpty);
      expect(empty.tags!.coverage, MetadataCoverage.complete);
    },
  );

  test(
    'summary, details and members share one envelope with missing middle Page',
    () async {
      final access = galleryAccess();
      final pending = Completer<NhentaiGalleryDetails>();
      var calls = 0;
      final source = NhentaiGallerySource(
        access: access,
        fetchGallery: (id) {
          calls++;
          return pending.future;
        },
        mediaPolicy: () async => galleryPolicy(),
      );
      addTearDown(source.dispose);
      final reference = nhentaiGalleryReference(access, 101);
      final summary = source.loadSummary(reference).run();
      final details = source.loadDetails(reference).run();
      final members = source
          .loadMembers(GroupMemberQuery(reference: reference))
          .run();
      pending.complete(NhentaiGalleryDetails.fromJson(galleryJson()));
      (await summary).fold(
        (error) => fail('$error'),
        (value) => expect(value.reference, reference),
      );
      (await details).fold(
        (error) => fail('$error'),
        (value) => expect(value.tags!.values.single.name, 'fixture'),
      );
      (await members).fold((error) => fail('$error'), (value) {
        expect(value.page.items.map((member) => member.sourcePosition), [
          0,
          1,
          2,
        ]);
        expect(value.page.items.map((member) => member.availability), [
          MemberAvailability.available,
          MemberAvailability.unavailable,
          MemberAvailability.available,
        ]);
        expect(value.resolved, hasLength(2));
      });
      expect(calls, 1);
    },
  );

  test(
    'known empty Gallery is terminal while absent Page manifest stays unavailable',
    () async {
      for (final knownEmpty in [true, false]) {
        final access = galleryAccess();
        final raw = galleryJson()
          ..['num_pages'] = 0
          ..['pages'] = knownEmpty ? <Object>[] : null;
        final source = NhentaiGallerySource(
          access: access,
          fetchGallery: (_) async => NhentaiGalleryDetails.fromJson(raw),
          mediaPolicy: () async => galleryPolicy(),
        );
        addTearDown(source.dispose);
        final result = await source
            .loadMembers(
              GroupMemberQuery(reference: nhentaiGalleryReference(access, 101)),
            )
            .run();
        if (knownEmpty) {
          result.fold((error) => fail('$error'), (value) {
            expect(value.page.items, isEmpty);
            expect(value.page.total, 0);
            expect(value.page.next, isNull);
            expect(value.resolved, isEmpty);
          });
        } else {
          expect(result.isLeft(), isTrue);
        }
      }
    },
  );

  test(
    'refresh rejects stale cursors and does not reseed stale summary',
    () async {
      final access = galleryAccess();
      var calls = 0;
      final source = NhentaiGallerySource(
        access: access,
        fetchGallery: (id) async {
          calls++;
          return NhentaiGalleryDetails.fromJson(galleryJson());
        },
        mediaPolicy: () async => galleryPolicy(),
      );
      addTearDown(source.dispose);
      final reference = nhentaiGalleryReference(access, 101);
      final first =
          (await source
                  .loadMembers(
                    GroupMemberQuery(reference: reference, requestedLimit: 1),
                  )
                  .run())
              .fold((error) => throw error, (value) => value);
      expect(first.page.next, isNotNull);
      source.invalidate(reference);
      final stale = await source
          .loadMembers(
            GroupMemberQuery(
              reference: reference,
              requestedLimit: 1,
              cursor: first.page.next,
            ),
          )
          .run();
      expect(stale.isLeft(), isTrue);
      await source.loadDetails(reference).run();
      expect(calls, 2);
    },
  );

  test(
    'anonymous API, CDN, favicon and portable keys have exact boundaries',
    () {
      final source = const AnonymousSourcePolicy().resolve(
        BooruType.nhentai,
        Uri.parse('https://nhentai.net'),
      )!;
      for (final path in [
        '/api/v2/config',
        '/api/v2/galleries?page=1&per_page=25',
        '/api/v2/galleries/101',
        '/api/v2/search?query=fixture&page=2',
        '/api/v2/tags/ids?ids=5,6',
        '/api/v2/tags/tag?page=1&sort=popular',
      ]) {
        expect(
          source.allowsApi(Uri.parse('https://nhentai.net$path')),
          isTrue,
          reason: path,
        );
      }
      for (final path in [
        '/api/v2/galleries?api_key=secret',
        '/api/v2/galleries/0',
        '/api/v2/tags/ids?ids=0',
        '/api/v2/tags/general',
        '/api/v2/galleries?per_page=101',
      ]) {
        expect(
          source.allowsApi(Uri.parse('https://nhentai.net$path')),
          isFalse,
          reason: path,
        );
      }
      expect(
        source.allowsMedia(
          Uri.parse('https://i1.nhentai.net/galleries/7001/1.webp'),
        ),
        isTrue,
      );
      expect(
        source.allowsMedia(
          Uri.parse('https://i1.nhentai.net.evil.test/galleries/7001/1.webp'),
        ),
        isFalse,
      );
      expect(
        source.allowsMedia(
          Uri.parse(
            'https://i1.nhentai.net/galleries/7001/1.webp?token=secret',
          ),
        ),
        isFalse,
      );
      expect(
        source.allowsFavicon(Uri.parse('https://nhentai.net/favicon.ico')),
        isTrue,
      );
      expect(
        source.allowsFavicon(Uri.parse('https://nhentai.net/favicon.ico?q=1')),
        isFalse,
      );
      expect(
        source.allowsFavicon(Uri.parse('https://foreign.test/favicon.ico')),
        isFalse,
      );
    },
  );
}
